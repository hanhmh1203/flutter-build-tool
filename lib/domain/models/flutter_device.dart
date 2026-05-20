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
