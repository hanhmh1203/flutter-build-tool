import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_paths.dart';
import '../data/hive_setup.dart';
import '../data/repositories/build_log_repository.dart';
import '../data/repositories/project_repository.dart';
import '../domain/models/flutter_device.dart';
import '../domain/models/project.dart';
import '../domain/services/command_composer.dart';
import '../domain/services/command_runner.dart';
import '../domain/services/device_lister.dart';
import '../domain/services/finder_reveal.dart';
import '../domain/services/flavor_detector.dart';
import '../domain/services/flutter_sdk_checker.dart';
import '../domain/services/output_finder.dart';
import '../domain/services/output_renamer.dart';
import 'project_runner_controller.dart';
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

final flavorsForProjectProvider =
    FutureProvider.family<List<String>, String>((ref, projectPath) {
  return ref.watch(flavorDetectorProvider).detect(projectPath);
});

final devicesProvider = FutureProvider<List<FlutterDevice>>((ref) {
  return ref.watch(deviceListerProvider).list();
});

final projectRunnerProvider =
    Provider.family<ProjectRunnerController, String>((ref, projectId) {
  final controller = ProjectRunnerController(
    runner: ref.watch(commandRunnerProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

final sdkStatusProvider = FutureProvider((ref) {
  return ref.watch(sdkCheckerProvider).check();
});
