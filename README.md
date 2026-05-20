# Flutter Build Tool

A native macOS desktop GUI for managing and building multiple Flutter projects.
Skip the terminal — import your projects once, then run, build, and clean them
with one click while watching a live, ANSI-colored terminal output.

Built with Flutter + Riverpod + Hive + xterm + flutter_pty.

---

## Features

### Project management
- Import and manage multiple Flutter projects from a sortable sidebar
- Per-project settings persist across sessions (Hive-backed)
- Search/filter projects from the sidebar
- Drag-resizable sidebar with responsive breakpoints

### Build & run commands
- **Run** — `flutter run` with device/flavor/entry-point selection
- **Build APK** / **Build AAB** / **Build IPA** — release builds with optional flavor
- **Clean + Pub get** — `flutter clean && flutter pub get`
- **build_runner** — `dart run build_runner build --delete-conflicting-outputs`
- **Custom commands** — user-defined shell commands per project
- **Shell scripts** — auto-detected from `scripts/` folder

### Smart detection
- **Android flavors** — parses both `build.gradle` (Groovy) and `build.gradle.kts` (Kotlin DSL)
- **Devices** — reads `flutter devices --machine` and shows a live picker
- **Entry points** — scans `lib/` for files with `main()` functions, with manual file picker fallback
- **Flutter SDK** — multi-strategy auto-detection (see below)

### Live terminal
- xterm-based terminal with full ANSI color support
- Streamed via PTY (`flutter_pty`) so progress bars and colors render correctly
- 10,000-line buffer
- Stop (SIGTERM → SIGKILL after 2s), Clear, Save log (ANSI-stripped)

### Build output pipeline
- After a successful Build APK: auto-renames `app-release.apk` →
  `<project-name>-v<version>.apk` using `pubspec.yaml`
- Reveals the renamed file in Finder
- "Open output file" button in the terminal toolbar

### UI
- Light paper aesthetic with custom theme
- Per-project state (last flavor, device, entry point, "clean before build" toggle)
- Adaptive layout — works from compact windows up to wide screens

---

## Flutter SDK auto-detection

macOS GUI apps don't inherit your terminal's `PATH` by default — running
`flutter` from a Dart `Process` typically fails with
`zsh: command not found: flutter`, even when it works fine in your terminal.

This tool tries **six** strategies in order to find the real `flutter` binary
and uses the full absolute path in every command:

| # | Strategy | Catches |
|---|----------|---------|
| 1 | Project-local FVM: `<project>/.fvm/flutter_sdk/bin/flutter` | Per-project Flutter version pinning |
| 2 | `zsh -l -i -c 'which flutter'` (login + interactive) | `PATH` set in `~/.zshrc` |
| 3 | `zsh -l -c 'which flutter'` (login only) | `PATH` set in `~/.zprofile` / `~/.zshenv` |
| 4 | `bash -l -c 'which flutter'` (bash login) | `PATH` set in `~/.bash_profile` / `~/.bashrc` |
| 5 | Common install paths (`~/flutter/bin`, `~/fvm/default/bin`, `~/development/flutter/bin`, …) | Manual installs without shell config |
| 6 | Fallback to bare `flutter` | Best-effort last resort |

The resolved path is cached per app launch via a Riverpod `FutureProvider`,
then injected into every shell command (Build, Run, Clean, devices listing,
SDK version check). Per-project FVM is re-checked on each command so different
projects can use different Flutter versions.

---

## Requirements

- macOS 11 (Big Sur) or later
- Flutter SDK installed somewhere on disk (auto-detection handles the rest)
- Xcode + command-line tools for iOS/macOS builds
- Android SDK + accepted licenses for Android builds

---

## Run (development)

```bash
flutter pub get
flutter run -d macos
```

## Build release

```bash
flutter build macos --release
open build/macos/Build/Products/Release/build_tool.app
```

## Test

```bash
flutter test
```

Unit tests cover services (flavor detector, command composer, output renamer,
device parser, etc.) and widget tests cover the toolbar, sidebar, command grid,
and dialogs.

---

## Architecture

```
lib/
├─ app/                          App-level theme, colors, root MaterialApp
├─ data/                         Hive setup, repositories, app paths
├─ domain/
│  ├─ models/                    Project, CustomCommand, BuildLog, CommandIntent (sealed)
│  └─ services/                  All business logic (composer, detectors, runners)
├─ state/                        Riverpod providers + ProjectRunnerController
└─ ui/                           Shell, sidebar, project detail, dialogs, terminal panel
```

**Key services**

| Service | Purpose |
|---------|---------|
| `FlutterPathResolver` | Multi-strategy Flutter binary detection |
| `CommandComposer` | Pattern-matches `CommandIntent` (sealed class) → shell command |
| `CommandRunner` | Abstract; `PtyCommandRunner` (production, color) + `ProcessCommandRunner` (testing) |
| `FlavorDetector` | Parses Groovy + Kotlin DSL `build.gradle` for `productFlavors` |
| `DeviceLister` | Runs `flutter devices --machine`, parses JSON |
| `EntryPointDetector` | Scans `lib/` for `main()` functions |
| `OutputFinder` + `OutputRenamer` | Locates and renames built artifacts |
| `PubspecParser` | Reads name & version from `pubspec.yaml` |
| `ProjectRunnerController` | Per-project runner state machine (idle / running / success / failed / cancelled) |

---

## Data persistence

```
~/Library/Application Support/build_tool/
├─ hive/                Projects, custom commands, build logs
└─ logs/<projectId>/    ANSI-stripped terminal logs (50 most recent per project)
```

---

## License

Personal project — all rights reserved. Reach out if you want to use it.
