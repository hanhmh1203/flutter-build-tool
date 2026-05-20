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
