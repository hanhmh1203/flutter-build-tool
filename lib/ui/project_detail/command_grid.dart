import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/colors.dart';
import '../../domain/models/command_intent.dart';
import '../../domain/models/custom_command.dart';
import '../../domain/models/project.dart';
import '../../domain/services/script_detector.dart';
import '../../state/providers.dart';
import '../dialogs/custom_command_dialog.dart';

class CommandGrid extends ConsumerWidget {
  const CommandGrid({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(projectRunnerProvider(project.id));
    final selectedDevice = ref.watch(selectedDeviceIdProvider(project.id));
    final selectedFlavor = ref.watch(selectedFlavorProvider(project.id));
    final selectedEntry = ref.watch(selectedEntryPointProvider(project.id));
    final cleanBefore = ref.watch(selectedCleanProvider(project.id));
    final scripts = ref.watch(scriptsForProjectProvider(project.path));

    return StreamBuilder(
      stream: controller.stream,
      builder: (_, __) {
        final running = controller.isRunning;

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
          decoration: const BoxDecoration(color: AppColors.bg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Primary and secondary action buttons
              Row(
                children: [
                  // Primary Run button
                  _RunButton(
                    running: running,
                    onTap: () => _run(
                      ref,
                      RunIntent(
                        deviceId: selectedDevice ?? '',
                        flavor: selectedFlavor,
                        entryPoint: selectedEntry,
                      ),
                      cleanBefore: false,
                    ),
                    onStop: controller.stop,
                  ),
                  const SizedBox(width: 8),
                  // Secondary buttons
                  _SecondaryButton(
                    icon: Icons.auto_fix_high,
                    label: 'Clean + Pub',
                    enabled: !running,
                    onTap: () => _run(ref, const CleanIntent(),
                        cleanBefore: false),
                  ),
                  const SizedBox(width: 6),
                  _SecondaryButton(
                    icon: Icons.settings_outlined,
                    label: 'build_runner',
                    enabled: !running,
                    onTap: () => _run(ref, const BuildRunnerIntent(),
                        cleanBefore: false),
                  ),
                  // Vertical separator
                  Container(
                    height: 24,
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: AppColors.border,
                  ),
                  _SecondaryButton(
                    icon: Icons.android,
                    label: 'APK',
                    enabled: !running,
                    onTap: () => _run(
                      ref,
                      BuildApkIntent(
                          flavor: selectedFlavor, entryPoint: selectedEntry),
                      cleanBefore: cleanBefore,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _SecondaryButton(
                    icon: Icons.inventory_2_outlined,
                    label: 'AAB',
                    enabled: !running,
                    onTap: () => _run(
                      ref,
                      BuildAabIntent(
                          flavor: selectedFlavor, entryPoint: selectedEntry),
                      cleanBefore: cleanBefore,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _SecondaryButton(
                    icon: Icons.apple,
                    label: 'IPA',
                    enabled: !running,
                    onTap: () => _run(
                      ref,
                      BuildIpaIntent(
                          flavor: selectedFlavor, entryPoint: selectedEntry),
                      cleanBefore: cleanBefore,
                    ),
                  ),
                ],
              ),

              // Release scripts
              const SizedBox(height: 16),
              scripts.when(
                data: (list) => _ScriptsSection(
                  scripts: list,
                  running: running,
                  project: project,
                  onRunScript: (script) => _runScript(ref, script),
                  onAddScript: () => _addScript(context, ref),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // Custom commands
              const SizedBox(height: 12),
              _CustomCommandsSection(
                project: project,
                running: running,
                onRun: (c) => _run(
                  ref,
                  CustomIntent(label: c.label, command: c.command),
                  cleanBefore: false,
                ),
                onEdit: (c) => _editCustom(context, ref, c),
                onAdd: () => _editCustom(context, ref, null),
              ),
            ],
          ),
        );
      },
    );
  }

  void _run(WidgetRef ref, CommandIntent intent, {required bool cleanBefore}) {
    final composed = ref.read(commandComposerProvider).compose(
          intent,
          cleanBeforeBuild: cleanBefore,
        );
    final controller = ref.read(projectRunnerProvider(project.id));
    controller.setLastOutputFile(null);
    controller.start(
      label: composed.label,
      command: composed.shell,
      workingDir: project.path,
      onComplete: (code, duration) async {
        if (code == 0 && intent is BuildApkIntent) {
          final apk =
              await ref.read(outputFinderProvider).findApk(project.path);
          if (apk == null) {
            await ref
                .read(finderRevealProvider)
                .openFolder('${project.path}/build');
            return;
          }
          try {
            final result = await ref.read(outputRenamerProvider).rename(
                  sourceApk: apk,
                  projectPath: project.path,
                );
            controller.setLastOutputFile(result.target);
            await ref.read(finderRevealProvider).reveal(result.target.path);
          } catch (_) {
            await ref
                .read(finderRevealProvider)
                .openFolder('${project.path}/build');
          }
        }
      },
    );
  }

  void _runScript(WidgetRef ref, ShScript script) {
    final controller = ref.read(projectRunnerProvider(project.id));
    controller.setLastOutputFile(null);
    controller.start(
      label: script.name,
      command: 'bash ${_q(script.path)}',
      workingDir: project.path,
      onComplete: (_, __) {},
    );
  }

  String _q(String input) {
    final escaped = input.replaceAll("'", r"'\''");
    return "'$escaped'";
  }

  Future<void> _addScript(BuildContext context, WidgetRef ref) async {
    // File picker opens for .sh files
    await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['sh'],
    );
    // Refresh script list
    ref.invalidate(scriptsForProjectProvider(project.path));
  }

  Future<void> _editCustom(
      BuildContext context, WidgetRef ref, CustomCommand? existing) async {
    final result = await showDialog<CustomCommand>(
      context: context,
      builder: (_) => CustomCommandDialog(initial: existing),
    );
    if (result == null) return;
    final updated = [
      ...project.customCommands.where((x) => x.id != result.id),
      result,
    ];
    project.customCommands = updated;
    await ref.read(projectsProvider.notifier).update(project);
  }
}

// ─── Run button ───────────────────────────────────────────────────────────

class _RunButton extends StatefulWidget {
  const _RunButton({
    required this.running,
    required this.onTap,
    required this.onStop,
  });
  final bool running;
  final VoidCallback onTap;
  final VoidCallback onStop;

  @override
  State<_RunButton> createState() => _RunButtonState();
}

class _RunButtonState extends State<_RunButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.running ? widget.onStop : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          decoration: BoxDecoration(
            color: widget.running
                ? AppColors.danger
                : (_hovered ? AppColors.accent : AppColors.text),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: 14,
                color: AppColors.bg,
              ),
              const SizedBox(width: 6),
              Text(
                widget.running ? 'Stop' : 'Run',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.bg,
                  letterSpacing: -0.005 * 13,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '⌘R',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: AppColors.bg.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Secondary button ─────────────────────────────────────────────────────

class _SecondaryButton extends StatefulWidget {
  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<_SecondaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          transform: _hovered && widget.enabled
              ? (Matrix4.identity()..translate(0.0, -0.5))
              : Matrix4.identity(),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: _hovered && widget.enabled
                ? AppColors.surface2
                : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _hovered && widget.enabled
                  ? AppColors.border2
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: widget.enabled ? AppColors.text : AppColors.dim,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.enabled ? AppColors.text : AppColors.dim,
                  letterSpacing: -0.005 * 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Scripts section ─────────────────────────────────────────────────────

class _ScriptsSection extends StatelessWidget {
  const _ScriptsSection({
    required this.scripts,
    required this.running,
    required this.project,
    required this.onRunScript,
    required this.onAddScript,
  });

  final List<ShScript> scripts;
  final bool running;
  final Project project;
  final ValueChanged<ShScript> onRunScript;
  final VoidCallback onAddScript;

  @override
  Widget build(BuildContext context) {
    if (scripts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'release scripts',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: AppColors.muted,
                letterSpacing: 0.12 * 10,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '${scripts.length}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.5,
                  color: AppColors.muted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in scripts)
              _ScriptCard(
                script: s,
                enabled: !running,
                onTap: () => onRunScript(s),
              ),
            _AddScriptCard(onTap: onAddScript),
          ],
        ),
      ],
    );
  }
}

class _ScriptCard extends StatefulWidget {
  const _ScriptCard({
    required this.script,
    required this.enabled,
    required this.onTap,
  });

  final ShScript script;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_ScriptCard> createState() => _ScriptCardState();
}

class _ScriptCardState extends State<_ScriptCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.accentTint : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon box
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _hovered ? AppColors.surface : AppColors.surface2,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Icon(
                  Icons.terminal,
                  size: 14,
                  color: _hovered ? AppColors.accent : AppColors.text2,
                ),
              ),
              const SizedBox(width: 10),
              // Meta
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.script.name,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.script.desc.isNotEmpty)
                      Text(
                        widget.script.desc,
                        style: GoogleFonts.dmSans(
                          fontSize: 10.5,
                          color: AppColors.muted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.play_arrow_rounded,
                size: 14,
                color: AppColors.dim,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddScriptCard extends StatefulWidget {
  const _AddScriptCard({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_AddScriptCard> createState() => _AddScriptCardState();
}

class _AddScriptCardState extends State<_AddScriptCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.accentTint : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered ? AppColors.accent : AppColors.border2,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 14,
                  color: _hovered ? AppColors.accent : AppColors.muted),
              const SizedBox(width: 6),
              Text(
                'Add script',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: _hovered ? AppColors.accent : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Custom commands section ──────────────────────────────────────────────

class _CustomCommandsSection extends StatelessWidget {
  const _CustomCommandsSection({
    required this.project,
    required this.running,
    required this.onRun,
    required this.onEdit,
    required this.onAdd,
  });

  final Project project;
  final bool running;
  final ValueChanged<CustomCommand> onRun;
  final ValueChanged<CustomCommand?> onEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'custom commands',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: AppColors.muted,
            letterSpacing: 0.12 * 10,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in project.customCommands)
              _CommandChip(
                command: c,
                enabled: !running,
                onTap: () => onRun(c),
                onEdit: () => onEdit(c),
              ),
            _AddCommandChip(onTap: onAdd),
          ],
        ),
      ],
    );
  }
}

class _CommandChip extends StatefulWidget {
  const _CommandChip({
    required this.command,
    required this.enabled,
    required this.onTap,
    required this.onEdit,
  });

  final CustomCommand command;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  State<_CommandChip> createState() => _CommandChipState();
}

class _CommandChipState extends State<_CommandChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _hovered ? AppColors.border2 : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.terminal,
                size: 12,
                color: AppColors.text2,
              ),
              const SizedBox(width: 5),
              Text(
                widget.command.label,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.5,
                  color: AppColors.text2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCommandChip extends StatefulWidget {
  const _AddCommandChip({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_AddCommandChip> createState() => _AddCommandChipState();
}

class _AddCommandChipState extends State<_AddCommandChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _hovered ? AppColors.accent : AppColors.border2,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add,
                size: 12,
                color: _hovered ? AppColors.accent : AppColors.muted,
              ),
              const SizedBox(width: 4),
              Text(
                'Add',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.5,
                  color: _hovered ? AppColors.accent : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
