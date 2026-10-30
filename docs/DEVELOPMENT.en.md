# Development and Release Guide

[VI](DEVELOPMENT.md) | [EN](DEVELOPMENT.en.md)

## Environment

1. Install Xcode or a Swift toolchain that supports macOS 13.
2. Clone the repository.
3. Check the toolchain:

```bash
swift --version
```

## Development loop

```bash
swift build
swift run
```

After changing the UI or scanners, verify at least the following:

- The app launches and its icon appears in the menu bar.
- The Ports tab shows data when a process is listening.
- The Processes tab reports plausible CPU and memory values.
- Search is case-insensitive.
- SIGTERM updates the list; SIGKILL is used only when necessary.
- The app does not crash when `lsof` or `ps` returns unexpected output.

## Build a local app bundle

```bash
./build.sh
open PortKiller.app
```

`build.sh` creates a minimal app bundle, sets `LSUIElement=true`, and applies an ad-hoc signature. This is not a production distribution workflow.

## Pre-commit checklist

- `swift build` succeeds.
- `./build.sh` creates the app bundle.
- `.build/`, `.DS_Store`, and `PortKiller.app` are not committed.
- README/docs are updated when behavior, system requirements, or user workflows change.
- No shell command capable of deleting user data is introduced.

## Public release

A production release should add:

- An Apple Developer signing identity.
- Hardened Runtime and notarization.
- Consistent versioning in `Info.plist`.
- Release notes and artifact checksums.
- CI builds on a clean macOS runner.
