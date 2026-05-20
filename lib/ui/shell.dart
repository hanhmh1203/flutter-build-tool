import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/colors.dart';
import '../state/providers.dart';
import 'project_detail/project_detail.dart';
import 'sidebar/sidebar.dart';

class Shell extends ConsumerWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedProjectProvider);
    final sdk = ref.watch(sdkStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _Titlebar(sdkStatus: sdk),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(width: 260, child: Sidebar()),
                Expanded(
                  child: selected == null
                      ? const _EmptyState()
                      : ProjectDetail(project: selected),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Titlebar extends ConsumerWidget {
  const _Titlebar({required this.sdkStatus});

  final AsyncValue sdkStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sdkAvailable = sdkStatus.maybeWhen(
      data: (s) => s.available,
      orElse: () => true,
    );

    return Container(
      height: 42,
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(
          bottom: BorderSide(color: AppColors.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Traffic light dots
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                _TrafficDot(color: const Color(0xFFEC6A5E)),
                const SizedBox(width: 6),
                _TrafficDot(color: const Color(0xFFF4BE4F)),
                const SizedBox(width: 6),
                _TrafficDot(color: const Color(0xFF61C454)),
              ],
            ),
          ),
          // Center title + optional SDK warning
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'build_tool',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (!sdkAvailable) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: AppColors.danger.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Flutter SDK not found',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Right: branch pill + Flutter version
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BranchPill(),
                const SizedBox(width: 8),
                _FlutterVersionLabel(sdkStatus: sdkStatus),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrafficDot extends StatelessWidget {
  const _TrafficDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.black.withOpacity(0.1),
          width: 0.5,
        ),
      ),
    );
  }
}

class _BranchPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.ok,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'main',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10.5,
              color: AppColors.text2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlutterVersionLabel extends StatelessWidget {
  const _FlutterVersionLabel({required this.sdkStatus});
  final AsyncValue sdkStatus;

  @override
  Widget build(BuildContext context) {
    final version = sdkStatus.maybeWhen(
      data: (s) {
        final v = s.version;
        return v != null ? 'Flutter $v' : 'Flutter —';
      },
      orElse: () => 'Flutter —',
    );
    return Text(
      version,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 10,
        color: AppColors.dim,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No project selected',
            style: GoogleFonts.sourceSerif4(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select a project from the sidebar to begin.',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.dim,
            ),
          ),
        ],
      ),
    );
  }
}
