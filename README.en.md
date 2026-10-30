# PortKiller

macOS menu-bar utility for monitoring open network ports and managing running processes.

[VI](README.md) | [EN](README.en.md)

PortKiller helps you:

- List TCP ports in `LISTEN` state and UDP endpoints.
- View the command, PID, user, and bind address for each port.
- Monitor running processes with current CPU and memory usage.
- Scan `node_modules` directories under the home folder and sort them by size, largest first.
- Search by process name, port, or PID.
- Send `SIGTERM` for graceful termination or `SIGKILL` for force termination.

> **Warning:** Killing the wrong process can cause data loss or unstable application/system behavior. Always verify the PID and command before terminating a process.

## Requirements

- macOS 13 Ventura or later.
- Swift 5.9 or later; the project currently builds with Swift 6.x.
- Access to the system binaries `/usr/sbin/lsof` and `/bin/ps`.

## Install and run

### Build the app bundle

```bash
./build.sh
open PortKiller.app
```

The script builds a release binary with Swift Package Manager, packages it as `PortKiller.app`, and applies an ad-hoc signature for local execution.

### Run directly with SwiftPM

```bash
swift run
```

When launched, PortKiller appears in the menu bar. Click its icon to open the management window.

## Usage

### Ports

The **Ports** tab refreshes automatically every three seconds. Each row shows the port, command, protocol, bind address, PID, and user.

- Click the red button to send `SIGTERM`.
- Open the button menu and choose **Force Kill (SIGKILL)** when a process does not stop gracefully.
- Use the search field to filter by command, port, or PID.

### Processes

The **Processes** tab lists processes sorted by descending CPU usage, with user, CPU, and memory information. Search by name or PID and use the same termination controls.

### Node Modules

The **Node Modules** tab scans for `node_modules` directories under the home folder, calculates their recursive sizes, and sorts them from largest to smallest. Each row shows the size, direct package count, and path. You can search by path and refresh manually.

## Architecture

The source currently lives in a single executable target:

```text
Sources/PortKiller/PortKillerApp.swift
├── Models       PortInfo, ProcInfo
├── Shell helper run(...)
├── Scanning     scanPorts(), scanProcesses()
├── Monitor      polling, termination, and UI state
├── UI           ContentView, KillMenu
└── App          PortKillerApp / MenuBarExtra
```

See [docs/ARCHITECTURE.en.md](docs/ARCHITECTURE.en.md) for the data flow and current limitations.

## Repository layout

```text
.
├── Package.swift
├── Sources/PortKiller/PortKillerApp.swift
├── build.sh
├── README.md          # Vietnamese documentation
├── README.en.md       # English documentation
└── docs/
    ├── ARCHITECTURE.md
    ├── ARCHITECTURE.en.md
    ├── DEVELOPMENT.md
    └── DEVELOPMENT.en.md
```

## Development

```bash
swift build
swift test       # no test target yet; reserved for future CI
./build.sh
```

See [docs/DEVELOPMENT.en.md](docs/DEVELOPMENT.en.md) for the development, verification, and release workflow.

## License

Released under the [MIT License](LICENSE).
