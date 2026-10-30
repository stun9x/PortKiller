import SwiftUI
import AppKit
import Darwin

// MARK: - Models

struct PortInfo: Identifiable, Hashable {
    var id: String { "\(pid)-\(proto)-\(port)-\(address)" }
    let pid: Int32
    let command: String
    let user: String
    let proto: String
    let address: String
    let port: Int
}

struct ProcInfo: Identifiable, Hashable {
    var id: Int32 { pid }
    let pid: Int32
    let name: String
    let user: String
    let cpu: Double
    let memMB: Double
}

struct NodeModulesInfo: Identifiable, Hashable {
    var id: String { path }
    let path: String
    let sizeBytes: Int64
    let packageCount: Int
}

// MARK: - Shell helper

func run(_ path: String, _ args: [String]) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    let out = Pipe()
    p.standardOutput = out
    p.standardError = Pipe()
    do { try p.run() } catch { return "" }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return String(decoding: data, as: UTF8.self)
}

// MARK: - Scanning

func scanPorts() -> [PortInfo] {
    var result: [PortInfo] = []
    var seen = Set<String>()

    // TCP LISTEN + UDP
    let outputs: [(String, String)] = [
        ("TCP", run("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN"])),
        ("UDP", run("/usr/sbin/lsof", ["-nP", "-iUDP"]))
    ]

    for (proto, text) in outputs {
        for line in text.split(separator: "\n").dropFirst() {
            var tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard tokens.count >= 9, let pid = Int32(tokens[1]) else { continue }
            if tokens.last == "(LISTEN)" { tokens.removeLast() }
            // NAME có thể là "*:3000" hoặc "127.0.0.1:8080" hoặc "[::1]:3000" hoặc "a->b"
            let name = tokens.last ?? ""
            if name.contains("->") { continue } // bỏ kết nối đã thiết lập
            guard let colon = name.lastIndex(of: ":"),
                  let port = Int(name[name.index(after: colon)...]) else { continue }
            let address = String(name[..<colon])
            let command = tokens[0].replacingOccurrences(of: "\\x20", with: " ")
            let info = PortInfo(pid: pid, command: command, user: tokens[2],
                                proto: proto, address: address.isEmpty ? "*" : address, port: port)
            if seen.insert(info.id).inserted { result.append(info) }
        }
    }
    return result.sorted { $0.port < $1.port }
}

func scanProcesses() -> [ProcInfo] {
    let text = run("/bin/ps", ["-axo", "pid=,pcpu=,rss=,user=,comm="])
    var result: [ProcInfo] = []
    for line in text.split(separator: "\n") {
        let parts = line.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
        guard parts.count == 5,
              let pid = Int32(parts[0]),
              let cpu = Double(parts[1]),
              let rss = Double(parts[2]) else { continue }
        let name = (String(parts[4]) as NSString).lastPathComponent
        result.append(ProcInfo(pid: pid, name: name, user: String(parts[3]),
                               cpu: cpu, memMB: rss / 1024))
    }
    return result.sorted { $0.cpu > $1.cpu }
}

func directorySize(_ url: URL) -> Int64 {
    let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .fileAllocatedSizeKey, .fileSizeKey]
    guard let enumerator = FileManager.default.enumerator(
        at: url,
        includingPropertiesForKeys: keys,
        options: [.skipsHiddenFiles]
    ) else { return 0 }

    var total: Int64 = 0
    for case let fileURL as URL in enumerator {
        guard let values = try? fileURL.resourceValues(forKeys: Set(keys)) else { continue }
        if values.isDirectory == true {
            if values.isSymbolicLink == true { enumerator.skipDescendants() }
            continue
        }
        total += Int64(values.fileAllocatedSize ?? values.fileSize ?? 0)
    }
    return total
}

func packageCount(in url: URL) -> Int {
    (try? FileManager.default.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
        options: [.skipsHiddenFiles]
    ).filter { child in
        guard let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
        return values.isDirectory == true && values.isSymbolicLink != true
    }.count) ?? 0
}

func scanNodeModules(in root: URL) -> [NodeModulesInfo] {
    let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
    guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: keys,
        options: [.skipsHiddenFiles]
    ) else { return [] }

    var result: [NodeModulesInfo] = []
    for case let url as URL in enumerator {
        guard url.lastPathComponent == "node_modules",
              let values = try? url.resourceValues(forKeys: Set(keys)),
              values.isDirectory == true,
              values.isSymbolicLink != true else { continue }

        result.append(NodeModulesInfo(
            path: url.path,
            sizeBytes: directorySize(url),
            packageCount: packageCount(in: url)
        ))
        // Nested node_modules belongs to this dependency tree; do not report it again.
        enumerator.skipDescendants()
    }
    return result.sorted { $0.sizeBytes > $1.sizeBytes }
}

func formatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

// MARK: - Monitor

@MainActor
final class Monitor: ObservableObject {
    @Published var ports: [PortInfo] = []
    @Published var processes: [ProcInfo] = []
    @Published var nodeModules: [NodeModulesInfo] = []
    @Published var message: String?

    private var timer: Timer?

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        Task.detached(priority: .utility) {
            let p = scanPorts()
            let pr = scanProcesses()
            await MainActor.run {
                self.ports = p
                self.processes = pr
            }
        }
    }

    func refreshNodeModules() {
        let root = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        Task.detached(priority: .utility) {
            let modules = scanNodeModules(in: root)
            await MainActor.run { self.nodeModules = modules }
        }
    }

    func deleteNodeModules(_ module: NodeModulesInfo) {
        let url = URL(fileURLWithPath: module.path, isDirectory: true).standardizedFileURL
        let homePath = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).standardizedFileURL.path
        let isInsideHome = url.path.hasPrefix(homePath + "/")
        let isNodeModules = url.lastPathComponent == "node_modules"
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
        let values = try? url.resourceValues(forKeys: keys)

        guard isInsideHome,
              isNodeModules,
              values?.isDirectory == true,
              values?.isSymbolicLink != true else {
            message = "Không xoá được: đường dẫn không hợp lệ"
            return
        }

        do {
            try FileManager.default.removeItem(at: url)
            message = "Đã xoá node_modules: \(url.deletingLastPathComponent().lastPathComponent)"
            refreshNodeModules()
        } catch {
            message = "Không xoá được node_modules: \(error.localizedDescription)"
        }
    }

    func kill(pid: Int32, name: String, force: Bool) {
        let sig = force ? SIGKILL : SIGTERM
        if Darwin.kill(pid, sig) == 0 {
            message = "Đã gửi \(force ? "SIGKILL" : "SIGTERM") tới \(name) (\(pid))"
        } else {
            let err = String(cString: strerror(errno))
            message = "Không kill được \(name) (\(pid)): \(err)"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.refresh() }
    }
}

// MARK: - UI

enum Tab: String, CaseIterable, Identifiable {
    case ports = "Ports"
    case processes = "Processes"
    case nodeModules = "Node Modules"
    var id: String { rawValue }
}

struct KillMenu: View {
    let pid: Int32
    let name: String
    @ObservedObject var monitor: Monitor

    var body: some View {
        Menu {
            Button("Force Kill (SIGKILL)", role: .destructive) {
                monitor.kill(pid: pid, name: name, force: true)
            }
        } label: {
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        } primaryAction: {
            monitor.kill(pid: pid, name: name, force: false)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Click: kill (SIGTERM) • Giữ chuột: Force Kill")
    }
}

struct ContentView: View {
    @StateObject private var monitor = Monitor()
    @State private var tab: Tab = .ports
    @State private var query = ""

    func confirmDelete(_ module: NodeModulesInfo) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Xoá node_modules?"
            alert.informativeText = "Thư mục này sẽ bị xoá vĩnh viễn:\n\(module.path)\n\nKích thước: \(formatBytes(module.sizeBytes))"
            alert.addButton(withTitle: "Xoá")
            alert.addButton(withTitle: "Huỷ")

            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn {
                monitor.deleteNodeModules(module)
            }
        }
    }

    var filteredPorts: [PortInfo] {
        guard !query.isEmpty else { return monitor.ports }
        let q = query.lowercased()
        return monitor.ports.filter {
            $0.command.lowercased().contains(q) || String($0.port).contains(q) || String($0.pid).contains(q)
        }
    }

    var filteredProcesses: [ProcInfo] {
        guard !query.isEmpty else { return monitor.processes }
        let q = query.lowercased()
        return monitor.processes.filter {
            $0.name.lowercased().contains(q) || String($0.pid).contains(q)
        }
    }

    var filteredNodeModules: [NodeModulesInfo] {
        guard !query.isEmpty else { return monitor.nodeModules }
        let q = query.lowercased()
        return monitor.nodeModules.filter { $0.path.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            TextField("Tìm theo tên, port, PID…", text: $query)
                .textFieldStyle(.roundedBorder)

            List {
                if tab == .ports {
                    ForEach(filteredPorts) { p in
                        HStack {
                            Text(verbatim: ":" + String(p.port))
                                .font(.system(.body, design: .monospaced).bold())
                                .frame(width: 64, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(p.command).lineLimit(1)
                                Text(verbatim: "\(p.proto) • \(p.address) • PID \(String(p.pid)) • \(p.user)")
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            KillMenu(pid: p.pid, name: p.command, monitor: monitor)
                        }
                    }
                } else {
                    if tab == .processes {
                        ForEach(filteredProcesses) { p in
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(p.name).lineLimit(1)
                                    Text(verbatim: "PID \(String(p.pid)) • \(p.user)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(String(format: "%.1f%%", p.cpu))
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(width: 52, alignment: .trailing)
                                Text(String(format: "%.0f MB", p.memMB))
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(width: 66, alignment: .trailing)
                                KillMenu(pid: p.pid, name: p.name, monitor: monitor)
                            }
                        }
                    } else {
                        ForEach(filteredNodeModules) { module in
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(formatBytes(module.sizeBytes))
                                            .font(.system(.body, design: .monospaced).bold())
                                            .frame(width: 78, alignment: .leading)
                                        Text(verbatim: "\(module.packageCount) packages")
                                            .font(.caption).foregroundStyle(.secondary)
                                        Spacer()
                                    }
                                    Text(module.path)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer(minLength: 4)
                                Button {
                                    confirmDelete(module)
                                } label: {
                                    Image(systemName: "trash")
                                        .frame(width: 28, height: 28)
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                                .help("Xoá thư mục node_modules này")
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .listStyle(.plain)

            HStack {
                Text(monitor.message ?? {
                    switch tab {
                    case .ports: return "\(filteredPorts.count) ports đang mở"
                    case .processes: return "\(filteredProcesses.count) tiến trình"
                    case .nodeModules: return "\(filteredNodeModules.count) thư mục node_modules"
                    }
                }())
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Button {
                    if tab == .nodeModules { monitor.refreshNodeModules() } else { monitor.refresh() }
                } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                Button { NSApplication.shared.terminate(nil) } label: { Image(systemName: "power") }
                    .buttonStyle(.borderless)
            }
        }
        .padding(10)
        .frame(width: 560, height: 600)
        .onAppear { monitor.start() }
        .onChange(of: tab) { newTab in
            if newTab == .nodeModules { monitor.refreshNodeModules() }
        }
        .onDisappear { monitor.stop() }
    }
}

// MARK: - App

@main
struct PortKillerApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.accessory) // không hiện icon Dock
    }

    var body: some Scene {
        MenuBarExtra("PortKiller", systemImage: "bolt.horizontal.circle") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
