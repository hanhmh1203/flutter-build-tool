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
          Text(project.name,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w600)),
          Text(project.path,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
