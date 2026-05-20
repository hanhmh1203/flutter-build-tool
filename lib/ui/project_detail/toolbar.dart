import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/colors.dart';
import '../../domain/models/project.dart';
import '../../state/providers.dart';

class ProjectToolbar extends ConsumerWidget {
  const ProjectToolbar({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavors = ref.watch(flavorsForProjectProvider(project.path));
    final devices = ref.watch(devicesProvider);
    final entryPoints = ref.watch(entryPointsForProjectProvider(project.path));

    final selectedDevice = ref.watch(selectedDeviceIdProvider(project.id));
    final selectedFlavor = ref.watch(selectedFlavorProvider(project.id));
    final selectedEntry = ref.watch(selectedEntryPointProvider(project.id));
    final cleanBefore = ref.watch(selectedCleanProvider(project.id));

    // Build the 4 field widgets once; reused in both layout modes.
    final entryField = _UnderlineSelect(
      label: 'ENTRY',
      value: selectedEntry,
      hint: 'main.dart',
      items: _entryItems(entryPoints),
      onChanged: (v) {
        ref.read(selectedEntryPointProvider(project.id).notifier).state = v;
        project.lastEntryPoint = v;
        ref.read(projectsProvider.notifier).update(project);
      },
    );
    final flavorField = _UnderlineSelect(
      label: 'FLAVOR',
      value: selectedFlavor,
      hint: '(default)',
      items: _flavorItems(flavors),
      onChanged: (v) {
        ref.read(selectedFlavorProvider(project.id).notifier).state = v;
        project.lastFlavor = v;
        ref.read(projectsProvider.notifier).update(project);
      },
    );
    final deviceField = _DeviceSelect(
      selectedDevice: selectedDevice,
      devices: devices,
      onChanged: (v) {
        ref.read(selectedDeviceIdProvider(project.id).notifier).state = v;
        project.lastDeviceId = v;
        ref.read(projectsProvider.notifier).update(project);
      },
    );
    final toggleField = _CleanToggle(
      value: cleanBefore,
      onChanged: (val) {
        ref.read(selectedCleanProvider(project.id).notifier).state = val;
        project.cleanBeforeBuild = val;
        ref.read(projectsProvider.notifier).update(project);
      },
    );
    final refreshBtn = _RefreshButton(
      onPressed: () {
        ref.invalidate(devicesProvider);
        ref.invalidate(flavorsForProjectProvider(project.path));
        ref.invalidate(entryPointsForProjectProvider(project.path));
      },
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Wide: single Row with Expanded fields.
          // Narrow (< 620px): Wrap, each field gets a fixed width.
          if (constraints.maxWidth >= 620) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: entryField),
                  const SizedBox(width: 20),
                  Expanded(child: flavorField),
                  const SizedBox(width: 20),
                  Expanded(child: deviceField),
                  const SizedBox(width: 24),
                  toggleField,
                  const SizedBox(width: 12),
                  refreshBtn,
                ],
              ),
            );
          } else {
            // Narrow: Wrap with fixed-width SizedBox per field.
            final fieldW = ((constraints.maxWidth - 48 - 16) / 2)
                .clamp(120.0, 300.0);
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(width: fieldW, child: entryField),
                  SizedBox(width: fieldW, child: flavorField),
                  SizedBox(width: fieldW, child: deviceField),
                  toggleField,
                  refreshBtn,
                ],
              ),
            );
          }
        },
      ),
    );
  }

  List<DropdownMenuItem<String?>> _entryItems(
      AsyncValue<List<String>> entryPoints) {
    final items = entryPoints.maybeWhen(
      data: (l) => l,
      orElse: () => const <String>['lib/main.dart'],
    );
    String label(String path) =>
        path.startsWith('lib/') ? path.substring(4) : path;
    return [
      DropdownMenuItem<String?>(
        value: null,
        child: Text('main.dart', style: _dropdownStyle()),
      ),
      for (final e in items)
        if (e != 'lib/main.dart')
          DropdownMenuItem<String?>(
            value: e,
            child: Text(label(e), style: _dropdownStyle()),
          ),
    ];
  }

  List<DropdownMenuItem<String?>> _flavorItems(
      AsyncValue<List<String>> flavors) {
    final items = flavors.maybeWhen(
      data: (l) => l,
      orElse: () => const <String>[],
    );
    return [
      DropdownMenuItem<String?>(
        value: null,
        child: Text('(default)', style: _dropdownStyle()),
      ),
      for (final f in items)
        DropdownMenuItem<String?>(
          value: f,
          child: Text(f, style: _dropdownStyle()),
        ),
    ];
  }

  TextStyle _dropdownStyle() => GoogleFonts.jetBrainsMono(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: AppColors.text,
      );
}

// ─── Underline select ─────────────────────────────────────────────────────

class _UnderlineSelect extends StatefulWidget {
  const _UnderlineSelect({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final String hint;
  final List<DropdownMenuItem<String?>> items;
  final ValueChanged<String?> onChanged;

  @override
  State<_UnderlineSelect> createState() => _UnderlineSelectState();
}

class _UnderlineSelectState extends State<_UnderlineSelect> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: AppColors.muted,
            letterSpacing: 0.12 * 10,
          ),
        ),
        const SizedBox(height: 4),
        Focus(
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: widget.value,
              isExpanded: true,
              hint: Text(
                widget.hint,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.dim,
                ),
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: AppColors.muted,
              ),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.text,
              ),
              underline: Container(
                height: 1,
                color: _focused ? AppColors.accent : AppColors.border,
              ),
              items: widget.items,
              onChanged: widget.onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Device select ───────────────────────────────────────────────────────

class _DeviceSelect extends StatefulWidget {
  const _DeviceSelect({
    required this.selectedDevice,
    required this.devices,
    required this.onChanged,
  });

  final String? selectedDevice;
  final AsyncValue devices;
  final ValueChanged<String?> onChanged;

  @override
  State<_DeviceSelect> createState() => _DeviceSelectState();
}

class _DeviceSelectState extends State<_DeviceSelect> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.devices is AsyncLoading;
    final list = widget.devices.maybeWhen(
      data: (d) => d as List,
      orElse: () => const [],
    );
    final currentValue =
        (widget.selectedDevice != null &&
                list.any((d) => d.id == widget.selectedDevice))
            ? widget.selectedDevice
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'DEVICE',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: AppColors.muted,
            letterSpacing: 0.12 * 10,
          ),
        ),
        const SizedBox(height: 4),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.muted,
              ),
            ),
          )
        else
          Focus(
            onFocusChange: (focused) => setState(() => _focused = focused),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: currentValue,
                isExpanded: true,
                hint: Text(
                  '(pick)',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.dim,
                  ),
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: AppColors.muted,
                ),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
                underline: Container(
                  height: 1,
                  color: _focused ? AppColors.accent : AppColors.border,
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      '(none)',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  for (final d in list)
                    DropdownMenuItem<String?>(
                      value: d.id as String,
                      child: Text(
                        d.name as String,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                ],
                onChanged: widget.onChanged,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Clean toggle ─────────────────────────────────────────────────────────

class _CleanToggle extends StatelessWidget {
  const _CleanToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PillSwitch(value: value, onChanged: onChanged),
        const SizedBox(width: 8),
        Text(
          'Clean before build',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.text2,
          ),
        ),
      ],
    );
  }
}

class _PillSwitch extends StatelessWidget {
  const _PillSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 32,
        height: 18,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: value ? AppColors.accent : AppColors.border,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Refresh button ───────────────────────────────────────────────────────

class _RefreshButton extends StatefulWidget {
  const _RefreshButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: 'Refresh devices / entry points / flavors',
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hovered ? AppColors.surface2 : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.refresh_rounded,
              size: 16,
              color: _hovered ? AppColors.text : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
