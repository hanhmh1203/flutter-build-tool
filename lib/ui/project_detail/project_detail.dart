import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/colors.dart';
import '../../domain/models/project.dart';
import '../../state/providers.dart';
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
        _ProjectHeader(project: project),
        const Divider(height: 1, color: AppColors.hairline),
        ProjectToolbar(project: project),
        const Divider(height: 1, color: AppColors.hairline),
        CommandGrid(project: project),
        const Divider(height: 1, color: AppColors.hairline),
        Expanded(child: TerminalPanel(project: project)),
      ],
    );
  }
}

// ─── Project Header ──────────────────────────────────────────────────────────

class _ProjectHeader extends ConsumerWidget {
  const _ProjectHeader({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(projectRunnerProvider(project.id));
    final sdk = ref.watch(sdkStatusProvider);
    final sdkVersion = sdk.maybeWhen(
      data: (s) => s.version ?? '—',
      orElse: () => '—',
    );

    final lastBuild = controller.lastDuration != null
        ? '${controller.lastDuration!.inSeconds}s ago'
        : '—';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(
          bottom: BorderSide(color: AppColors.hairline, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Left title block
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Eyebrow
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ACTIVE PROJECT',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        color: AppColors.muted,
                        letterSpacing: 0.14 * 10.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // H1 with last char italic accent
                _StyledProjectName(name: project.name),
                // Path
                const SizedBox(height: 8),
                _StyledPath(path: project.path),
              ],
            ),
          ),
          const SizedBox(width: 18),
          // Right stats block
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StatCell(label: 'LAST BUILD', value: lastBuild),
              const SizedBox(width: 18),
              _StatCell(label: 'SIZE', value: '—'),
              const SizedBox(width: 18),
              _StatCell(label: 'FLUTTER', value: sdkVersion),
            ],
          ),
        ],
      ),
    );
  }
}

class _StyledProjectName extends StatelessWidget {
  const _StyledProjectName({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    if (name.isEmpty) {
      return Text(
        name,
        style: GoogleFonts.sourceSerif4(
          fontSize: 34,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
          letterSpacing: -0.025 * 34,
        ),
      );
    }
    final mainPart = name.substring(0, name.length - 1);
    final lastChar = name[name.length - 1];

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: mainPart,
            style: GoogleFonts.sourceSerif4(
              fontSize: 34,
              fontWeight: FontWeight.w500,
              color: AppColors.text,
              letterSpacing: -0.025 * 34,
            ),
          ),
          TextSpan(
            text: lastChar,
            style: GoogleFonts.sourceSerif4(
              fontSize: 34,
              fontWeight: FontWeight.w500,
              color: AppColors.accent,
              fontStyle: FontStyle.italic,
              letterSpacing: -0.025 * 34,
            ),
          ),
        ],
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _StyledPath extends StatelessWidget {
  const _StyledPath({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final segments = path.split('/');
    final spans = <TextSpan>[];
    for (var i = 0; i < segments.length; i++) {
      if (segments[i].isEmpty) continue;
      if (i > 0) {
        spans.add(TextSpan(
          text: '/',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11.5,
            color: AppColors.dim,
          ),
        ));
      }
      spans.add(TextSpan(
        text: segments[i],
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11.5,
          color: AppColors.muted,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9.5,
            color: AppColors.dim,
            letterSpacing: 0.12 * 9.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            color: AppColors.text,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
