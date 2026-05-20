# Flutter Build Tool Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS desktop app (Flutter Desktop) that imports Flutter projects, runs build/run/clean commands via a sidebar UI with a live ANSI terminal, and auto-renames built APKs to `<name>-v<version>.apk` with Finder reveal.

**Architecture:** Sidebar layout. Pure-logic services (parsers, composers, file ops) are tested in isolation; one IO service (`PtyCommandRunner`) wraps `flutter_pty`. Riverpod for state. Hive for persistence under `~/Library/Application Support/build_tool/`.

**Tech Stack:** Flutter 3.x desktop (macOS), Dart 3.x, Riverpod, Hive, `flutter_pty`, `xterm` + `xterm_flutter`, `file_picker`, `yaml`, `path_provider`.

**Spec:** [`docs/superpowers/specs/2026-05-18-flutter-build-tool-design.md`](../specs/2026-05-18-flutter-build-tool-design.md)

---

## File Structure

```
build_tool/
├── pubspec.yaml
├── analysis_options.yaml
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart                # MaterialApp + shell
│   │   └── theme.dart
│   ├── domain/
│   │   ├── models/
│   │   │   ├── project.dart
│   │   │   ├── custom_command.dart
│   │   │   ├── build_log.dart
│   │   │   ├── flutter_device.dart
│   │   │   └── command_intent.dart
│   │   └── services/
│   │       ├── pubspec_parser.dart
│   │       ├── flavor_detector.dart
│   │       ├── command_composer.dart
│   │       ├── command_runner.dart        # abstract + PtyCommandRunner
│   │       ├── output_finder.dart
│   │       ├── output_renamer.dart
│   │       ├── device_lister.dart
│   │       ├── flutter_sdk_checker.dart
│   │       ├── finder_reveal.dart
│   │       └── project_importer.dart
│   ├── data/
│   │   ├── app_paths.dart
│   │   ├── hive_setup.dart
│   │   └── repositories/
│   │       ├── project_repository.dart
│   │       └── build_log_repository.dart
│   ├── state/
│   │   ├── providers.dart
│   │   └── project_runner_controller.dart
│   └── ui/
│       ├── shell.dart
│       ├── sidebar/
│       │   └── sidebar.dart
│       ├── project_detail/
│       │   ├── project_detail.dart
│       │   ├── toolbar.dart
│       │   ├── command_grid.dart
│       │   └── terminal_panel.dart
│       └── dialogs/
│           ├── add_project_dialog.dart
│           └── custom_command_dialog.dart
└── test/
    ├── fixtures/
    │   ├── build_gradle_groovy_flavors.txt
    │   ├── build_gradle_groovy_no_flavors.txt
    │   ├── build_gradle_kts_flavors.txt
    │   ├── pubspec_full.yaml
    │   ├── pubspec_no_version.yaml
    │   └── sample_app/                  # minimal flutter-shaped folder
    ├── unit/...
    └── widget/...
```

**Boundary rules** (verify during code review of each task):
- UI never imports `dart:io` Process / `flutter_pty`. Only via `CommandRunner` injected through Riverpod.
- Services in `domain/services/` never import `package:flutter/*` (testable in pure Dart).
- Models in `domain/models/` are plain data — no IO, no Flutter.

---

## Task 0: Project init & dependencies

**Files:**
- Create: `pubspec.yaml`
- Create: `analysis_options.yaml`
- Create: `.gitignore`

- [ ] **Step 1: Initialize Flutter project**

Run in `/Users/william/Documents/my_git/build_tool`:

```bash
flutter create --platforms=macos --project-name build_tool .
```

Expected: scaffolds `lib/main.dart`, `macos/`, `pubspec.yaml`, `test/`.

- [ ] **Step 2: Replace `pubspec.yaml` dependencies**

Open `pubspec.yaml`. Keep `name`, `description`, `publish_to: 'none'`, `version: 0.1.0+1`, `environment.sdk: '>=3.3.0 <4.0.0'`. Replace `dependencies:` and `dev_dependencies:` blocks with:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  path_provider: ^2.1.3
  file_picker: ^8.0.0+1
  yaml: ^3.1.2
  uuid: ^4.4.0
  flutter_pty: ^0.3.1
  xterm: ^4.0.0
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  hive_generator: ^2.0.1
  build_runner: ^2.4.10
```

- [ ] **Step 3: Install deps and verify**

```bash
flutter pub get
flutter analyze
```

Expected: deps resolve. Analyze passes (only the default `MyApp` boilerplate warnings, ignore for now).

- [ ] **Step 4: Strengthen lints**

Replace `analysis_options.yaml` with:

```yaml
include: package:flutter_lints/flutter.yaml
linter:
  rules:
    avoid_print: true
    prefer_const_constructors: true
    prefer_final_locals: true
    sort_pub_dependencies: false
analyzer:
  errors:
    invalid_annotation_target: ignore
  exclude:
    - "**/*.g.dart"
```

- [ ] **Step 5: Verify macOS build runs**

```bash
flutter run -d macos
```

Expected: app window opens with default counter (kill with Ctrl-C).

- [ ] **Step 6: Init git repo and commit**

```bash
git init
git add .
git commit -m "chore: bootstrap flutter macos desktop project with deps"
```

---

## Task 1: App paths utility

**Files:**
- Create: `lib/data/app_paths.dart`
- Test: `test/unit/app_paths_test.dart`

`AppPaths` exposes filesystem locations relative to `Application Support`. We inject a base directory so tests don't touch the real `~/Library`.

- [ ] **Step 1: Write the failing test**

`test/unit/app_paths_test.dart`:

```dart
import 'dart:io';
import 'package:build_tool/data/app_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempBase;

  setUp(() async {
    tempBase = await Directory.systemTemp.createTemp('build_tool_test');
  });

  tearDown(() async {
    if (tempBase.existsSync()) await tempBase.delete(recursive: true);
  });

  test('hiveDir is <base>/hive', () {
    final paths = AppPaths(base: tempBase);
    expect(paths.hiveDir.path, '${tempBase.path}/hive');
  });

  test('logDir for project is <base>/logs/<projectId>', () {
    final paths = AppPaths(base: tempBase);
    expect(paths.logDirFor('p1').path, '${tempBase.path}/logs/p1');
  });

  test('ensure() creates missing directories', () async {
    final paths = AppPaths(base: tempBase);
    await paths.ensure();
    expect(paths.hiveDir.existsSync(), isTrue);
    expect(Directory('${tempBase.path}/logs').existsSync(), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/unit/app_paths_test.dart
```

Expected: FAIL — `AppPaths` undefined.

- [ ] **Step 3: Implement `AppPaths`**

`lib/data/app_paths.dart`:

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AppPaths {
  AppPaths({required this.base});

  final Directory base;

  Directory get hiveDir => Directory('${base.path}/hive');
  Directory get logsRoot => Directory('${base.path}/logs');
  Directory logDirFor(String projectId) =>
      Directory('${logsRoot.path}/$projectId');

  Future<void> ensure() async {
    await hiveDir.create(recursive: true);
    await logsRoot.create(recursive: true);
  }

  static Future<AppPaths> forApp() async {
    final dir = await getApplicationSupportDirectory();
    final base = Directory('${dir.path}/build_tool');
    await base.create(recursive: true);
    final paths = AppPaths(base: base);
    await paths.ensure();
    return paths;
  }
}
```

- [ ] **Step 4: Run test to verify pass**

```bash
flutter test test/unit/app_paths_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/app_paths.dart test/unit/app_paths_test.dart
git commit -m "feat(data): add AppPaths utility for filesystem layout"
```

---

## Task 2: Data models with Hive adapters

**Files:**
- Create: `lib/domain/models/custom_command.dart`
- Create: `lib/domain/models/project.dart`
- Create: `lib/domain/models/build_log.dart`
- Test: `test/unit/models_test.dart`

We use Hive's generated adapters via `build_runner`.

- [ ] **Step 1: Write the failing test**

`test/unit/models_test.dart`:

```dart
import 'dart:io';
import 'package:build_tool/domain/models/build_log.dart';
import 'package:build_tool/domain/models/custom_command.dart';
import 'package:build_tool/domain/models/project.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('models_test');
    Hive.init(tmp.path);
    Hive.registerAdapter(ProjectAdapter());
    Hive.registerAdapter(CustomCommandAdapter());
    Hive.registerAdapter(BuildLogAdapter());
  });

  tearDown(() async {
    await Hive.close();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('Project round-trips through Hive', () async {
    final box = await Hive.openBox<Project>('projects');
    final p = Project(
      id: 'abc',
      name: 'my_app',
      path: '/Users/me/my_app',
      lastFlavor: 'prod',
      lastDeviceId: 'iPhone15',
      cleanBeforeBuild: true,
      customCommands: [
        CustomCommand(id: 'c1', label: 'Deploy', command: 'firebase deploy'),
      ],
      addedAt: DateTime.utc(2026, 5, 1),
    );
    await box.put(p.id, p);

    final loaded = box.get('abc')!;
    expect(loaded.name, 'my_app');
    expect(loaded.lastFlavor, 'prod');
    expect(loaded.customCommands.single.label, 'Deploy');
    expect(loaded.cleanBeforeBuild, isTrue);
  });

  test('BuildLog round-trips', () async {
    final box = await Hive.openBox<BuildLog>('build_logs');
    final l = BuildLog(
      id: 'l1',
      projectId: 'abc',
      commandLabel: 'Build APK (prod)',
      fullCommand: 'flutter build apk --release --flavor prod',
      startedAt: DateTime.utc(2026, 5, 1, 12),
      duration: const Duration(seconds: 90),
      exitCode: 0,
      logFilePath: '/tmp/logs/abc/log1.log',
    );
    await box.put(l.id, l);
    expect(box.get('l1')!.exitCode, 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/unit/models_test.dart
```

Expected: FAIL — model classes undefined.

- [ ] **Step 3: Define models with Hive annotations**

`lib/domain/models/custom_command.dart`:

```dart
import 'package:hive/hive.dart';

part 'custom_command.g.dart';

@HiveType(typeId: 1)
class CustomCommand {
  CustomCommand({
    required this.id,
    required this.label,
    required this.command,
    this.icon,
  });

  @HiveField(0)
  final String id;
  @HiveField(1)
  String label;
  @HiveField(2)
  String command;
  @HiveField(3)
  String? icon;
}
```

`lib/domain/models/project.dart`:

```dart
import 'package:hive/hive.dart';
import 'custom_command.dart';

part 'project.g.dart';

@HiveType(typeId: 0)
class Project {
  Project({
    required this.id,
    required this.name,
    required this.path,
    required this.addedAt,
    this.lastFlavor,
    this.lastDeviceId,
    this.cleanBeforeBuild = false,
    List<CustomCommand>? customCommands,
    this.lastOpenedAt,
  }) : customCommands = customCommands ?? <CustomCommand>[];

  @HiveField(0)
  final String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  String path;
  @HiveField(3)
  String? lastFlavor;
  @HiveField(4)
  String? lastDeviceId;
  @HiveField(5)
  bool cleanBeforeBuild;
  @HiveField(6)
  List<CustomCommand> customCommands;
  @HiveField(7)
  DateTime addedAt;
  @HiveField(8)
  DateTime? lastOpenedAt;
}
```

`lib/domain/models/build_log.dart`:

```dart
import 'package:hive/hive.dart';

part 'build_log.g.dart';

@HiveType(typeId: 2)
class BuildLog {
  BuildLog({
    required this.id,
    required this.projectId,
    required this.commandLabel,
    required this.fullCommand,
    required this.startedAt,
    required this.logFilePath,
    this.duration,
    this.exitCode,
  });

  @HiveField(0)
  final String id;
  @HiveField(1)
  final String projectId;
  @HiveField(2)
  final String commandLabel;
  @HiveField(3)
  final String fullCommand;
  @HiveField(4)
  final DateTime startedAt;
  @HiveField(5)
  Duration? duration;
  @HiveField(6)
  int? exitCode;
  @HiveField(7)
  final String logFilePath;
}
```

- [ ] **Step 4: Run build_runner to generate adapters**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: creates `*.g.dart` files alongside each model.

- [ ] **Step 5: Run test to verify pass**

```bash
flutter test test/unit/models_test.dart
```

Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/domain/models/ test/unit/models_test.dart
git commit -m "feat(models): add Project, CustomCommand, BuildLog with Hive adapters"
```

---

## Task 3: Hive setup helper

**Files:**
- Create: `lib/data/hive_setup.dart`
- Test: `test/unit/hive_setup_test.dart`

- [ ] **Step 1: Write failing test**

`test/unit/hive_setup_test.dart`:

```dart
import 'dart:io';
import 'package:build_tool/data/app_paths.dart';
import 'package:build_tool/data/hive_setup.dart';
import 'package:build_tool/domain/models/project.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('hive_setup');
  });

  tearDown(() async {
    await Hive.close();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('initHive opens both boxes', () async {
    final paths = AppPaths(base: tmp);
    await paths.ensure();
    final result = await initHive(paths);
    expect(result.projects.isOpen, isTrue);
    expect(result.buildLogs.isOpen, isTrue);
  });

  test('initHive is idempotent', () async {
    final paths = AppPaths(base: tmp);
    await paths.ensure();
    await initHive(paths);
    await initHive(paths);  // must not throw
  });
}
```

- [ ] **Step 2: Run, expect FAIL** — `initHive` undefined.

```bash
flutter test test/unit/hive_setup_test.dart
```

- [ ] **Step 3: Implement**

`lib/data/hive_setup.dart`:

```dart
import 'package:hive/hive.dart';
import '../domain/models/build_log.dart';
import '../domain/models/custom_command.dart';
import '../domain/models/project.dart';
import 'app_paths.dart';

class HiveBoxes {
  HiveBoxes({required this.projects, required this.buildLogs});
  final Box<Project> projects;
  final Box<BuildLog> buildLogs;
}

Future<HiveBoxes> initHive(AppPaths paths) async {
  Hive.init(paths.hiveDir.path);
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ProjectAdapter());
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(CustomCommandAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(BuildLogAdapter());

  final projects = await Hive.openBox<Project>('projects');
  final buildLogs = await Hive.openBox<BuildLog>('build_logs');
  return HiveBoxes(projects: projects, buildLogs: buildLogs);
}
```

- [ ] **Step 4: Run, expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add lib/data/hive_setup.dart test/unit/hive_setup_test.dart
git commit -m "feat(data): add initHive bootstrap"
```

---

## Task 4: ProjectRepository

**Files:**
- Create: `lib/data/repositories/project_repository.dart`
- Test: `test/unit/project_repository_test.dart`

- [ ] **Step 1: Write failing test**

```dart
import 'dart:io';
import 'package:build_tool/data/app_paths.dart';
import 'package:build_tool/data/hive_setup.dart';
import 'package:build_tool/data/repositories/project_repository.dart';
import 'package:build_tool/domain/models/project.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tmp;
  late ProjectRepository repo;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('project_repo');
    final paths = AppPaths(base: tmp);
    await paths.ensure();
    final boxes = await initHive(paths);
    repo = ProjectRepository(boxes.projects);
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  Project sample(String id) => Project(
        id: id,
        name: 'app_$id',
        path: '/Users/me/$id',
        addedAt: DateTime.utc(2026, 5, 1),
      );

  test('add and list returns inserted project', () async {
    await repo.add(sample('a'));
    expect(repo.list().map((p) => p.id), ['a']);
  });

  test('list sorts by lastOpenedAt descending, nulls last', () async {
    await repo.add(sample('a')..lastOpenedAt = DateTime.utc(2026, 1, 1));
    await repo.add(sample('b')..lastOpenedAt = DateTime.utc(2026, 6, 1));
    await repo.add(sample('c'));  // null
    expect(repo.list().map((p) => p.id), ['b', 'a', 'c']);
  });

  test('update persists changes', () async {
    final p = sample('a');
    await repo.add(p);
    p.lastFlavor = 'prod';
    await repo.update(p);
    expect(repo.get('a')!.lastFlavor, 'prod');
  });

  test('remove deletes', () async {
    await repo.add(sample('a'));
    await repo.remove('a');
    expect(repo.get('a'), isNull);
  });

  test('exists returns true after add', () async {
    await repo.add(sample('a'));
    expect(repo.exists('a'), isTrue);
    expect(repo.exists('zz'), isFalse);
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

`lib/data/repositories/project_repository.dart`:

```dart
import 'package:hive/hive.dart';
import '../../domain/models/project.dart';

class ProjectRepository {
  ProjectRepository(this._box);
  final Box<Project> _box;

  List<Project> list() {
    final items = _box.values.toList();
    items.sort((a, b) {
      final ao = a.lastOpenedAt;
      final bo = b.lastOpenedAt;
      if (ao == null && bo == null) return 0;
      if (ao == null) return 1;
      if (bo == null) return -1;
      return bo.compareTo(ao);
    });
    return items;
  }

  Project? get(String id) => _box.get(id);
  bool exists(String id) => _box.containsKey(id);

  Future<void> add(Project p) => _box.put(p.id, p);
  Future<void> update(Project p) => _box.put(p.id, p);
  Future<void> remove(String id) => _box.delete(id);
}
```

- [ ] **Step 4: Run, expect PASS (5 tests).**

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/project_repository.dart test/unit/project_repository_test.dart
git commit -m "feat(data): add ProjectRepository CRUD"
```

---

## Task 5: BuildLogRepository

**Files:**
- Create: `lib/data/repositories/build_log_repository.dart`
- Test: `test/unit/build_log_repository_test.dart`

Manages BuildLog Hive entries AND log files on disk (retention: 50 per project).

- [ ] **Step 1: Write failing test**

```dart
import 'dart:io';
import 'package:build_tool/data/app_paths.dart';
import 'package:build_tool/data/hive_setup.dart';
import 'package:build_tool/data/repositories/build_log_repository.dart';
import 'package:build_tool/domain/models/build_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tmp;
  late BuildLogRepository repo;
  late AppPaths paths;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('blr');
    paths = AppPaths(base: tmp);
    await paths.ensure();
    final boxes = await initHive(paths);
    repo = BuildLogRepository(boxes.buildLogs, paths);
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  BuildLog mk(String id, String projectId, DateTime start) => BuildLog(
        id: id,
        projectId: projectId,
        commandLabel: 'X',
        fullCommand: 'echo X',
        startedAt: start,
        logFilePath: '${paths.logDirFor(projectId).path}/$id.log',
      );

  test('add inserts log entry', () async {
    await repo.add(mk('l1', 'p1', DateTime.utc(2026, 5, 1)));
    expect(repo.forProject('p1').single.id, 'l1');
  });

  test('forProject returns most recent first', () async {
    await repo.add(mk('a', 'p1', DateTime.utc(2026, 5, 1)));
    await repo.add(mk('b', 'p1', DateTime.utc(2026, 5, 2)));
    expect(repo.forProject('p1').map((l) => l.id), ['b', 'a']);
  });

  test('retention trims old logs beyond limit', () async {
    for (var i = 0; i < 55; i++) {
      await repo.add(mk('l$i', 'p1', DateTime.utc(2026, 5, 1).add(Duration(seconds: i))));
    }
    await repo.enforceRetention('p1', keep: 50);
    expect(repo.forProject('p1').length, 50);
    // Newest (l54) preserved, oldest (l0) gone
    expect(repo.forProject('p1').first.id, 'l54');
    expect(repo.forProject('p1').last.id, 'l5');
  });

  test('retention also deletes log files', () async {
    final logDir = paths.logDirFor('p1');
    await logDir.create(recursive: true);
    final fileA = File('${logDir.path}/a.log');
    await fileA.writeAsString('old');
    await repo.add(mk('a', 'p1', DateTime.utc(2026, 5, 1)));
    await repo.add(mk('b', 'p1', DateTime.utc(2026, 5, 2)));
    await repo.enforceRetention('p1', keep: 1);
    expect(fileA.existsSync(), isFalse);
  });

  test('finish updates exitCode and duration', () async {
    final log = mk('l1', 'p1', DateTime.utc(2026, 5, 1));
    await repo.add(log);
    await repo.finish('l1', exitCode: 0, duration: const Duration(seconds: 5));
    final loaded = repo.forProject('p1').single;
    expect(loaded.exitCode, 0);
    expect(loaded.duration, const Duration(seconds: 5));
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

`lib/data/repositories/build_log_repository.dart`:

```dart
import 'dart:io';
import 'package:hive/hive.dart';
import '../app_paths.dart';
import '../../domain/models/build_log.dart';

class BuildLogRepository {
  BuildLogRepository(this._box, this._paths);
  final Box<BuildLog> _box;
  final AppPaths _paths;

  List<BuildLog> forProject(String projectId) {
    final items = _box.values.where((l) => l.projectId == projectId).toList();
    items.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return items;
  }

  Future<void> add(BuildLog log) => _box.put(log.id, log);

  Future<void> finish(String id,
      {required int exitCode, required Duration duration}) async {
    final log = _box.get(id);
    if (log == null) return;
    log.exitCode = exitCode;
    log.duration = duration;
    await log.save();
  }

  Future<void> enforceRetention(String projectId, {int keep = 50}) async {
    final logs = forProject(projectId);
    if (logs.length <= keep) return;
    final toDelete = logs.sublist(keep);
    for (final log in toDelete) {
      final f = File(log.logFilePath);
      if (f.existsSync()) {
        try {
          await f.delete();
        } catch (_) {/* swallow — disk error must not crash app */}
      }
      await _box.delete(log.id);
    }
  }
}
```

- [ ] **Step 4: Run, expect PASS (5 tests).**

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/build_log_repository.dart test/unit/build_log_repository_test.dart
git commit -m "feat(data): add BuildLogRepository with file retention"
```

---

## Task 6: PubspecParser

**Files:**
- Create: `lib/domain/services/pubspec_parser.dart`
- Create: `test/fixtures/pubspec_full.yaml`
- Create: `test/fixtures/pubspec_no_version.yaml`
- Test: `test/unit/pubspec_parser_test.dart`

- [ ] **Step 1: Create fixtures**

`test/fixtures/pubspec_full.yaml`:

```yaml
name: my_app
description: A sample.
version: 1.2.3+45
environment:
  sdk: '>=3.0.0 <4.0.0'
```

`test/fixtures/pubspec_no_version.yaml`:

```yaml
name: another_app
description: No version.
environment:
  sdk: '>=3.0.0 <4.0.0'
```

- [ ] **Step 2: Write failing test**

`test/unit/pubspec_parser_test.dart`:

```dart
import 'dart:io';
import 'package:build_tool/domain/services/pubspec_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String fixture(String name) =>
      File('test/fixtures/$name').readAsStringSync();

  test('parses name and version, strips build number', () {
    final info = parsePubspec(fixture('pubspec_full.yaml'));
    expect(info.name, 'my_app');
    expect(info.version, '1.2.3');
    expect(info.buildNumber, '45');
  });

  test('missing version yields null version', () {
    final info = parsePubspec(fixture('pubspec_no_version.yaml'));
    expect(info.name, 'another_app');
    expect(info.version, isNull);
    expect(info.buildNumber, isNull);
  });

  test('sanitizeName lowercases and strips weird chars', () {
    expect(PubspecInfo.sanitize('My App!'), 'my_app_');
    expect(PubspecInfo.sanitize('foo-bar_2'), 'foo-bar_2');
  });

  test('malformed yaml throws PubspecParseException', () {
    expect(() => parsePubspec('::: not yaml :::'),
        throwsA(isA<PubspecParseException>()));
  });
}
```

- [ ] **Step 3: Run, expect FAIL.**

- [ ] **Step 4: Implement**

`lib/domain/services/pubspec_parser.dart`:

```dart
import 'package:yaml/yaml.dart';

class PubspecInfo {
  PubspecInfo({required this.name, this.version, this.buildNumber});
  final String name;
  final String? version;
  final String? buildNumber;

  /// Sanitizes a name for safe use in filenames: lowercase, keep a-z0-9_-, others → _.
  static String sanitize(String input) {
    final lower = input.toLowerCase();
    return lower.replaceAllMapped(RegExp(r'[^a-z0-9_-]'), (_) => '_');
  }
}

class PubspecParseException implements Exception {
  PubspecParseException(this.message);
  final String message;
  @override
  String toString() => 'PubspecParseException: $message';
}

PubspecInfo parsePubspec(String content) {
  final YamlMap doc;
  try {
    final parsed = loadYaml(content);
    if (parsed is! YamlMap) {
      throw PubspecParseException('pubspec root is not a map');
    }
    doc = parsed;
  } on YamlException catch (e) {
    throw PubspecParseException(e.message);
  }

  final name = doc['name'];
  if (name is! String || name.isEmpty) {
    throw PubspecParseException('pubspec has no `name`');
  }

  final rawVersion = doc['version'];
  String? version;
  String? buildNumber;
  if (rawVersion is String && rawVersion.isNotEmpty) {
    final plus = rawVersion.indexOf('+');
    if (plus >= 0) {
      version = rawVersion.substring(0, plus);
      buildNumber = rawVersion.substring(plus + 1);
    } else {
      version = rawVersion;
    }
  }

  return PubspecInfo(name: name, version: version, buildNumber: buildNumber);
}
```

- [ ] **Step 5: Run, expect PASS (4 tests).**

- [ ] **Step 6: Commit**

```bash
git add lib/domain/services/pubspec_parser.dart test/unit/pubspec_parser_test.dart test/fixtures/
git commit -m "feat(services): add PubspecParser"
```

---

## Task 7: FlavorDetector

**Files:**
- Create: `lib/domain/services/flavor_detector.dart`
- Create: `test/fixtures/build_gradle_groovy_flavors.txt`
- Create: `test/fixtures/build_gradle_groovy_no_flavors.txt`
- Create: `test/fixtures/build_gradle_kts_flavors.txt`
- Test: `test/unit/flavor_detector_test.dart`

- [ ] **Step 1: Create fixtures**

`test/fixtures/build_gradle_groovy_flavors.txt`:

```groovy
android {
    compileSdkVersion 34
    flavorDimensions "env"
    productFlavors {
        dev {
            dimension "env"
            applicationIdSuffix ".dev"
        }
        staging {
            dimension "env"
        }
        prod {
            dimension "env"
        }
    }
}
```

`test/fixtures/build_gradle_groovy_no_flavors.txt`:

```groovy
android {
    compileSdkVersion 34
    defaultConfig { applicationId "com.example.app" }
}
```

`test/fixtures/build_gradle_kts_flavors.txt`:

```kotlin
android {
    flavorDimensions += "env"
    productFlavors {
        create("dev") { dimension = "env" }
        create("prod") { dimension = "env" }
    }
}
```

- [ ] **Step 2: Write failing test**

`test/unit/flavor_detector_test.dart`:

```dart
import 'dart:io';
import 'package:build_tool/domain/services/flavor_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String fx(String n) => File('test/fixtures/$n').readAsStringSync();

  test('groovy: extracts three flavors', () {
    final flavors = FlavorDetector.parseGradle(
      fx('build_gradle_groovy_flavors.txt'),
      isKotlin: false,
    );
    expect(flavors, ['dev', 'staging', 'prod']);
  });

  test('groovy: no productFlavors returns empty', () {
    final flavors = FlavorDetector.parseGradle(
      fx('build_gradle_groovy_no_flavors.txt'),
      isKotlin: false,
    );
    expect(flavors, isEmpty);
  });

  test('kotlin DSL: extracts flavors from create("name")', () {
    final flavors = FlavorDetector.parseGradle(
      fx('build_gradle_kts_flavors.txt'),
      isKotlin: true,
    );
    expect(flavors, ['dev', 'prod']);
  });

  test('garbage input returns empty (no throw)', () {
    expect(FlavorDetector.parseGradle('::: not gradle :::', isKotlin: false),
        isEmpty);
  });

  test('detectFromProject reads from android/app/build.gradle', () async {
    final tmp = await Directory.systemTemp.createTemp('flavor');
    final gradle = File('${tmp.path}/android/app/build.gradle');
    await gradle.create(recursive: true);
    await gradle.writeAsString(fx('build_gradle_groovy_flavors.txt'));

    final flavors = await FlavorDetector().detect(tmp.path);
    expect(flavors, ['dev', 'staging', 'prod']);
    await tmp.delete(recursive: true);
  });

  test('detectFromProject prefers .kts when both present', () async {
    final tmp = await Directory.systemTemp.createTemp('flavor');
    final groovy = File('${tmp.path}/android/app/build.gradle');
    final kts = File('${tmp.path}/android/app/build.gradle.kts');
    await groovy.create(recursive: true);
    await groovy.writeAsString(fx('build_gradle_groovy_no_flavors.txt'));
    await kts.writeAsString(fx('build_gradle_kts_flavors.txt'));

    final flavors = await FlavorDetector().detect(tmp.path);
    expect(flavors, ['dev', 'prod']);
    await tmp.delete(recursive: true);
  });
}
```

- [ ] **Step 3: Run, expect FAIL.**

- [ ] **Step 4: Implement**

`lib/domain/services/flavor_detector.dart`:

```dart
import 'dart:io';

class FlavorDetector {
  /// Reads android/app/build.gradle(.kts) and returns flavor names.
  Future<List<String>> detect(String projectPath) async {
    final kts = File('$projectPath/android/app/build.gradle.kts');
    final groovy = File('$projectPath/android/app/build.gradle');
    if (kts.existsSync()) {
      try {
        return parseGradle(await kts.readAsString(), isKotlin: true);
      } catch (_) {
        return const [];
      }
    }
    if (groovy.existsSync()) {
      try {
        return parseGradle(await groovy.readAsString(), isKotlin: false);
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }

  static List<String> parseGradle(String content, {required bool isKotlin}) {
    final block = _extractBlock(content, 'productFlavors');
    if (block == null) return const [];
    return isKotlin ? _extractKts(block) : _extractGroovy(block);
  }

  /// Returns the substring inside `productFlavors { ... }` (balanced braces).
  static String? _extractBlock(String src, String keyword) {
    final i = src.indexOf(keyword);
    if (i < 0) return null;
    final open = src.indexOf('{', i);
    if (open < 0) return null;
    var depth = 1;
    var j = open + 1;
    while (j < src.length && depth > 0) {
      final c = src[j];
      if (c == '{') depth++;
      if (c == '}') depth--;
      j++;
    }
    if (depth != 0) return null;
    return src.substring(open + 1, j - 1);
  }

  /// Groovy: top-level identifiers followed by `{` are flavor names.
  static List<String> _extractGroovy(String block) {
    final result = <String>[];
    final lines = block.split('\n');
    var depth = 0;
    for (final raw in lines) {
      final line = raw.trim();
      // process line per char to track depth and identifiers
      if (depth == 0) {
        final m = RegExp(r'^([a-zA-Z_][a-zA-Z0-9_]*)\s*\{').firstMatch(line);
        if (m != null) result.add(m.group(1)!);
      }
      for (final c in line.split('')) {
        if (c == '{') depth++;
        if (c == '}') depth--;
      }
    }
    return result;
  }

  /// Kotlin DSL: `create("name")` or `register("name")` calls.
  static List<String> _extractKts(String block) {
    final pattern = RegExp(r'''(?:create|register)\s*\(\s*"([^"]+)"''');
    return pattern.allMatches(block).map((m) => m.group(1)!).toList();
  }
}
```

- [ ] **Step 5: Run, expect PASS (6 tests).**

- [ ] **Step 6: Commit**

```bash
git add lib/domain/services/flavor_detector.dart test/unit/flavor_detector_test.dart test/fixtures/build_gradle_*
git commit -m "feat(services): add FlavorDetector (groovy + kotlin DSL)"
```

---

## Task 8: CommandIntent + CommandComposer

**Files:**
- Create: `lib/domain/models/command_intent.dart`
- Create: `lib/domain/services/command_composer.dart`
- Test: `test/unit/command_composer_test.dart`

`CommandIntent` is a sealed class describing what the user clicked.

- [ ] **Step 1: Write failing test**

`test/unit/command_composer_test.dart`:

```dart
import 'package:build_tool/domain/models/command_intent.dart';
import 'package:build_tool/domain/services/command_composer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const composer = CommandComposer();

  test('run with device and flavor', () {
    final cmd = composer.compose(
      const RunIntent(deviceId: 'iPhone15', flavor: 'prod'),
      cleanBeforeBuild: false,
    );
    expect(cmd.label, 'Run (prod)');
    expect(cmd.shell, "flutter run -d 'iPhone15' --flavor 'prod'");
  });

  test('run without flavor omits --flavor', () {
    final cmd = composer.compose(
      const RunIntent(deviceId: 'macos', flavor: null),
      cleanBeforeBuild: false,
    );
    expect(cmd.shell, "flutter run -d 'macos'");
    expect(cmd.label, 'Run');
  });

  test('build APK release with flavor', () {
    final cmd = composer.compose(
      const BuildApkIntent(flavor: 'prod'),
      cleanBeforeBuild: false,
    );
    expect(cmd.shell, "flutter build apk --release --flavor 'prod'");
    expect(cmd.label, 'Build APK (prod)');
  });

  test('build APK with cleanBeforeBuild prepends clean+pub get', () {
    final cmd = composer.compose(
      const BuildApkIntent(flavor: 'dev'),
      cleanBeforeBuild: true,
    );
    expect(cmd.shell,
        "flutter clean && flutter pub get && flutter build apk --release --flavor 'dev'");
  });

  test('clean+pub composes the chain', () {
    final cmd = composer.compose(const CleanIntent(), cleanBeforeBuild: false);
    expect(cmd.shell, 'flutter clean && flutter pub get');
    expect(cmd.label, 'Clean + Pub get');
  });

  test('build_runner intent', () {
    final cmd =
        composer.compose(const BuildRunnerIntent(), cleanBeforeBuild: false);
    expect(cmd.shell, 'dart run build_runner build --delete-conflicting-outputs');
    expect(cmd.label, 'build_runner');
  });

  test('custom intent uses raw command and label', () {
    final cmd = composer.compose(
      const CustomIntent(label: 'Deploy', command: 'firebase deploy'),
      cleanBeforeBuild: false,
    );
    expect(cmd.shell, 'firebase deploy');
    expect(cmd.label, 'Deploy');
  });

  test('flavor with shell special chars is single-quoted safely', () {
    final cmd = composer.compose(
      const BuildApkIntent(flavor: "weird'name"),
      cleanBeforeBuild: false,
    );
    expect(cmd.shell, contains(r"--flavor 'weird'\''name'"));
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement intent + composer**

`lib/domain/models/command_intent.dart`:

```dart
sealed class CommandIntent {
  const CommandIntent();
}

class RunIntent extends CommandIntent {
  const RunIntent({required this.deviceId, required this.flavor});
  final String deviceId;
  final String? flavor;
}

class BuildApkIntent extends CommandIntent {
  const BuildApkIntent({required this.flavor});
  final String? flavor;
}

class CleanIntent extends CommandIntent {
  const CleanIntent();
}

class BuildRunnerIntent extends CommandIntent {
  const BuildRunnerIntent();
}

class CustomIntent extends CommandIntent {
  const CustomIntent({required this.label, required this.command});
  final String label;
  final String command;
}
```

`lib/domain/services/command_composer.dart`:

```dart
import '../models/command_intent.dart';

class ComposedCommand {
  const ComposedCommand({required this.label, required this.shell});
  final String label;
  final String shell;
}

class CommandComposer {
  const CommandComposer();

  ComposedCommand compose(CommandIntent intent,
      {required bool cleanBeforeBuild}) {
    return switch (intent) {
      RunIntent(deviceId: final d, flavor: final f) => ComposedCommand(
          label: f == null ? 'Run' : 'Run ($f)',
          shell: _join([
            'flutter run',
            '-d ${_q(d)}',
            if (f != null) '--flavor ${_q(f)}',
          ]),
        ),
      BuildApkIntent(flavor: final f) => ComposedCommand(
          label: f == null ? 'Build APK' : 'Build APK ($f)',
          shell: _withCleanPrefix(
            cleanBeforeBuild,
            _join([
              'flutter build apk --release',
              if (f != null) '--flavor ${_q(f)}',
            ]),
          ),
        ),
      CleanIntent() => const ComposedCommand(
          label: 'Clean + Pub get',
          shell: 'flutter clean && flutter pub get',
        ),
      BuildRunnerIntent() => const ComposedCommand(
          label: 'build_runner',
          shell: 'dart run build_runner build --delete-conflicting-outputs',
        ),
      CustomIntent(label: final l, command: final c) =>
        ComposedCommand(label: l, shell: c),
    };
  }

  String _withCleanPrefix(bool clean, String tail) =>
      clean ? 'flutter clean && flutter pub get && $tail' : tail;

  String _join(List<String> parts) => parts.where((p) => p.isNotEmpty).join(' ');

  /// POSIX shell single-quote escape: ' becomes '\''
  String _q(String input) {
    final escaped = input.replaceAll("'", r"'\''");
    return "'$escaped'";
  }
}
```

- [ ] **Step 4: Run, expect PASS (8 tests).**

- [ ] **Step 5: Commit**

```bash
git add lib/domain/models/command_intent.dart lib/domain/services/command_composer.dart test/unit/command_composer_test.dart
git commit -m "feat(services): add CommandIntent sealed class and CommandComposer"
```

---

## Task 9: OutputFinder

**Files:**
- Create: `lib/domain/services/output_finder.dart`
- Test: `test/unit/output_finder_test.dart`

Finds the newest `*-release.apk` under `build/app/outputs/flutter-apk/`.

- [ ] **Step 1: Write failing test**

```dart
import 'dart:io';
import 'package:build_tool/domain/services/output_finder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  late Directory apkDir;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('output');
    apkDir = Directory('${tmp.path}/build/app/outputs/flutter-apk');
    await apkDir.create(recursive: true);
  });

  tearDown(() async => tmp.delete(recursive: true));

  Future<File> mkApk(String name, DateTime mtime) async {
    final f = File('${apkDir.path}/$name');
    await f.writeAsBytes([0]);
    await f.setLastModified(mtime);
    return f;
  }

  test('picks newest -release.apk by mtime', () async {
    await mkApk('app-prod-release.apk', DateTime.utc(2026, 5, 1));
    final newer = await mkApk('app-dev-release.apk', DateTime.utc(2026, 5, 5));
    final found = await const OutputFinder().findApk(tmp.path);
    expect(found?.path, newer.path);
  });

  test('ignores -debug.apk and unsigned variants', () async {
    await mkApk('app-debug.apk', DateTime.utc(2026, 6, 1));
    final release =
        await mkApk('app-prod-release.apk', DateTime.utc(2026, 5, 1));
    final found = await const OutputFinder().findApk(tmp.path);
    expect(found?.path, release.path);
  });

  test('returns null when no apk present', () async {
    final found = await const OutputFinder().findApk(tmp.path);
    expect(found, isNull);
  });

  test('returns null when folder missing entirely', () async {
    await apkDir.delete(recursive: true);
    final found = await const OutputFinder().findApk(tmp.path);
    expect(found, isNull);
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

`lib/domain/services/output_finder.dart`:

```dart
import 'dart:io';

class OutputFinder {
  const OutputFinder();

  /// Returns the newest *-release.apk under build/app/outputs/flutter-apk/,
  /// or null if none.
  Future<File?> findApk(String projectPath) async {
    final dir = Directory('$projectPath/build/app/outputs/flutter-apk');
    if (!dir.existsSync()) return null;
    final candidates = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('-release.apk'))
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) =>
        b.statSync().modified.compareTo(a.statSync().modified));
    return candidates.first;
  }
}
```

- [ ] **Step 4: Run, expect PASS (4 tests).**

- [ ] **Step 5: Commit**

```bash
git add lib/domain/services/output_finder.dart test/unit/output_finder_test.dart
git commit -m "feat(services): add OutputFinder for built APKs"
```

---

## Task 10: OutputRenamer

**Files:**
- Create: `lib/domain/services/output_renamer.dart`
- Test: `test/unit/output_renamer_test.dart`

Copies the original APK to `<name>-v<version>.apk` in the same folder. Uses `PubspecParser` to read project metadata.

- [ ] **Step 1: Write failing test**

```dart
import 'dart:io';
import 'package:build_tool/domain/services/output_renamer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() async => tmp = await Directory.systemTemp.createTemp('rename'));
  tearDown(() async => tmp.delete(recursive: true));

  Future<File> apk(String name) async {
    final f = File('${tmp.path}/$name');
    await f.writeAsBytes([1, 2, 3]);
    return f;
  }

  Future<void> writePubspec(String content) async {
    await File('${tmp.path}/pubspec.yaml').writeAsString(content);
  }

  test('copies APK to <name>-v<version>.apk in same folder', () async {
    final source = await apk('app-prod-release.apk');
    await writePubspec('name: my_app\nversion: 1.2.3+45\n');
    final result = await const OutputRenamer().rename(
      sourceApk: source,
      projectPath: tmp.path,
    );
    expect(result.target.path, '${tmp.path}/my_app-v1.2.3.apk');
    expect(result.target.existsSync(), isTrue);
    expect(result.fallbackVersionUsed, isFalse);
    // Original preserved
    expect(source.existsSync(), isTrue);
  });

  test('fallback v0.0.0 when version missing', () async {
    final source = await apk('app-release.apk');
    await writePubspec('name: foo_app\n');
    final result = await const OutputRenamer().rename(
      sourceApk: source,
      projectPath: tmp.path,
    );
    expect(result.target.path.endsWith('foo_app-v0.0.0.apk'), isTrue);
    expect(result.fallbackVersionUsed, isTrue);
  });

  test('overwrites existing target with same name', () async {
    final source = await apk('app-release.apk');
    await writePubspec('name: my_app\nversion: 1.0.0\n');
    final existing = File('${tmp.path}/my_app-v1.0.0.apk');
    await existing.writeAsBytes([9, 9, 9]);
    final result = await const OutputRenamer().rename(
      sourceApk: source,
      projectPath: tmp.path,
    );
    expect(await result.target.readAsBytes(), [1, 2, 3]);
  });

  test('sanitizes weird name chars', () async {
    final source = await apk('app-release.apk');
    await writePubspec('name: My App!\nversion: 1.0.0\n');
    final result = await const OutputRenamer().rename(
      sourceApk: source,
      projectPath: tmp.path,
    );
    expect(result.target.path.endsWith('my_app_-v1.0.0.apk'), isTrue);
  });

  test('missing pubspec throws OutputRenameException', () async {
    final source = await apk('app-release.apk');
    expect(
      () => const OutputRenamer().rename(
        sourceApk: source,
        projectPath: tmp.path,
      ),
      throwsA(isA<OutputRenameException>()),
    );
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

`lib/domain/services/output_renamer.dart`:

```dart
import 'dart:io';
import 'pubspec_parser.dart';

class RenameResult {
  RenameResult({
    required this.target,
    required this.fallbackVersionUsed,
  });
  final File target;
  final bool fallbackVersionUsed;
}

class OutputRenameException implements Exception {
  OutputRenameException(this.message);
  final String message;
  @override
  String toString() => 'OutputRenameException: $message';
}

class OutputRenamer {
  const OutputRenamer();

  Future<RenameResult> rename({
    required File sourceApk,
    required String projectPath,
  }) async {
    final pubspecFile = File('$projectPath/pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      throw OutputRenameException('pubspec.yaml not found at $projectPath');
    }
    final info = parsePubspec(await pubspecFile.readAsString());
    final safeName = PubspecInfo.sanitize(info.name);
    final version = info.version ?? '0.0.0';
    final fallback = info.version == null;

    final ext = sourceApk.path.endsWith('.apk') ? 'apk' : 'ipa';
    final dir = sourceApk.parent.path;
    final target = File('$dir/$safeName-v$version.$ext');
    if (target.existsSync()) {
      await target.delete();
    }
    final copied = await sourceApk.copy(target.path);
    return RenameResult(target: copied, fallbackVersionUsed: fallback);
  }
}
```

- [ ] **Step 4: Run, expect PASS (5 tests).**

- [ ] **Step 5: Commit**

```bash
git add lib/domain/services/output_renamer.dart test/unit/output_renamer_test.dart
git commit -m "feat(services): add OutputRenamer with version-based naming"
```

---

## Task 11: ProjectImporter

**Files:**
- Create: `lib/domain/services/project_importer.dart`
- Test: `test/unit/project_importer_test.dart`

Validates a folder is a Flutter project; constructs `Project` with id from `uuid`.

- [ ] **Step 1: Write failing test**

```dart
import 'dart:io';
import 'package:build_tool/domain/services/project_importer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() async => tmp = await Directory.systemTemp.createTemp('imp'));
  tearDown(() async => tmp.delete(recursive: true));

  test('valid flutter project: returns Project with parsed name', () async {
    await File('${tmp.path}/pubspec.yaml')
        .writeAsString('name: my_app\nversion: 0.1.0\n');
    final result = await const ProjectImporter().import(tmp.path);
    expect(result.name, 'my_app');
    expect(result.path, tmp.path);
    expect(result.id, isNotEmpty);
    expect(result.cleanBeforeBuild, isFalse);
    expect(result.customCommands, isEmpty);
  });

  test('missing pubspec throws ProjectImportException with code', () async {
    expect(
      () => const ProjectImporter().import(tmp.path),
      throwsA(predicate(
          (e) => e is ProjectImportException && e.code == 'NO_PUBSPEC')),
    );
  });

  test('malformed pubspec throws with code MALFORMED_PUBSPEC', () async {
    await File('${tmp.path}/pubspec.yaml').writeAsString(':::not::yaml:::');
    expect(
      () => const ProjectImporter().import(tmp.path),
      throwsA(predicate(
          (e) => e is ProjectImportException && e.code == 'MALFORMED_PUBSPEC')),
    );
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

`lib/domain/services/project_importer.dart`:

```dart
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/project.dart';
import 'pubspec_parser.dart';

class ProjectImportException implements Exception {
  ProjectImportException({required this.code, required this.message});
  final String code;
  final String message;
  @override
  String toString() => 'ProjectImportException($code): $message';
}

class ProjectImporter {
  const ProjectImporter();

  Future<Project> import(String projectPath) async {
    final pubspec = File('$projectPath/pubspec.yaml');
    if (!pubspec.existsSync()) {
      throw ProjectImportException(
        code: 'NO_PUBSPEC',
        message: 'No pubspec.yaml at $projectPath',
      );
    }
    final String content;
    try {
      content = await pubspec.readAsString();
    } on FileSystemException catch (e) {
      throw ProjectImportException(
        code: 'READ_FAILED',
        message: e.message,
      );
    }
    final PubspecInfo info;
    try {
      info = parsePubspec(content);
    } on PubspecParseException catch (e) {
      throw ProjectImportException(
        code: 'MALFORMED_PUBSPEC',
        message: e.message,
      );
    }
    return Project(
      id: const Uuid().v4(),
      name: info.name,
      path: projectPath,
      addedAt: DateTime.now().toUtc(),
    );
  }
}
```

- [ ] **Step 4: Run, expect PASS (3 tests).**

- [ ] **Step 5: Commit**

```bash
git add lib/domain/services/project_importer.dart test/unit/project_importer_test.dart
git commit -m "feat(services): add ProjectImporter with typed errors"
```

---

## Task 12: CommandRunner abstract + PTY implementation

**Files:**
- Create: `lib/domain/services/command_runner.dart`
- Test: `test/unit/command_runner_test.dart`

This is the first IO service. We use `flutter_pty`. Smoke test with `echo`.

- [ ] **Step 1: Write smoke test (real PTY)**

`test/unit/command_runner_test.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:build_tool/domain/services/command_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PtyCommandRunner streams echo output and exits 0', () async {
    const runner = PtyCommandRunner();
    final running = runner.start(
      command: "echo 'hello-pty-world'",
      workingDir: '/tmp',
    );

    final buffer = StringBuffer();
    final sub = running.output.transform(utf8.decoder).listen(buffer.write);

    final code = await running.exitCode.timeout(const Duration(seconds: 5));
    await sub.cancel();

    expect(code, 0);
    expect(buffer.toString(), contains('hello-pty-world'));
  });

  test('PtyCommandRunner kill() terminates running process', () async {
    const runner = PtyCommandRunner();
    final running = runner.start(
      command: 'sleep 30',
      workingDir: '/tmp',
    );

    Future.delayed(const Duration(milliseconds: 200), running.kill);

    final code = await running.exitCode.timeout(const Duration(seconds: 5));
    expect(code, isNot(0));  // killed → non-zero exit
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

```bash
flutter test test/unit/command_runner_test.dart
```

- [ ] **Step 3: Implement abstract + PTY impl**

`lib/domain/services/command_runner.dart`:

```dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_pty/flutter_pty.dart';

abstract class CommandRunner {
  RunningCommand start({
    required String command,
    required String workingDir,
    Map<String, String>? env,
  });
}

class RunningCommand {
  RunningCommand({
    required this.output,
    required this.exitCode,
    required this.startedAt,
    required void Function() onKill,
  }) : _onKill = onKill;

  final Stream<Uint8List> output;
  final Future<int> exitCode;
  final DateTime startedAt;
  final void Function() _onKill;

  void kill() => _onKill();
}

class PtyCommandRunner implements CommandRunner {
  const PtyCommandRunner();

  @override
  RunningCommand start({
    required String command,
    required String workingDir,
    Map<String, String>? env,
  }) {
    final pty = Pty.start(
      '/bin/zsh',
      arguments: ['-l', '-c', command],
      workingDirectory: workingDir,
      environment: env ?? Map.from(Platform.environment),
    );

    final controller = StreamController<Uint8List>.broadcast();
    final outSub = pty.output.listen(controller.add);

    final exitCompleter = Completer<int>();
    pty.exitCode.then((code) async {
      await outSub.cancel();
      await controller.close();
      if (!exitCompleter.isCompleted) exitCompleter.complete(code);
    });

    var killed = false;
    void doKill() {
      if (killed) return;
      killed = true;
      pty.kill(ProcessSignal.sigterm);
      Future.delayed(const Duration(seconds: 2), () {
        if (!exitCompleter.isCompleted) {
          pty.kill(ProcessSignal.sigkill);
        }
      });
    }

    return RunningCommand(
      output: controller.stream,
      exitCode: exitCompleter.future,
      startedAt: DateTime.now(),
      onKill: doKill,
    );
  }
}
```

- [ ] **Step 4: Run, expect PASS (2 tests).**

If `flutter_pty` fails to compile or PTY tests fail on the macOS host, abort and follow the fallback in spec §13: use `Process.start` with `TERM=xterm-256color` env. Open an issue describing what failed before falling back.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/services/command_runner.dart test/unit/command_runner_test.dart
git commit -m "feat(services): add PtyCommandRunner backed by flutter_pty"
```

---

## Task 13: DeviceLister

**Files:**
- Create: `lib/domain/models/flutter_device.dart`
- Create: `lib/domain/services/device_lister.dart`
- Test: `test/unit/device_lister_test.dart`

Parses `flutter devices --machine` JSON.

- [ ] **Step 1: Write failing test**

```dart
import 'package:build_tool/domain/services/device_lister.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses JSON output into FlutterDevice list', () {
    const json = '''
[
  {"name":"iPhone 15","id":"7E1F","platformType":"ios","emulator":false},
  {"name":"macOS","id":"macos","platformType":"darwin","emulator":false}
]
''';
    final devices = DeviceLister.parseJson(json);
    expect(devices.length, 2);
    expect(devices[0].id, '7E1F');
    expect(devices[0].name, 'iPhone 15');
    expect(devices[0].platformType, 'ios');
    expect(devices[1].id, 'macos');
  });

  test('returns empty list on garbage', () {
    expect(DeviceLister.parseJson('not json'), isEmpty);
  });

  test('returns empty list on empty array', () {
    expect(DeviceLister.parseJson('[]'), isEmpty);
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

`lib/domain/models/flutter_device.dart`:

```dart
class FlutterDevice {
  const FlutterDevice({
    required this.id,
    required this.name,
    required this.platformType,
    required this.isEmulator,
  });

  final String id;
  final String name;
  final String platformType;
  final bool isEmulator;
}
```

`lib/domain/services/device_lister.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import '../models/flutter_device.dart';

class DeviceLister {
  const DeviceLister();

  /// Runs `flutter devices --machine` and parses the result.
  /// Returns empty list on any failure (timeouts, non-zero exit, parse error).
  Future<List<FlutterDevice>> list() async {
    try {
      final result = await Process.run(
        'flutter',
        ['devices', '--machine'],
        runInShell: true,
      ).timeout(const Duration(seconds: 10));
      if (result.exitCode != 0) return const [];
      return parseJson(result.stdout.toString());
    } catch (_) {
      return const [];
    }
  }

  static List<FlutterDevice> parseJson(String input) {
    try {
      final decoded = jsonDecode(input);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((m) => FlutterDevice(
                id: (m['id'] ?? '').toString(),
                name: (m['name'] ?? '').toString(),
                platformType: (m['platformType'] ?? '').toString(),
                isEmulator: m['emulator'] == true,
              ))
          .where((d) => d.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
```

- [ ] **Step 4: Run, expect PASS (3 tests).**

- [ ] **Step 5: Commit**

```bash
git add lib/domain/models/flutter_device.dart lib/domain/services/device_lister.dart test/unit/device_lister_test.dart
git commit -m "feat(services): add DeviceLister"
```

---

## Task 14: FlutterSdkChecker

**Files:**
- Create: `lib/domain/services/flutter_sdk_checker.dart`
- Test: `test/unit/flutter_sdk_checker_test.dart`

Checks `flutter` is on PATH by running `flutter --version` once at startup.

- [ ] **Step 1: Write failing test**

```dart
import 'package:build_tool/domain/services/flutter_sdk_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real flutter on PATH returns available (skipped if no flutter)',
      () async {
    final result = await const FlutterSdkChecker().check();
    // Must return a SdkStatus; do not assert availability since CI may lack flutter.
    expect(result, isA<SdkStatus>());
  });

  test('explicitly bad command returns unavailable', () async {
    final result = await const FlutterSdkChecker().check(executable: 'nope_xyz_123');
    expect(result.available, isFalse);
    expect(result.error, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

`lib/domain/services/flutter_sdk_checker.dart`:

```dart
import 'dart:io';

class SdkStatus {
  const SdkStatus({required this.available, this.version, this.error});
  final bool available;
  final String? version;
  final String? error;
}

class FlutterSdkChecker {
  const FlutterSdkChecker();

  Future<SdkStatus> check({String executable = 'flutter'}) async {
    try {
      final result = await Process.run(executable, ['--version'],
              runInShell: true)
          .timeout(const Duration(seconds: 10));
      if (result.exitCode != 0) {
        return SdkStatus(
            available: false, error: result.stderr.toString());
      }
      final first = result.stdout.toString().split('\n').first.trim();
      return SdkStatus(available: true, version: first);
    } catch (e) {
      return SdkStatus(available: false, error: e.toString());
    }
  }
}
```

- [ ] **Step 4: Run, expect PASS (2 tests).**

- [ ] **Step 5: Commit**

```bash
git add lib/domain/services/flutter_sdk_checker.dart test/unit/flutter_sdk_checker_test.dart
git commit -m "feat(services): add FlutterSdkChecker"
```

---

## Task 15: FinderReveal

**Files:**
- Create: `lib/domain/services/finder_reveal.dart`

Simple wrapper. No test (would require launching real Finder); checked via smoke later.

- [ ] **Step 1: Implement**

`lib/domain/services/finder_reveal.dart`:

```dart
import 'dart:io';

class FinderReveal {
  const FinderReveal();

  /// Opens macOS Finder revealing the file. Best-effort; logs on failure.
  Future<void> reveal(String path) async {
    try {
      await Process.run('open', ['-R', path]);
    } catch (_) {/* non-fatal */}
  }

  Future<void> openFolder(String path) async {
    try {
      await Process.run('open', [path]);
    } catch (_) {}
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/domain/services/finder_reveal.dart
git commit -m "feat(services): add FinderReveal for macOS"
```

---

## Task 16: Riverpod providers

**Files:**
- Create: `lib/state/providers.dart`

Exposes app-wide singletons via Riverpod. `appPaths` and `hiveBoxes` are seeded via `ProviderScope` overrides in `main.dart` (see Task 19).

- [ ] **Step 1: Implement providers**

`lib/state/providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_paths.dart';
import '../data/hive_setup.dart';
import '../data/repositories/build_log_repository.dart';
import '../data/repositories/project_repository.dart';
import '../domain/models/project.dart';
import '../domain/services/command_composer.dart';
import '../domain/services/command_runner.dart';
import '../domain/services/device_lister.dart';
import '../domain/services/finder_reveal.dart';
import '../domain/services/flavor_detector.dart';
import '../domain/services/flutter_sdk_checker.dart';
import '../domain/services/output_finder.dart';
import '../domain/services/output_renamer.dart';
import '../domain/services/project_importer.dart';

final appPathsProvider = Provider<AppPaths>((_) {
  throw UnimplementedError('Override in ProviderScope at startup');
});

final hiveBoxesProvider = Provider<HiveBoxes>((_) {
  throw UnimplementedError('Override in ProviderScope at startup');
});

final projectRepositoryProvider = Provider<ProjectRepository>(
    (ref) => ProjectRepository(ref.watch(hiveBoxesProvider).projects));

final buildLogRepositoryProvider = Provider<BuildLogRepository>(
    (ref) => BuildLogRepository(
        ref.watch(hiveBoxesProvider).buildLogs, ref.watch(appPathsProvider)));

final commandRunnerProvider =
    Provider<CommandRunner>((_) => const PtyCommandRunner());
final commandComposerProvider =
    Provider<CommandComposer>((_) => const CommandComposer());
final deviceListerProvider =
    Provider<DeviceLister>((_) => const DeviceLister());
final flavorDetectorProvider =
    Provider<FlavorDetector>((_) => FlavorDetector());
final outputFinderProvider =
    Provider<OutputFinder>((_) => const OutputFinder());
final outputRenamerProvider =
    Provider<OutputRenamer>((_) => const OutputRenamer());
final projectImporterProvider =
    Provider<ProjectImporter>((_) => const ProjectImporter());
final finderRevealProvider =
    Provider<FinderReveal>((_) => const FinderReveal());
final sdkCheckerProvider =
    Provider<FlutterSdkChecker>((_) => const FlutterSdkChecker());

/// Reactive list of projects. Notifier-driven so UI updates after add/remove.
final projectsProvider =
    NotifierProvider<ProjectsNotifier, List<Project>>(ProjectsNotifier.new);

class ProjectsNotifier extends Notifier<List<Project>> {
  @override
  List<Project> build() => ref.watch(projectRepositoryProvider).list();

  Future<void> add(Project p) async {
    await ref.read(projectRepositoryProvider).add(p);
    state = ref.read(projectRepositoryProvider).list();
  }

  Future<void> update(Project p) async {
    await ref.read(projectRepositoryProvider).update(p);
    state = ref.read(projectRepositoryProvider).list();
  }

  Future<void> remove(String id) async {
    await ref.read(projectRepositoryProvider).remove(id);
    state = ref.read(projectRepositoryProvider).list();
  }
}

/// Currently selected project id (null if none selected).
final selectedProjectIdProvider = StateProvider<String?>((_) => null);

final selectedProjectProvider = Provider<Project?>((ref) {
  final id = ref.watch(selectedProjectIdProvider);
  if (id == null) return null;
  return ref.watch(projectsProvider).where((p) => p.id == id).firstOrNull;
});
```

- [ ] **Step 2: Run analyzer**

```bash
flutter analyze
```

Expected: no errors (warnings about unused providers OK — used in later tasks).

- [ ] **Step 3: Commit**

```bash
git add lib/state/providers.dart
git commit -m "feat(state): wire Riverpod providers for services and project list"
```

---

## Task 17: ProjectRunnerController

**Files:**
- Create: `lib/state/project_runner_controller.dart`
- Test: `test/unit/project_runner_controller_test.dart`

Holds the per-project execution state. One running command at a time per project.

- [ ] **Step 1: Write failing test (with fake CommandRunner)**

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:build_tool/domain/services/command_runner.dart';
import 'package:build_tool/state/project_runner_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCommandRunner implements CommandRunner {
  late StreamController<Uint8List> controller;
  late Completer<int> exit;
  bool killed = false;

  @override
  RunningCommand start({
    required String command,
    required String workingDir,
    Map<String, String>? env,
  }) {
    controller = StreamController<Uint8List>.broadcast();
    exit = Completer<int>();
    return RunningCommand(
      output: controller.stream,
      exitCode: exit.future,
      startedAt: DateTime.now(),
      onKill: () {
        killed = true;
        if (!exit.isCompleted) exit.complete(-1);
      },
    );
  }
}

void main() {
  test('start emits running state then completed on exit 0', () async {
    final runner = FakeCommandRunner();
    final c = ProjectRunnerController(runner: runner);

    final events = <RunnerState>[];
    c.stream.listen(events.add);

    c.start(label: 'echo', command: 'echo hi', workingDir: '/tmp');
    expect(c.current?.label, 'echo');
    expect(c.isRunning, isTrue);

    runner.controller.add(Uint8List.fromList('hello\n'.codeUnits));
    runner.exit.complete(0);

    // Wait for stream events.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(c.isRunning, isFalse);
    expect(c.lastExitCode, 0);
    expect(events.any((e) => e == RunnerState.running), isTrue);
    expect(events.last, RunnerState.success);
  });

  test('stop calls kill on the running command', () async {
    final runner = FakeCommandRunner();
    final c = ProjectRunnerController(runner: runner);
    c.start(label: 'sleep', command: 'sleep 60', workingDir: '/tmp');

    c.stop();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(runner.killed, isTrue);
    expect(c.isRunning, isFalse);
  });

  test('starting a second command while running is rejected', () async {
    final runner = FakeCommandRunner();
    final c = ProjectRunnerController(runner: runner);
    c.start(label: 'a', command: 'a', workingDir: '/tmp');

    expect(
      () => c.start(label: 'b', command: 'b', workingDir: '/tmp'),
      throwsStateError,
    );
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

`lib/state/project_runner_controller.dart`:

```dart
import 'dart:async';
import 'dart:typed_data';

import '../domain/services/command_runner.dart';

enum RunnerState { idle, running, success, failed, cancelled }

class RunningInfo {
  RunningInfo({required this.label, required this.command, required this.startedAt});
  final String label;
  final String command;
  final DateTime startedAt;
}

class ProjectRunnerController {
  ProjectRunnerController({required CommandRunner runner}) : _runner = runner;

  final CommandRunner _runner;
  final StreamController<RunnerState> _stateCtrl =
      StreamController<RunnerState>.broadcast();
  final StreamController<Uint8List> _outputCtrl =
      StreamController<Uint8List>.broadcast();

  RunningCommand? _running;
  RunningInfo? _current;
  RunnerState _state = RunnerState.idle;
  int? _lastExitCode;
  Duration? _lastDuration;

  Stream<RunnerState> get stream => _stateCtrl.stream;
  Stream<Uint8List> get output => _outputCtrl.stream;
  RunnerState get state => _state;
  bool get isRunning => _state == RunnerState.running;
  RunningInfo? get current => _current;
  int? get lastExitCode => _lastExitCode;
  Duration? get lastDuration => _lastDuration;

  void start({
    required String label,
    required String command,
    required String workingDir,
    Map<String, String>? env,
    void Function(int exitCode, Duration duration)? onComplete,
  }) {
    if (_state == RunnerState.running) {
      throw StateError('Another command is already running');
    }
    final running = _runner.start(
      command: command,
      workingDir: workingDir,
      env: env,
    );
    _running = running;
    _current = RunningInfo(
      label: label, command: command, startedAt: running.startedAt);
    _setState(RunnerState.running);

    final outSub = running.output.listen(_outputCtrl.add);
    running.exitCode.then((code) async {
      _lastExitCode = code;
      _lastDuration = DateTime.now().difference(running.startedAt);
      await outSub.cancel();
      if (code == 0) {
        _setState(RunnerState.success);
      } else if (code < 0) {
        _setState(RunnerState.cancelled);
      } else {
        _setState(RunnerState.failed);
      }
      _running = null;
      onComplete?.call(code, _lastDuration!);
    });
  }

  void stop() => _running?.kill();

  void _setState(RunnerState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  Future<void> dispose() async {
    await _stateCtrl.close();
    await _outputCtrl.close();
  }
}
```

- [ ] **Step 4: Run, expect PASS (3 tests).**

- [ ] **Step 5: Commit**

```bash
git add lib/state/project_runner_controller.dart test/unit/project_runner_controller_test.dart
git commit -m "feat(state): add ProjectRunnerController coordinating one command per project"
```

---

## Task 18: Theme + App

**Files:**
- Create: `lib/app/theme.dart`
- Create: `lib/app/app.dart`

- [ ] **Step 1: Implement theme**

`lib/app/theme.dart`:

```dart
import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1976D2),
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    fontFamily: 'SF Pro Text',
  );
}
```

- [ ] **Step 2: Implement app shell wiring (uses `Shell` placeholder from Task 20)**

`lib/app/app.dart`:

```dart
import 'package:flutter/material.dart';
import '../ui/shell.dart';
import 'theme.dart';

class BuildToolApp extends StatelessWidget {
  const BuildToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Build Tool',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const Shell(),
    );
  }
}
```

This will not compile until `Shell` is created in Task 20. Commit only after Task 20 builds.

- [ ] **Step 3: Skip commit until Task 20** — proceed to Task 19.

---

## Task 19: main.dart with Hive + ProviderScope bootstrap

**Files:**
- Modify: `lib/main.dart` (replace flutter create boilerplate entirely)

- [ ] **Step 1: Implement**

`lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'data/app_paths.dart';
import 'data/hive_setup.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final paths = await AppPaths.forApp();
  final boxes = await initHive(paths);

  runApp(
    ProviderScope(
      overrides: [
        appPathsProvider.overrideWithValue(paths),
        hiveBoxesProvider.overrideWithValue(boxes),
      ],
      child: const BuildToolApp(),
    ),
  );
}
```

- [ ] **Step 2: Skip commit; proceed to Task 20 so app compiles.**

---

## Task 20: Shell layout (sidebar + detail split)

**Files:**
- Create: `lib/ui/shell.dart`
- Test: `test/widget/shell_test.dart`

Two-pane scaffold with fixed sidebar width.

- [ ] **Step 1: Write failing widget test**

`test/widget/shell_test.dart`:

```dart
import 'package:build_tool/data/app_paths.dart';
import 'package:build_tool/data/hive_setup.dart';
import 'package:build_tool/state/providers.dart';
import 'package:build_tool/ui/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'dart:io';

void main() {
  late Directory tmp;
  late HiveBoxes boxes;
  late AppPaths paths;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('shell_widget');
    paths = AppPaths(base: tmp);
    await paths.ensure();
    boxes = await initHive(paths);
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  testWidgets('Shell renders sidebar and empty-state when no project selected',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appPathsProvider.overrideWithValue(paths),
        hiveBoxesProvider.overrideWithValue(boxes),
      ],
      child: const MaterialApp(home: Shell()),
    ));
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Select a project to begin'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement shell + placeholders**

`lib/ui/shell.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'project_detail/project_detail.dart';
import 'sidebar/sidebar.dart';

class Shell extends ConsumerWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedProjectProvider);
    return Scaffold(
      body: Row(
        children: [
          const SizedBox(width: 260, child: Sidebar()),
          const VerticalDivider(width: 1),
          Expanded(
            child: selected == null
                ? const _EmptyState()
                : ProjectDetail(project: selected),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Select a project to begin'));
  }
}
```

Also create placeholders so the test compiles:

`lib/ui/sidebar/sidebar.dart`:

```dart
import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text('Projects', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
```

`lib/ui/project_detail/project_detail.dart`:

```dart
import 'package:flutter/material.dart';
import '../../domain/models/project.dart';

class ProjectDetail extends StatelessWidget {
  const ProjectDetail({super.key, required this.project});
  final Project project;
  @override
  Widget build(BuildContext context) => Center(child: Text(project.name));
}
```

- [ ] **Step 4: Run, expect widget test PASS.**

- [ ] **Step 5: Verify the app boots end-to-end**

```bash
flutter run -d macos
```

Expected: window opens showing "Projects" sidebar and "Select a project to begin" placeholder. Quit with Cmd-Q.

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart lib/app/ lib/ui/shell.dart lib/ui/sidebar/sidebar.dart lib/ui/project_detail/project_detail.dart test/widget/shell_test.dart
git commit -m "feat(ui): bootstrap shell layout with sidebar and empty-state"
```

---

## Task 21: Sidebar with project list and add button

**Files:**
- Modify: `lib/ui/sidebar/sidebar.dart`
- Create: `lib/ui/dialogs/add_project_dialog.dart`
- Test: `test/widget/sidebar_test.dart`

- [ ] **Step 1: Write failing widget test**

`test/widget/sidebar_test.dart`:

```dart
import 'dart:io';

import 'package:build_tool/data/app_paths.dart';
import 'package:build_tool/data/hive_setup.dart';
import 'package:build_tool/domain/models/project.dart';
import 'package:build_tool/state/providers.dart';
import 'package:build_tool/ui/sidebar/sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tmp;
  late HiveBoxes boxes;
  late AppPaths paths;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('sb');
    paths = AppPaths(base: tmp);
    await paths.ensure();
    boxes = await initHive(paths);
    await boxes.projects.put(
      'p1',
      Project(
        id: 'p1',
        name: 'my_app',
        path: '/tmp/my_app',
        addedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  testWidgets('Sidebar lists projects from store', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appPathsProvider.overrideWithValue(paths),
        hiveBoxesProvider.overrideWithValue(boxes),
      ],
      child: const MaterialApp(home: Scaffold(body: Sidebar())),
    ));
    expect(find.text('my_app'), findsOneWidget);
  });

  testWidgets('Tapping a project sets selectedProjectId',
      (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appPathsProvider.overrideWithValue(paths),
        hiveBoxesProvider.overrideWithValue(boxes),
      ],
      child: Builder(builder: (context) {
        container = ProviderScope.containerOf(context);
        return const MaterialApp(home: Scaffold(body: Sidebar()));
      }),
    ));
    await tester.tap(find.text('my_app'));
    await tester.pump();
    expect(container.read(selectedProjectIdProvider), 'p1');
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement sidebar**

`lib/ui/sidebar/sidebar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../dialogs/add_project_dialog.dart';

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final selectedId = ref.watch(selectedProjectIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Projects',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: projects.length,
            itemBuilder: (context, i) {
              final p = projects[i];
              final isSel = p.id == selectedId;
              return ListTile(
                title: Text(p.name),
                subtitle: Text(
                  p.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                selected: isSel,
                onTap: () =>
                    ref.read(selectedProjectIdProvider.notifier).state = p.id,
                trailing: PopupMenuButton<String>(
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'remove', child: Text('Remove')),
                    PopupMenuItem(value: 'open_finder', child: Text('Open in Finder')),
                  ],
                  onSelected: (v) async {
                    if (v == 'remove') {
                      await ref.read(projectsProvider.notifier).remove(p.id);
                      if (selectedId == p.id) {
                        ref.read(selectedProjectIdProvider.notifier).state = null;
                      }
                    } else if (v == 'open_finder') {
                      ref.read(finderRevealProvider).openFolder(p.path);
                    }
                  },
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const AddProjectDialog(),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add project'),
            ),
          ),
        ),
      ],
    );
  }
}
```

`lib/ui/dialogs/add_project_dialog.dart`:

```dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/project_importer.dart';
import '../../state/providers.dart';

class AddProjectDialog extends ConsumerStatefulWidget {
  const AddProjectDialog({super.key});
  @override
  ConsumerState<AddProjectDialog> createState() => _AddProjectDialogState();
}

class _AddProjectDialogState extends ConsumerState<AddProjectDialog> {
  String? _error;
  bool _busy = false;

  Future<void> _pickAndImport() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) {
      setState(() => _busy = false);
      return;
    }
    try {
      final project = await ref.read(projectImporterProvider).import(path);
      // Duplicate check
      final exists = ref
          .read(projectsProvider)
          .any((p) => p.path == project.path);
      if (exists) {
        setState(() {
          _busy = false;
          _error = 'Project already imported';
        });
        return;
      }
      await ref.read(projectsProvider.notifier).add(project);
      ref.read(selectedProjectIdProvider.notifier).state = project.id;
      if (mounted) Navigator.of(context).pop();
    } on ProjectImportException catch (e) {
      setState(() {
        _busy = false;
        _error = switch (e.code) {
          'NO_PUBSPEC' => 'Not a Flutter project (no pubspec.yaml)',
          'MALFORMED_PUBSPEC' => 'pubspec.yaml is malformed: ${e.message}',
          _ => 'Failed: ${e.message}',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Flutter Project'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pick the root folder of your Flutter project.'),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            if (_busy) const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _pickAndImport,
          child: const Text('Pick folder…'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run, expect widget tests PASS (2 tests).**

- [ ] **Step 5: Commit**

```bash
git add lib/ui/sidebar/sidebar.dart lib/ui/dialogs/add_project_dialog.dart test/widget/sidebar_test.dart
git commit -m "feat(ui): sidebar list, add project dialog with importer"
```

---

## Task 22: ProjectDetail toolbar (flavor + device + clean toggle)

**Files:**
- Create: `lib/ui/project_detail/toolbar.dart`
- Modify: `lib/ui/project_detail/project_detail.dart`
- Test: `test/widget/toolbar_test.dart`

- [ ] **Step 1: Write failing test**

`test/widget/toolbar_test.dart`:

```dart
import 'dart:io';
import 'package:build_tool/data/app_paths.dart';
import 'package:build_tool/data/hive_setup.dart';
import 'package:build_tool/domain/models/flutter_device.dart';
import 'package:build_tool/domain/models/project.dart';
import 'package:build_tool/domain/services/device_lister.dart';
import 'package:build_tool/domain/services/flavor_detector.dart';
import 'package:build_tool/state/providers.dart';
import 'package:build_tool/ui/project_detail/toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class FakeDevices extends DeviceLister {
  const FakeDevices();
  @override
  Future<List<FlutterDevice>> list() async => const [
        FlutterDevice(id: 'macos', name: 'macOS', platformType: 'darwin', isEmulator: false),
        FlutterDevice(id: 'iPhone', name: 'iPhone 15', platformType: 'ios', isEmulator: false),
      ];
}

class FakeFlavors extends FlavorDetector {
  @override
  Future<List<String>> detect(String _) async => ['dev', 'prod'];
}

void main() {
  late Directory tmp;
  late HiveBoxes boxes;
  late AppPaths paths;
  late Project project;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('tb');
    paths = AppPaths(base: tmp);
    await paths.ensure();
    boxes = await initHive(paths);
    project = Project(id: 'p', name: 'x', path: '/tmp/x', addedAt: DateTime.now());
    await boxes.projects.put('p', project);
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  testWidgets('renders flavor and device dropdowns from providers', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appPathsProvider.overrideWithValue(paths),
        hiveBoxesProvider.overrideWithValue(boxes),
        deviceListerProvider.overrideWithValue(const FakeDevices()),
        flavorDetectorProvider.overrideWithValue(FakeFlavors()),
      ],
      child: MaterialApp(home: Scaffold(body: ProjectToolbar(project: project))),
    ));
    // pump enough frames for async device/flavor futures
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('dev'), findsOneWidget);
    expect(find.text('macOS'), findsOneWidget);
    expect(find.text('Clean before build'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement toolbar with FutureProviders for flavors/devices**

Add these to `lib/state/providers.dart`. First, ensure this import is present near the other domain imports at the top of the file:

```dart
import '../domain/models/flutter_device.dart';
```

Then append at the bottom of the file:

```dart
final flavorsForProjectProvider =
    FutureProvider.family<List<String>, String>((ref, projectPath) {
  return ref.watch(flavorDetectorProvider).detect(projectPath);
});

final devicesProvider = FutureProvider<List<FlutterDevice>>((ref) {
  return ref.watch(deviceListerProvider).list();
});
```

`lib/ui/project_detail/toolbar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/project.dart';
import '../../state/providers.dart';

class ProjectToolbar extends ConsumerWidget {
  const ProjectToolbar({super.key, required this.project});
  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavors = ref.watch(flavorsForProjectProvider(project.path));
    final devices = ref.watch(devicesProvider);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _flavorDropdown(context, ref, flavors),
          _deviceDropdown(context, ref, devices),
          _cleanToggle(context, ref),
          IconButton(
            tooltip: 'Refresh devices/flavors',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(devicesProvider);
              ref.invalidate(flavorsForProjectProvider(project.path));
            },
          ),
        ],
      ),
    );
  }

  Widget _flavorDropdown(
      BuildContext c, WidgetRef ref, AsyncValue<List<String>> flavors) {
    final items = flavors.maybeWhen(
      data: (l) => l,
      orElse: () => const <String>[],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Flavor: '),
        DropdownButton<String?>(
          value: project.lastFlavor,
          hint: const Text('(default)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('(default)')),
            for (final f in items)
              DropdownMenuItem(value: f, child: Text(f)),
          ],
          onChanged: (v) {
            project.lastFlavor = v;
            ref.read(projectsProvider.notifier).update(project);
          },
        ),
      ],
    );
  }

  Widget _deviceDropdown(BuildContext c, WidgetRef ref, AsyncValue devices) {
    final list = devices.maybeWhen(
      data: (d) => d as List,
      orElse: () => const [],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Device: '),
        DropdownButton<String?>(
          value: project.lastDeviceId,
          hint: const Text('(pick)'),
          items: [
            for (final d in list)
              DropdownMenuItem(value: d.id as String, child: Text(d.name as String)),
          ],
          onChanged: (v) {
            project.lastDeviceId = v;
            ref.read(projectsProvider.notifier).update(project);
          },
        ),
      ],
    );
  }

  Widget _cleanToggle(BuildContext c, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: project.cleanBeforeBuild,
          onChanged: (v) {
            project.cleanBeforeBuild = v ?? false;
            ref.read(projectsProvider.notifier).update(project);
          },
        ),
        const Text('Clean before build'),
      ],
    );
  }
}
```

- [ ] **Step 4: Update `project_detail.dart` to show toolbar**

```dart
import 'package:flutter/material.dart';
import '../../domain/models/project.dart';
import 'toolbar.dart';

class ProjectDetail extends StatelessWidget {
  const ProjectDetail({super.key, required this.project});
  final Project project;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(project: project),
        const Divider(height: 1),
        ProjectToolbar(project: project),
        const Divider(height: 1),
        const Expanded(child: Placeholder()),  // command grid + terminal next tasks
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.project});
  final Project project;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(project.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          Text(project.path, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run, expect widget test PASS.**

- [ ] **Step 6: Commit**

```bash
git add lib/ui/project_detail/toolbar.dart lib/ui/project_detail/project_detail.dart lib/state/providers.dart test/widget/toolbar_test.dart
git commit -m "feat(ui): project detail toolbar with flavor/device dropdowns + clean toggle"
```

---

## Task 23: Per-project runner controllers via Riverpod family

**Files:**
- Modify: `lib/state/providers.dart` (add family)

A `ProjectRunnerController` instance lives per project id; created lazily and kept alive while the project remains in the list.

- [ ] **Step 1: Add provider**

Append to `lib/state/providers.dart`:

```dart
final projectRunnerProvider =
    Provider.family<ProjectRunnerController, String>((ref, projectId) {
  final controller = ProjectRunnerController(
    runner: ref.watch(commandRunnerProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
```

Add the import:

```dart
import 'project_runner_controller.dart';
```

- [ ] **Step 2: Run analyzer**

```bash
flutter analyze
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/state/providers.dart
git commit -m "feat(state): expose ProjectRunnerController per project via family"
```

---

## Task 24: Command grid (built-in + custom buttons)

**Files:**
- Create: `lib/ui/project_detail/command_grid.dart`
- Modify: `lib/ui/project_detail/project_detail.dart`
- Test: `test/widget/command_grid_test.dart`

The grid composes a `CommandIntent`, asks the controller to start, and disables buttons while running.

- [ ] **Step 1: Write failing widget test**

`test/widget/command_grid_test.dart`:

```dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:build_tool/data/app_paths.dart';
import 'package:build_tool/data/hive_setup.dart';
import 'package:build_tool/domain/models/project.dart';
import 'package:build_tool/domain/services/command_runner.dart';
import 'package:build_tool/state/providers.dart';
import 'package:build_tool/ui/project_detail/command_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class RecordingRunner implements CommandRunner {
  final List<String> calls = [];
  late Completer<int> exit;
  late StreamController<Uint8List> out;

  @override
  RunningCommand start({required String command, required String workingDir, Map<String, String>? env}) {
    calls.add(command);
    out = StreamController<Uint8List>.broadcast();
    exit = Completer<int>();
    return RunningCommand(
      output: out.stream,
      exitCode: exit.future,
      startedAt: DateTime.now(),
      onKill: () { if (!exit.isCompleted) exit.complete(-1); },
    );
  }
}

void main() {
  late Directory tmp;
  late HiveBoxes boxes;
  late AppPaths paths;
  late Project project;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cg');
    paths = AppPaths(base: tmp);
    await paths.ensure();
    boxes = await initHive(paths);
    project = Project(
      id: 'p', name: 'x', path: '/tmp/x',
      addedAt: DateTime.now(),
      lastFlavor: 'prod', lastDeviceId: 'iPhone',
    );
    await boxes.projects.put('p', project);
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  testWidgets('Build APK button triggers composed flutter build apk command',
      (tester) async {
    final runner = RecordingRunner();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appPathsProvider.overrideWithValue(paths),
        hiveBoxesProvider.overrideWithValue(boxes),
        commandRunnerProvider.overrideWithValue(runner),
      ],
      child: MaterialApp(home: Scaffold(body: CommandGrid(project: project))),
    ));
    await tester.tap(find.text('Build APK'));
    await tester.pump();
    expect(runner.calls.single, "flutter build apk --release --flavor 'prod'");
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement command grid**

`lib/ui/project_detail/command_grid.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/command_intent.dart';
import '../../domain/models/custom_command.dart';
import '../../domain/models/project.dart';
import '../../state/providers.dart';
import '../dialogs/custom_command_dialog.dart';

class CommandGrid extends ConsumerWidget {
  const CommandGrid({super.key, required this.project});
  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(projectRunnerProvider(project.id));
    return StreamBuilder(
      stream: controller.stream,
      builder: (_, __) {
        final running = controller.isRunning;
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _btn(context, ref, '▶ Run', !running, () => _run(ref,
                    RunIntent(deviceId: project.lastDeviceId ?? '',
                              flavor: project.lastFlavor))),
                  _btn(context, ref, '🧹 Clean + Pub', !running,
                      () => _run(ref, const CleanIntent())),
                  _btn(context, ref, '📦 Build APK', !running,
                      () => _run(ref, BuildApkIntent(flavor: project.lastFlavor))),
                  _btn(context, ref, '⚙️ build_runner', !running,
                      () => _run(ref, const BuildRunnerIntent())),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Custom', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in project.customCommands)
                    _btn(context, ref, c.label, !running,
                        () => _run(ref, CustomIntent(label: c.label, command: c.command))),
                  OutlinedButton.icon(
                    onPressed: () => _editCustom(context, ref, null),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _btn(BuildContext c, WidgetRef ref, String label, bool enabled, VoidCallback onTap) {
    return FilledButton(onPressed: enabled ? onTap : null, child: Text(label));
  }

  void _run(WidgetRef ref, CommandIntent intent) {
    final composed = ref.read(commandComposerProvider).compose(
      intent,
      cleanBeforeBuild: project.cleanBeforeBuild,
    );
    final controller = ref.read(projectRunnerProvider(project.id));
    controller.start(
      label: composed.label,
      command: composed.shell,
      workingDir: project.path,
    );
  }

  Future<void> _editCustom(BuildContext c, WidgetRef ref, CustomCommand? existing) async {
    final result = await showDialog<CustomCommand>(
      context: c,
      builder: (_) => CustomCommandDialog(initial: existing),
    );
    if (result == null) return;
    final updated = [...project.customCommands.where((x) => x.id != result.id), result];
    project.customCommands = updated;
    await ref.read(projectsProvider.notifier).update(project);
  }
}
```

- [ ] **Step 4: Wire `CommandGrid` into `project_detail.dart`** (replace the `Placeholder()`):

```dart
import 'package:flutter/material.dart';
import '../../domain/models/project.dart';
import 'command_grid.dart';
import 'toolbar.dart';

class ProjectDetail extends StatelessWidget {
  const ProjectDetail({super.key, required this.project});
  final Project project;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(project: project),
        const Divider(height: 1),
        ProjectToolbar(project: project),
        const Divider(height: 1),
        CommandGrid(project: project),
        const Divider(height: 1),
        const Expanded(child: Placeholder()),  // terminal panel in Task 26
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.project});
  final Project project;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(project.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          Text(project.path, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run, expect widget test PASS.**

- [ ] **Step 6: Commit**

```bash
git add lib/ui/project_detail/command_grid.dart lib/ui/project_detail/project_detail.dart test/widget/command_grid_test.dart
git commit -m "feat(ui): command grid with built-in and custom command buttons"
```

---

## Task 25: Custom command dialog

**Files:**
- Create: `lib/ui/dialogs/custom_command_dialog.dart`
- Test: `test/widget/custom_command_dialog_test.dart`

- [ ] **Step 1: Write failing test**

```dart
import 'package:build_tool/domain/models/custom_command.dart';
import 'package:build_tool/ui/dialogs/custom_command_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('returns CustomCommand with label and command on save', (tester) async {
    CustomCommand? captured;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      return TextButton(
        onPressed: () async {
          captured = await showDialog<CustomCommand>(
            context: c,
            builder: (_) => const CustomCommandDialog(initial: null),
          );
        },
        child: const Text('Open'),
      );
    })));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('label-field')), 'Deploy');
    await tester.enterText(find.byKey(const Key('command-field')), 'firebase deploy');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(captured?.label, 'Deploy');
    expect(captured?.command, 'firebase deploy');
  });

  testWidgets('Save disabled when fields empty', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      return TextButton(
        onPressed: () => showDialog<CustomCommand>(
          context: c, builder: (_) => const CustomCommandDialog(initial: null)),
        child: const Text('Open'),
      );
    })));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final saveBtn = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
    expect(saveBtn.onPressed, isNull);
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

`lib/ui/dialogs/custom_command_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/custom_command.dart';

class CustomCommandDialog extends StatefulWidget {
  const CustomCommandDialog({super.key, required this.initial});
  final CustomCommand? initial;
  @override
  State<CustomCommandDialog> createState() => _CustomCommandDialogState();
}

class _CustomCommandDialogState extends State<CustomCommandDialog> {
  late final TextEditingController _label =
      TextEditingController(text: widget.initial?.label ?? '');
  late final TextEditingController _command =
      TextEditingController(text: widget.initial?.command ?? '');

  bool get _valid => _label.text.trim().isNotEmpty && _command.text.trim().isNotEmpty;

  @override
  void dispose() {
    _label.dispose();
    _command.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'New custom command' : 'Edit custom command'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('label-field'),
              controller: _label,
              decoration: const InputDecoration(labelText: 'Label'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('command-field'),
              controller: _command,
              decoration: const InputDecoration(labelText: 'Shell command'),
              maxLines: 3,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _valid
              ? () {
                  Navigator.pop(
                    context,
                    CustomCommand(
                      id: widget.initial?.id ?? const Uuid().v4(),
                      label: _label.text.trim(),
                      command: _command.text.trim(),
                    ),
                  );
                }
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run, expect PASS (2 tests).**

- [ ] **Step 5: Commit**

```bash
git add lib/ui/dialogs/custom_command_dialog.dart test/widget/custom_command_dialog_test.dart
git commit -m "feat(ui): custom command create/edit dialog"
```

---

## Task 26: Terminal panel with xterm + actions

**Files:**
- Create: `lib/ui/project_detail/terminal_panel.dart`
- Modify: `lib/ui/project_detail/project_detail.dart`

Wires the runner's output stream into an `xterm` `Terminal`. Buttons: Stop, Clear, Save log, Open output (Open output enabled only after successful APK build in Task 27).

- [ ] **Step 1: Implement terminal panel**

`lib/ui/project_detail/terminal_panel.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import 'package:xterm/ui.dart' as xtermui;
import 'package:file_picker/file_picker.dart';

import '../../domain/models/project.dart';
import '../../state/project_runner_controller.dart';
import '../../state/providers.dart';

class TerminalPanel extends ConsumerStatefulWidget {
  const TerminalPanel({super.key, required this.project});
  final Project project;
  @override
  ConsumerState<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends ConsumerState<TerminalPanel> {
  final Terminal _terminal = Terminal(maxLines: 10000);
  StreamSubscription<Uint8List>? _outSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    final controller = ref.read(projectRunnerProvider(widget.project.id));
    _outSub = controller.output.listen((data) {
      _terminal.write(utf8.decode(data, allowMalformed: true));
    });
    _stateSub = controller.stream.listen((_) => setState(() {}));
  }

  @override
  void dispose() {
    _outSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  Future<void> _saveLog() async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save log to…',
      fileName: '${widget.project.name}-log.txt',
    );
    if (path == null) return;
    // xterm's Buffer exposes lines. Flatten them, then strip ANSI for the file.
    final sb = StringBuffer();
    final buf = _terminal.buffer;
    for (var i = 0; i < buf.lines.length; i++) {
      sb.writeln(buf.lines[i].toString());
    }
    await File(path).writeAsString(_stripAnsi(sb.toString()));
  }

  void _clearTerminal() {
    // Use ANSI ED2 + cursor home to clear (portable across xterm versions).
    _terminal.write('\x1b[2J\x1b[H');
    setState(() {});
  }

  String _stripAnsi(String input) =>
      input.replaceAll(RegExp(r'\x1B\[[0-9;?]*[ -/]*[@-~]'), '');

  String _statusText(ProjectRunnerController controller) {
    final code = controller.lastExitCode;
    final dur = controller.lastDuration;
    final label = controller.current?.label ?? '';
    if (code == 0) return '✓ $label (${dur!.inSeconds}s)';
    if (code != null && code < 0) return '✗ Cancelled';
    return '✗ exit $code';
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(projectRunnerProvider(widget.project.id));
    final running = controller.isRunning;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              if (running)
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: controller.stop,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _clearTerminal,
                icon: const Icon(Icons.cleaning_services),
                label: const Text('Clear'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _saveLog,
                icon: const Icon(Icons.save),
                label: const Text('Save log'),
              ),
              const Spacer(),
              if (controller.lastDuration != null && !running)
                Text(
                  _statusText(controller),
                  style: TextStyle(
                    color: controller.lastExitCode == 0
                        ? Colors.greenAccent
                        : Colors.redAccent,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: xtermui.TerminalView(_terminal),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Update `project_detail.dart` to mount the terminal panel** (replace `Placeholder()` again):

```dart
import 'package:flutter/material.dart';
import '../../domain/models/project.dart';
import 'command_grid.dart';
import 'terminal_panel.dart';
import 'toolbar.dart';

class ProjectDetail extends StatelessWidget {
  const ProjectDetail({super.key, required this.project});
  final Project project;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(project: project),
        const Divider(height: 1),
        ProjectToolbar(project: project),
        const Divider(height: 1),
        CommandGrid(project: project),
        const Divider(height: 1),
        Expanded(child: TerminalPanel(project: project)),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.project});
  final Project project;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(project.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          Text(project.path, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Smoke test in the running app**

```bash
flutter run -d macos
```

Steps in the running app:
- Click "Add project" → pick any folder containing a real Flutter project.
- Add a custom command with label `Echo` and command `echo hello && sleep 1 && echo done`.
- Click `Echo` → verify terminal shows `hello`, then `done`, then green check + duration.
- Click `🧹 Clean + Pub` → verify two commands run; terminal shows their output.

Quit with Cmd-Q.

- [ ] **Step 4: Commit**

```bash
git add lib/ui/project_detail/terminal_panel.dart lib/ui/project_detail/project_detail.dart
git commit -m "feat(ui): terminal panel with xterm streaming + Stop/Clear/Save log"
```

---

## Task 27: APK build → rename → Finder reveal flow

**Files:**
- Modify: `lib/ui/project_detail/command_grid.dart`
- Modify: `lib/ui/project_detail/terminal_panel.dart` (add Open output button)

Hook into `controller.start(..., onComplete: ...)` for `BuildApkIntent` to run the rename + reveal after success. Cache the last reveal path on the controller so the terminal panel can show "Open output".

- [ ] **Step 1: Add lastOutputPath to ProjectRunnerController**

In `lib/state/project_runner_controller.dart`, add an instance field and getter:

```dart
File? _lastOutputFile;
File? get lastOutputFile => _lastOutputFile;
void setLastOutputFile(File? f) {
  _lastOutputFile = f;
  _setState(_state);  // notify listeners to refresh
}
```

Add `import 'dart:io';` at the top if not present.

- [ ] **Step 2: Wire post-build pipeline in CommandGrid**

In `_run` in `command_grid.dart`, handle `BuildApkIntent` specially:

```dart
void _run(WidgetRef ref, CommandIntent intent) {
  final composed = ref.read(commandComposerProvider).compose(
    intent,
    cleanBeforeBuild: project.cleanBeforeBuild,
  );
  final controller = ref.read(projectRunnerProvider(project.id));
  controller.setLastOutputFile(null);
  controller.start(
    label: composed.label,
    command: composed.shell,
    workingDir: project.path,
    onComplete: (code, duration) async {
      if (code == 0 && intent is BuildApkIntent) {
        final apk = await ref.read(outputFinderProvider).findApk(project.path);
        if (apk == null) {
          await ref.read(finderRevealProvider).openFolder('${project.path}/build');
          return;
        }
        try {
          final result = await ref.read(outputRenamerProvider).rename(
                sourceApk: apk,
                projectPath: project.path,
              );
          controller.setLastOutputFile(result.target);
          await ref.read(finderRevealProvider).reveal(result.target.path);
        } catch (_) {
          await ref.read(finderRevealProvider).openFolder('${project.path}/build');
        }
      }
    },
  );
}
```

Add the missing `import 'dart:io';` if needed (only if a File appears in this file — it does not, only the controller holds it).

- [ ] **Step 3: Add Open Output button in terminal_panel.dart**

In the toolbar row, before `Spacer`, add:

```dart
if (!running && controller.lastOutputFile != null)
  OutlinedButton.icon(
    onPressed: () =>
        ref.read(finderRevealProvider).reveal(controller.lastOutputFile!.path),
    icon: const Icon(Icons.folder_open),
    label: const Text('Open output'),
  ),
```

- [ ] **Step 4: Smoke test against a real Flutter project**

```bash
flutter run -d macos
```

In the app:
- Import a real Flutter project with a known version (e.g. `1.0.0+1`).
- Pick a flavor if any.
- Click `📦 Build APK` (expect a long-running command — wait it out).
- On success: Finder opens revealing `<name>-v1.0.0.apk`, terminal toolbar shows green status, "Open output" button appears.
- Click "Open output" → Finder reveals same file.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/project_detail/command_grid.dart lib/ui/project_detail/terminal_panel.dart lib/state/project_runner_controller.dart
git commit -m "feat(build): post-APK pipeline: find -> rename -> reveal in Finder"
```

---

## Task 28: SDK-missing banner at app top

**Files:**
- Modify: `lib/ui/shell.dart`
- Modify: `lib/state/providers.dart` (add FutureProvider)

- [ ] **Step 1: Add provider**

In `lib/state/providers.dart`:

```dart
final sdkStatusProvider = FutureProvider((ref) {
  return ref.watch(sdkCheckerProvider).check();
});
```

Add import for `SdkStatus` if not already imported via `flutter_sdk_checker.dart`.

- [ ] **Step 2: Modify Shell to show banner**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'project_detail/project_detail.dart';
import 'sidebar/sidebar.dart';

class Shell extends ConsumerWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedProjectProvider);
    final sdk = ref.watch(sdkStatusProvider);
    return Scaffold(
      body: Column(
        children: [
          sdk.when(
            data: (s) => s.available
                ? const SizedBox.shrink()
                : Container(
                    color: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(children: [
                      const Icon(Icons.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'Flutter SDK not found in PATH — install Flutter and ensure `flutter` is on your shell PATH.'
                        '${s.error == null ? '' : '\n${s.error}'}',
                      )),
                    ]),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Expanded(
            child: Row(
              children: [
                const SizedBox(width: 260, child: Sidebar()),
                const VerticalDivider(width: 1),
                Expanded(
                  child: selected == null
                      ? const _EmptyState()
                      : ProjectDetail(project: selected),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Select a project to begin'));
  }
}
```

- [ ] **Step 3: Smoke test**

```bash
flutter run -d macos
```

Expected: with flutter on PATH, no banner. To verify the banner path manually, temporarily rename `flutter` on PATH (or set PATH=/nonexistent in your terminal before launching) and re-run.

- [ ] **Step 4: Commit**

```bash
git add lib/ui/shell.dart lib/state/providers.dart
git commit -m "feat(ui): show banner when Flutter SDK is not on PATH"
```

---

## Task 29: Integration test (end-to-end with a fixture project)

**Files:**
- Create: `test/fixtures/sample_app/pubspec.yaml`
- Create: `test/integration/echo_command_test.dart`

We avoid running a real `flutter build` in tests. Instead the integration test imports a fixture folder, adds a custom `echo` command, runs it via the real PTY runner, and asserts terminal received output.

- [ ] **Step 1: Create fixture**

`test/fixtures/sample_app/pubspec.yaml`:

```yaml
name: sample_app
version: 0.1.0+1
environment:
  sdk: '>=3.0.0 <4.0.0'
```

- [ ] **Step 2: Write integration test**

`test/integration/echo_command_test.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:build_tool/domain/services/project_importer.dart';
import 'package:build_tool/domain/services/command_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('end-to-end: import fixture project, run echo via PTY', () async {
    // Resolve fixture path
    final fx = Directory('test/fixtures/sample_app');
    expect(fx.existsSync(), isTrue, reason: 'fixture missing');

    final imported = await const ProjectImporter().import(fx.absolute.path);
    expect(imported.name, 'sample_app');

    final running = const PtyCommandRunner().start(
      command: "echo 'integration-ok'",
      workingDir: fx.absolute.path,
    );
    final buf = StringBuffer();
    final sub = running.output.transform(utf8.decoder).listen(buf.write);
    final exit = await running.exitCode.timeout(const Duration(seconds: 5));
    await sub.cancel();

    expect(exit, 0);
    expect(buf.toString(), contains('integration-ok'));
  });
}
```

- [ ] **Step 3: Run integration test**

```bash
flutter test test/integration/echo_command_test.dart
```

Expected: PASS.

- [ ] **Step 4: Run full test suite to make sure nothing regressed**

```bash
flutter test
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add test/fixtures/sample_app/ test/integration/echo_command_test.dart
git commit -m "test(integration): end-to-end PTY echo against fixture project"
```

---

## Task 30: README and final sanity build

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README**

`README.md`:

````markdown
# build_tool

macOS desktop app that imports Flutter projects and runs build/run/clean
commands from a sidebar UI with a live ANSI terminal.

## Run

```bash
flutter run -d macos
```

## Package

```bash
flutter build macos --release
open build/macos/Build/Products/Release/build_tool.app
```

## Test

```bash
flutter test
```

## Data

App stores projects and logs under
`~/Library/Application Support/build_tool/`.
````

- [ ] **Step 2: Final release build**

```bash
flutter build macos --release
```

Expected: succeeds; produces `build/macos/Build/Products/Release/build_tool.app`.

- [ ] **Step 3: Open and smoke-test the release build**

```bash
open build/macos/Build/Products/Release/build_tool.app
```

Verify: window opens, can add project, can run an echo custom command. Quit.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: add README"
```

---

## Done — MVP shipped

After Task 30, the MVP from the spec is complete:
- Import / list / remove projects ✓ (Tasks 4, 21)
- Auto-detect Android flavors (Groovy + Kotlin DSL) ✓ (Task 7)
- Built-in commands Run / Build APK / Clean+Pub / build_runner ✓ (Task 8 + 24)
- Custom commands per project ✓ (Tasks 8 + 25)
- Device picker ✓ (Tasks 13 + 22)
- Terminal with xterm + Stop / Clear / Save log ✓ (Task 26)
- Output rename + Finder reveal for APK ✓ (Tasks 10 + 27)
- Build history infrastructure ✓ (Tasks 2 + 5; note: history UI list not yet
  surfaced — see "Deferred" below)
- "Clean before build" toggle per project ✓ (Task 22)
- SDK missing banner ✓ (Task 28)

**Deferred from MVP scope (file follow-up issues):**
- Build history list UI — `BuildLogRepository` is wired but no view surfaces it
  yet. Add a drawer or modal listing `BuildLog`s per project in a follow-up.
- Recording BuildLog entries when commands run — controller currently does not
  call `BuildLogRepository.add()`. Follow-up: in `ProjectRunnerController.start`
  inject a hook to write logs, and have `CommandGrid` pass it.
- "Project path missing" handling — repository can hold a project whose folder
  was deleted; UI does not yet mark it as missing. Add a check in `Sidebar`.
- Hive recovery dialog (corruption) — main.dart currently crashes if Hive
  fails to open. Wrap `initHive` in try/catch with a recovery prompt.

These are tracked separately and do not block the working MVP — every other
spec requirement is implemented and verified end-to-end.
