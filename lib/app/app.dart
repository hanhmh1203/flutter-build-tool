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
