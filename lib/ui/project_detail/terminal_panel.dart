import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xterm/xterm.dart';

import '../../app/colors.dart';
import '../../domain/models/project.dart';
import '../../state/project_runner_controller.dart';
import '../../state/providers.dart';

enum _LogTab { output, problems, history }

class TerminalPanel extends ConsumerStatefulWidget {
  const TerminalPanel({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends ConsumerState<TerminalPanel>
    with TickerProviderStateMixin {
  final Terminal _terminal = Terminal(maxLines: 10000);
  final StringBuffer _log = StringBuffer();
  StreamSubscription<Uint8List>? _outSub;
  StreamSubscription<RunnerState>? _stateSub;
  _LogTab _activeTab = _LogTab.output;
  late AnimationController _progressAnim;

  @override
  void initState() {
    super.initState();
    final controller = ref.read(projectRunnerProvider(widget.project.id));
    _outSub = controller.output.listen((data) {
      final text = utf8.decode(data, allowMalformed: true);
      _terminal.write(text);
      _log.write(text);
    });
    _stateSub = controller.stream.listen((_) {
      if (mounted) setState(() {});
    });
    _progressAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _outSub?.cancel();
    _stateSub?.cancel();
    _progressAnim.dispose();
    super.dispose();
  }

  Future<void> _saveLog() async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save log to…',
      fileName: '${widget.project.name}-log.txt',
    );
    if (path == null) return;
    await File(path).writeAsString(_stripAnsi(_log.toString()));
  }

  void _clearTerminal() {
    _terminal.write('\x1b[2J\x1b[H');
    _log.clear();
    if (mounted) setState(() {});
  }

  String _stripAnsi(String input) =>
      input.replaceAll(RegExp(r'\x1B\[[0-9;?]*[ -/]*[@-~]'), '');

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(projectRunnerProvider(widget.project.id));
    final running = controller.isRunning;

    return Column(
      children: [
        // Log bar
        _LogBar(
          activeTab: _activeTab,
          controller: controller,
          running: running,
          onTabChanged: (tab) => setState(() => _activeTab = tab),
          onClear: _clearTerminal,
          onSave: _saveLog,
          onStop: controller.stop,
        ),

        // Progress strip
        _ProgressStrip(running: running, animation: _progressAnim),

        // Log body
        Expanded(
          child: _activeTab == _LogTab.output
              ? _OutputTab(terminal: _terminal)
              : _activeTab == _LogTab.problems
                  ? const _ProblemsTab()
                  : const _HistoryTab(),
        ),
      ],
    );
  }
}

// ─── Log bar ─────────────────────────────────────────────────────────────

class _LogBar extends StatelessWidget {
  const _LogBar({
    required this.activeTab,
    required this.controller,
    required this.running,
    required this.onTabChanged,
    required this.onClear,
    required this.onSave,
    required this.onStop,
  });

  final _LogTab activeTab;
  final ProjectRunnerController controller;
  final bool running;
  final ValueChanged<_LogTab> onTabChanged;
  final VoidCallback onClear;
  final VoidCallback onSave;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      height: 38,
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(
          bottom: BorderSide(color: AppColors.hairline),
        ),
      ),
      child: Row(
        children: [
          // Tabs
          _TabItem(
            label: 'Output',
            active: activeTab == _LogTab.output,
            onTap: () => onTabChanged(_LogTab.output),
          ),
          const SizedBox(width: 4),
          _TabItem(
            label: 'Problems',
            active: activeTab == _LogTab.problems,
            onTap: () => onTabChanged(_LogTab.problems),
          ),
          const SizedBox(width: 4),
          _TabItem(
            label: 'History',
            active: activeTab == _LogTab.history,
            onTap: () => onTabChanged(_LogTab.history),
          ),

          const Spacer(),

          // Status
          _StatusDisplay(controller: controller, running: running),

          const SizedBox(width: 12),

          // Tool buttons
          _ToolButton(icon: Icons.tune, tooltip: 'Filter', onTap: () {}),
          _ToolButton(icon: Icons.search, tooltip: 'Search', onTap: () {}),
          _ToolButton(
            icon: Icons.save_outlined,
            tooltip: 'Save log',
            onTap: onSave,
          ),
          _ToolButton(
            icon: Icons.cleaning_services_outlined,
            tooltip: 'Clear',
            onTap: onClear,
          ),
          if (running)
            _ToolButton(
              icon: Icons.stop_rounded,
              tooltip: 'Stop',
              onTap: onStop,
              color: AppColors.danger,
            ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.accent : Colors.transparent,
              width: 1.5,
            ),
          ),
        ),
        height: 38,
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: active ? AppColors.text : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _StatusDisplay extends StatelessWidget {
  const _StatusDisplay({
    required this.controller,
    required this.running,
  });

  final ProjectRunnerController controller;
  final bool running;

  @override
  Widget build(BuildContext context) {
    if (running) {
      final label = controller.current?.label ?? '';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Spinner(),
          const SizedBox(width: 6),
          Text(
            'Running · $label',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11.5,
              color: AppColors.text2,
            ),
          ),
        ],
      );
    }

    final code = controller.lastExitCode;
    final dur = controller.lastDuration;
    final label = controller.current?.label ?? '';

    if (code == null) return const SizedBox.shrink();

    if (code == 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: AppColors.ok,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              size: 9,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label · ',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11.5,
                    color: AppColors.text2,
                  ),
                ),
                TextSpan(
                  text: '${dur?.inSeconds ?? 0}s',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: AppColors.danger,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, size: 9, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Text(
          code < 0 ? 'Cancelled' : 'exit $code',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11.5,
            color: AppColors.text2,
          ),
        ),
      ],
    );
  }
}

class _Spinner extends StatefulWidget {
  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            value: null,
            color: AppColors.accent,
          ),
        );
      },
    );
  }
}

class _ToolButton extends StatefulWidget {
  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _hovered ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(
              widget.icon,
              size: 15,
              color: widget.color ??
                  (_hovered ? AppColors.text : AppColors.muted),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Progress strip ───────────────────────────────────────────────────────

class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({required this.running, required this.animation});
  final bool running;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    if (!running) {
      return Container(
        height: 2,
        color: AppColors.ok.withOpacity(0.4),
      );
    }
    return SizedBox(
      height: 2,
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final total = constraints.maxWidth;
              final barWidth = total * 0.30;
              // slide from -barWidth to total (full travel = total + barWidth)
              final offset =
                  (animation.value * (total + barWidth)) - barWidth;
              return Stack(
                children: [
                  Container(color: AppColors.border),
                  Positioned(
                    left: offset,
                    width: barWidth,
                    top: 0,
                    bottom: 0,
                    child: Container(color: AppColors.accent),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Tab bodies ───────────────────────────────────────────────────────────

class _OutputTab extends StatelessWidget {
  const _OutputTab({required this.terminal});
  final Terminal terminal;

  @override
  Widget build(BuildContext context) {
    return TerminalView(
      terminal,
      theme: TerminalTheme(
        cursor: AppColors.accent,
        selection: AppColors.accentSoft,
        foreground: AppColors.text2,
        background: AppColors.surface2,
        black: const Color(0xFF1F1E1D),
        red: AppColors.danger,
        green: AppColors.ok,
        yellow: AppColors.warn,
        blue: const Color(0xFF3A6EA5),
        magenta: AppColors.accent,
        cyan: const Color(0xFF2F7E79),
        white: const Color(0xFFF7F4EC),
        brightBlack: AppColors.muted,
        brightRed: const Color(0xFFD4665A),
        brightGreen: const Color(0xFF73A65A),
        brightYellow: const Color(0xFFCE9A4A),
        brightBlue: const Color(0xFF5A8BBD),
        brightMagenta: const Color(0xFFCF7055),
        brightCyan: const Color(0xFF3D9E99),
        brightWhite: AppColors.surface,
        searchHitBackground: AppColors.accentSoft,
        searchHitBackgroundCurrent: AppColors.accent,
        searchHitForeground: AppColors.text,
      ),
    );
  }
}

class _ProblemsTab extends StatelessWidget {
  const _ProblemsTab();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface2,
      child: Center(
        child: Text(
          'No problems found.',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            color: AppColors.dim,
          ),
        ),
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface2,
      child: Center(
        child: Text(
          'No history yet.',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            color: AppColors.dim,
          ),
        ),
      ),
    );
  }
}
