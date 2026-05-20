sealed class CommandIntent {
  const CommandIntent();
}

class RunIntent extends CommandIntent {
  const RunIntent({required this.deviceId, this.flavor, this.entryPoint});
  final String deviceId;
  final String? flavor;
  /// Relative entry-point path, e.g. "lib/main_nightly.dart".
  /// null means use Flutter default (lib/main.dart).
  final String? entryPoint;
}

class BuildApkIntent extends CommandIntent {
  const BuildApkIntent({this.flavor, this.entryPoint});
  final String? flavor;
  final String? entryPoint;
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
