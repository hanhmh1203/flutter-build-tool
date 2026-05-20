import 'package:flutter/material.dart';
import '../../domain/models/project.dart';

class ProjectDetail extends StatelessWidget {
  const ProjectDetail({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) => Center(child: Text(project.name));
}
