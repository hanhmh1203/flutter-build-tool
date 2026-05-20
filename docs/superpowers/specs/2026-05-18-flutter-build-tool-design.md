# Flutter Build Tool — Design

**Date:** 2026-05-18
**Status:** Draft — awaiting user review

## 1. Problem

Every time the user needs to build a Flutter app (APK/IPA, release/debug, with
specific flavors), they must open the source, recall the right command, clean
artifacts, and run the build manually. This is slow and error-prone, especially
when juggling multiple Flutter projects.

## 2. Goal

A native macOS desktop app that:

- Imports existing Flutter projects by folder path.
- Presents a one-click UI for the common build/run/clean commands per project.
- Streams live terminal output with ANSI color and a Stop button.
- Auto-renames the produced APK/IPA to `<name>-v<version>.<ext>` and reveals it
  in Finder after a successful build.
- Persists projects, custom commands, and build history between sessions.

### Non-goals (MVP)

- Cross-platform (Windows/Linux) — macOS only.
- iOS code signing management — relies on signing already configured in the
  project (Xcode/fastlane).
- Build farm / parallel builds across many projects — one running command per
  project at a time.
- Editing project source code, gradle files, or xcconfig from the tool.

## 3. Tech Stack

- **Runtime:** Flutter Desktop (macOS), Dart 3.x.
- **Terminal:** `xterm` + `xterm_flutter` for ANSI-correct rendering.
- **Process spawning:** `flutter_pty` (pseudo-TTY) so Flutter CLI keeps color
  and progress output. Plain `Process.start` is insufficient.
- **State management:** Riverpod.
- **Persistence:** Hive (boxes for projects, custom commands, build history).
- **Misc:** `file_picker` (import folder), `yaml` (parse pubspec), `path_provider`.

## 4. Architecture

```
lib/
├─ ui/
│  ├─ sidebar/            # Project list, add/remove
│  ├─ project_detail/     # Toolbar, command grid, terminal
│  └─ dialogs/            # Add project, custom command editor, settings
├─ domain/
│  ├─ models/             # Project, Flavor, CustomCommand, BuildLog
│  └─ services/
│     ├─ project_importer.dart   # validate + create Project from path
│     ├─ flavor_detector.dart    # parse build.gradle, xcschemes
│     ├─ command_composer.dart   # build command string from Project + intent
│     ├─ command_runner.dart     # spawn via flutter_pty, return RunningCommand
│     ├─ output_finder.dart      # locate .apk/.ipa after build
│     ├─ output_renamer.dart     # copy file → <name>-v<version>.<ext>
│     └─ device_lister.dart      # `flutter devices --machine`
├─ data/
│  └─ repositories/
│     ├─ project_repository.dart
│     └─ build_log_repository.dart
└─ main.dart
```

**Boundaries:**
- UI never calls `Process.start` directly — always via `CommandRunner`.
- `CommandRunner` knows nothing about Flutter — it spawns shell commands.
- `FlavorDetector` only reads files, never spawns processes.
- `OutputRenamer` only does filesystem ops, called by the project_detail
  controller after a successful build.

## 5. UI / Layout (Approach A — Sidebar)

```
┌─────────────────────────────────────────────┐
│ Projects    │ my_app                        │
│ ▸ my_app    │ /Users/.../my_app · Flutter 3.24
│ ▸ shop_app  ├───────────────────────────────┤
│ ▸ admin     │ Flavor: [prod ▾]  Device: [.] │
│ + Add       │ [ ] Clean before build        │
│             ├───────────────────────────────┤
│             │ [▶ Run]      [🧹 Clean+Pub]   │
│             │ [📦 APK]     [⚙️ Runner]      │
│             │ ── Custom ──                  │
│             │ [Deploy FB] [+ Add]           │
│             │ (IPA / Analyze: Phase 2)      │
│             ├───────────────────────────────┤
│             │ Terminal (xterm)              │
│             │ > flutter build apk ...       │
│             │ [Stop] [Clear] [Save] [Open📁]│
└─────────────┴───────────────────────────────┘
```

**UI states:**
- **Idle:** commands enabled, last output (or empty) in terminal.
- **Running:** all action buttons disabled except Stop; spinner on the active
  button; terminal live-streams.
- **Success:** toast "Build APK done (2m 34s)", Finder opens revealing renamed
  file, "Open output" button enabled.
- **Failure:** red toast with exit code, terminal preserved, "Open output"
  disabled.
- **Cancelled:** toast "Cancelled".

## 6. Data Model

Stored at `~/Library/Application Support/build_tool/` (Hive boxes).

```dart
class Project {
  String id;                      // uuid
  String name;                    // from pubspec
  String path;                    // absolute
  String? lastFlavor;
  String? lastDeviceId;
  bool cleanBeforeBuild;          // toolbar toggle, persisted per project
  List<CustomCommand> customCommands;
  DateTime addedAt;
  DateTime? lastOpenedAt;
}

class CustomCommand {
  String id;
  String label;
  String command;                 // raw shell command
  String? icon;                   // emoji or icon name
}

class BuildLog {
  String id;
  String projectId;
  String commandLabel;            // "Build APK (prod)"
  String fullCommand;
  DateTime startedAt;
  Duration? duration;
  int? exitCode;                  // null = running
  String logFilePath;             // file under logs/<projectId>/
}
```

Log files live at:
`~/Library/Application Support/build_tool/logs/<projectId>/<timestamp>-<slug>.log`
(ANSI stripped). Retention: keep 50 most recent per project.

## 7. Command Execution

All commands run with `cwd` set to the project root and inherit the parent
process environment (so user's PATH, ANDROID_HOME, etc. are available).

### 7.1 CommandRunner

```dart
abstract class CommandRunner {
  RunningCommand start({
    required String command,
    required String workingDir,
    Map<String, String>? env,
  });
}

class RunningCommand {
  final Stream<Uint8List> output;
  final Future<int> exitCode;
  final DateTime startedAt;
  void kill();                    // SIGTERM, then SIGKILL after 2s
}
```

Implementation uses `flutter_pty` to allocate a PTY so the child sees a real
terminal (preserves color and progress lines from `flutter build`).

### 7.2 Concurrency rule

One running command per project at a time. Clicking another action while a
command runs disables those buttons (no queueing).

### 7.3 Terminal

`xterm_flutter` consumes the output stream as raw bytes; xterm parses ANSI
itself. Buffer cap: 10,000 lines (older lines drop).

Actions:
- **Stop:** `kill()`.
- **Clear:** reset xterm buffer (does not kill the process if running).
- **Save log:** dump current buffer to file (ANSI stripped).
- **Open output:** enabled only after successful build, opens Finder with the
  renamed output file revealed.

## 8. Flavor & Device Detection

### 8.1 Android flavors

Parse `android/app/build.gradle` and `android/app/build.gradle.kts`:
- Look for `productFlavors { ... }` block, extract flavor names.
- Support both Groovy DSL and Kotlin DSL.

### 8.2 iOS schemes (phase 2)

Parse `ios/Runner.xcodeproj/xcshareddata/xcschemes/*.xcscheme` (file names give
scheme names).

### 8.3 Devices

Run `flutter devices --machine` (JSON output). Refresh on demand (🔄 button)
and when device dropdown is opened.

### 8.4 Failure modes

- No flavors found → dropdown shows only `(default)`, build command omits
  `--flavor`.
- Parse failure → log warning, fallback to `(default)`, do not crash.

## 9. Build → Rename → Reveal

After `flutter build apk` (or `ipa`) exits 0:

1. **Find output:** glob `build/app/outputs/flutter-apk/*-release.apk` (APK) or
   `build/ios/ipa/*.ipa` (IPA). Pick the file with the latest mtime.
2. **Read pubspec.yaml:**
   - `name:` → project name (sanitize: keep `[a-z0-9_-]`, lowercase).
   - `version:` → take portion before `+` (e.g. `1.2.3+45` → `1.2.3`).
3. **Compose new name:** `<name>-v<version>.<ext>`.
   - Missing version → fallback `v0.0.0`, show warning toast.
4. **Copy** the original file to the same folder under the new name. Original
   is preserved. If the renamed file already exists (rebuilding same version),
   overwrite.
5. **Reveal in Finder:** `Process.run('open', ['-R', renamedPath])`.

Failure to find the output file → fallback to opening `build/` and toast
"Output file not found, opened build folder".

## 10. Error Handling

| Scenario | Behavior |
|---|---|
| Folder lacks `pubspec.yaml` on import | Dialog: "Not a Flutter project", do not add |
| `pubspec.yaml` malformed | Dialog with parse error, do not add |
| Project path no longer exists | Mark project as "missing"; disable commands; offer Re-locate / Remove |
| `flutter` not in PATH | Startup banner: "Flutter SDK not found in PATH" + hint |
| Process spawn fails | Error toast + line in terminal `[error] failed to start: ...` |
| Build exits non-zero | Preserve terminal, button shows failure state, no rename, no Finder reveal |
| User clicks Stop | SIGTERM → wait 2s → SIGKILL; toast "Cancelled" |
| Output file not found | Open `build/` folder, toast warning |
| `version` missing in pubspec | Rename uses `v0.0.0`, toast warning |
| Hive open fails (corrupt) | Show recovery dialog: "Reset app data?" |

## 11. Testing

**Unit tests:**
- `FlavorDetector` — fixtures: Groovy build.gradle with/without flavors,
  Kotlin DSL with flavors.
- `CommandComposer` — verify command strings for run/build/clean across
  combinations of flavor, clean-before-build, device id.
- `OutputFinder` — fake filesystem with multiple `.apk` files, picks newest
  mtime.
- `OutputRenamer` — parses `name` and `version` correctly (with/without
  `+build`, sanitization of weird names).
- `ProjectRepository` — Hive CRUD round-trip.

**Widget tests:**
- Sidebar renders project list, add/remove flows.
- Project detail toggles button enabled/disabled by running state.
- Custom command dialog (add/edit/delete).

**Integration test (one):**
- End-to-end against a fixture Flutter project at `test/fixtures/sample_app/`:
  import → list a fake "echo" custom command → run → verify terminal output
  → cancel → verify clean exit.

**Out of scope for CI:**
- Real `flutter build apk` (slow, requires Android SDK).
- iOS build (requires Mac CI with code signing).

## 12. MVP Scope vs Phase 2

**MVP:**
- Import / list / remove projects.
- Auto-detect Android flavors (Groovy + Kotlin DSL).
- Built-in commands:
  - **Run:** `flutter run -d <deviceId> [--flavor <f>]`
  - **Build APK:** `flutter build apk --release [--flavor <f>]`
  - **Clean + Pub get:** `flutter clean && flutter pub get` (one button, chained)
  - **build_runner:** `dart run build_runner build --delete-conflicting-outputs`
- Custom commands per project. Executed via `/bin/zsh -c '<command>'` with
  `cwd` set to project path and parent environment inherited. User is
  responsible for command safety (no validation beyond non-empty).
- Device picker for Run (`flutter devices --machine`).
- Terminal with xterm + Stop / Clear / Save log.
- Output rename + Finder reveal for APK.
- Build history (basic list, no filters).
- "Clean before build" toggle per project (applies to Build APK only in MVP).

**Phase 2:**
- Build iOS / IPA (signing edge cases, scheme detection).
- Format & analyze button.
- Build history filtering / search.
- Settings: theme, font size, log retention count.

## 13. Open Risks

- **`flutter_pty` on macOS arm64:** verify the package works on Apple Silicon
  during plan / spike phase. Fallback: `Process.start` with `--no-color`
  forced (lose colors but functional).
- **Flutter CLI output stability:** rename logic relies on default output
  paths; if Flutter changes them in future, `OutputFinder` glob may need
  updating. Mitigation: glob is centralized in one service.
- **Hive migration:** schema changes after release will need migration code;
  add a version field in app config from day one.
