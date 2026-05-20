import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/colors.dart';
import '../../state/providers.dart';
import '../dialogs/add_project_dialog.dart';

class Sidebar extends ConsumerStatefulWidget {
  const Sidebar({super.key});

  @override
  ConsumerState<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<Sidebar> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
    final selectedId = ref.watch(selectedProjectIdProvider);

    final filtered = _query.isEmpty
        ? projects
        : projects
            .where((p) =>
                p.name.toLowerCase().contains(_query.toLowerCase()) ||
                p.path.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(
          right: BorderSide(color: AppColors.hairline, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WORKSPACE',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.14 * 10,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Projects',
                        style: GoogleFonts.sourceSerif4(
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text,
                          letterSpacing: -0.02 * 28,
                        ),
                      ),
                      TextSpan(
                        text: '.',
                        style: GoogleFonts.sourceSerif4(
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                          color: AppColors.accent,
                          letterSpacing: -0.02 * 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: _SearchBar(
              controller: _searchCtrl,
              onChanged: (q) => setState(() => _query = q),
            ),
          ),

          // Project list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No projects',
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        color: AppColors.dim,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final p = filtered[i];
                      return _ProjectItem(
                        project: p,
                        isSelected: p.id == selectedId,
                        onTap: () => ref
                            .read(selectedProjectIdProvider.notifier)
                            .state = p.id,
                        onRemove: () async {
                          await ref
                              .read(projectsProvider.notifier)
                              .remove(p.id);
                          if (selectedId == p.id) {
                            ref
                                .read(selectedProjectIdProvider.notifier)
                                .state = null;
                          }
                        },
                        onOpenFinder: () =>
                            ref.read(finderRevealProvider).openFolder(p.path),
                      );
                    },
                  ),
          ),

          // Footer add button
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.hairline, width: 1),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            child: _AddProjectButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const AddProjectDialog(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Search bar ────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          const Icon(Icons.search, size: 14, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                color: AppColors.text,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Search projects',
                hintStyle: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  color: AppColors.dim,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Text(
              '⌘P',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: AppColors.dim,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Project item ─────────────────────────────────────────────────────────

class _ProjectItem extends StatefulWidget {
  const _ProjectItem({
    required this.project,
    required this.isSelected,
    required this.onTap,
    required this.onRemove,
    required this.onOpenFinder,
  });

  final dynamic project;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onOpenFinder;

  @override
  State<_ProjectItem> createState() => _ProjectItemState();
}

class _ProjectItemState extends State<_ProjectItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.project.name as String;
    final path = widget.project.path as String;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 1),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_hovered || widget.isSelected)
                    ? AppColors.surface
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: widget.isSelected
                    ? Border.all(color: AppColors.border, width: 1)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Glyph badge
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.accentTint,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: AppColors.accentSoft),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          name.isNotEmpty
                              ? name[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.sourceSerif4(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.dmSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_hovered && !widget.isSelected)
                        _ThreeDotButton(
                          onRemove: widget.onRemove,
                          onOpenFinder: widget.onOpenFinder,
                        ),
                    ],
                  ),
                  // Path
                  Padding(
                    padding: const EdgeInsets.only(left: 26, top: 2),
                    child: Text(
                      path,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  // Status row (only when active)
                  if (widget.isSelected)
                    Padding(
                      padding: const EdgeInsets.only(left: 26, top: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: AppColors.ok,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'main · recent',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Active left accent bar
            if (widget.isSelected)
              Positioned(
                left: -2,
                top: 14,
                bottom: 14,
                child: Container(
                  width: 2,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThreeDotButton extends StatelessWidget {
  const _ThreeDotButton({required this.onRemove, required this.onOpenFinder});
  final VoidCallback onRemove;
  final VoidCallback onOpenFinder;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      iconSize: 16,
      icon: const Icon(Icons.more_horiz, size: 16, color: AppColors.muted),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'remove', child: Text('Remove')),
        const PopupMenuItem(
            value: 'open_finder', child: Text('Open in Finder')),
      ],
      onSelected: (v) {
        if (v == 'remove') onRemove();
        if (v == 'open_finder') onOpenFinder();
      },
    );
  }
}

// ─── Add project button ───────────────────────────────────────────────────

class _AddProjectButton extends StatefulWidget {
  const _AddProjectButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_AddProjectButton> createState() => _AddProjectButtonState();
}

class _AddProjectButtonState extends State<_AddProjectButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.accentTint : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered ? AppColors.accent : AppColors.border2,
              width: 1,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                size: 14,
                color: _hovered ? AppColors.accent : AppColors.muted,
              ),
              const SizedBox(width: 6),
              Text(
                'Add project',
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
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
