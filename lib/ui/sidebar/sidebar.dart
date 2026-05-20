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
