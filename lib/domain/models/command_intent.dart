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
