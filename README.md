# build_tool

macOS desktop app that imports Flutter projects and runs build/run/clean
commands from a sidebar UI with a live ANSI terminal.

## Features

- Import & manage multiple Flutter projects
- Auto-detect Android flavors (Groovy + Kotlin DSL)
- One-click buttons: Run, Build APK, Clean + Pub get, build_runner, custom commands
- Device picker (reads `flutter devices --machine`)
- "Clean before build" toggle per project
- Live terminal output with ANSI colors (xterm), Stop, Clear, Save log
- After Build APK: auto-renames to `<name>-v<version>.apk` and reveals in Finder
- Persist projects, custom commands across sessions (Hive)
- Banner when Flutter SDK is not on PATH

## Run (development)

```bash
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

## Data

App stores projects and logs under:

```
~/Library/Application Support/build_tool/
```
