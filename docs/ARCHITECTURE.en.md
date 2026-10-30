# PortKiller Architecture

[VI](ARCHITECTURE.md) | [EN](ARCHITECTURE.en.md)

## Overview

PortKiller is a SwiftUI macOS menu-bar utility. It has no standalone main window and sets the activation policy to `accessory`, so it does not appear in the Dock.

Main flow:

```text
MenuBarExtra
    ↓
ContentView
    ↓
Monitor (@MainActor, ObservableObject)
    ├── scanPorts()      → /usr/sbin/lsof
    ├── scanProcesses()  → /bin/ps
    └── kill(...)         → Darwin.kill(SIGTERM | SIGKILL)
```

## Models

`PortInfo` represents a network endpoint with a PID, command, user, protocol, address, and port.

`ProcInfo` represents a process with its PID, name, user, CPU percentage, and memory in MB.

`NodeModulesInfo` represents a `node_modules` directory with its path, recursive byte size, and direct package count.

Both models conform to `Identifiable` and `Hashable` so they can be used directly in SwiftUI `ForEach` views.

## Port scanning

`scanPorts()` runs two commands:

```text
lsof -nP -iTCP -sTCP:LISTEN
lsof -nP -iUDP
```

The output is split into lines, then the command, PID, user, address, and port are parsed. Duplicate endpoints are removed with a `Set`, and the final result is sorted by port in ascending order.

Established TCP connections have an `a->b` form and are ignored. UDP output can vary between macOS versions, so lines with insufficient fields or an unparseable port are skipped.

## Process scanning

`scanProcesses()` runs:

```text
ps -axo pid=,pcpu=,rss=,user=,comm=
```

RSS is converted from KB to MB. The process name is reduced to the final path component, and results are sorted by descending CPU usage.

## Concurrency and refresh

`Monitor` is `@MainActor`, keeping all `@Published` changes safe for SwiftUI. System commands run inside a detached task so the UI is not blocked. A timer refreshes the data every three seconds; after a termination request, another refresh runs after 0.6 seconds so the UI can reflect the process exit.

The `node_modules` scan runs only when the corresponding tab is opened or manually refreshed. It uses the home folder as its root, calculates recursive sizes, and sorts results in descending order.

The delete button requires confirmation and only accepts a directory named exactly `node_modules`, located below the home directory and not a symbolic link.

## Process termination

- Primary click: sends `SIGTERM`, allowing the process to shut down cleanly.
- Secondary menu action **Force Kill**: sends `SIGKILL`, preventing process cleanup.

The app does not use `sudo` or elevate privileges automatically. If a process belongs to another user or is protected by the system, `kill` may fail; the `errno` message is shown in the status bar.

## Limitations and future improvements

- There is no test target or fixture set for `lsof`/`ps` output yet.
- The parser depends on macOS CLI output formats.
- Accessibility permissions, launch-at-login, icon assets, and notarization are not implemented yet.
- `run(...)` currently returns an empty string when a command fails; returning exit status and stderr would improve diagnostics.
- Scanners, process termination, and view-model logic can be split into separate files/modules as the feature set grows.
