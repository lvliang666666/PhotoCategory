import 'package:flutter/material.dart';

class RadialMenuAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool destructive;

  const RadialMenuAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });
}

class RadialActionMenu extends StatelessWidget {
  final List<RadialMenuAction> actions;

  const RadialActionMenu({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<int>(
      enabled: actions.isNotEmpty,
      tooltip: '更多操作',
      icon: const Icon(Icons.more_horiz_rounded),
      position: PopupMenuPosition.under,
      offset: const Offset(-8, 6),
      elevation: 8,
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      constraints: const BoxConstraints(minWidth: 210, maxWidth: 260),
      onSelected: (index) => actions[index].onPressed(),
      itemBuilder: (context) {
        final items = <PopupMenuEntry<int>>[];
        for (var index = 0; index < actions.length; index++) {
          final action = actions[index];
          if (action.destructive && items.isNotEmpty) {
            items.add(const PopupMenuDivider(height: 10));
          }
          final foreground =
              action.destructive ? scheme.error : scheme.onSurface;
          items.add(
            PopupMenuItem<int>(
              value: index,
              height: 48,
              child: Row(
                children: [
                  Icon(action.icon, size: 21, color: foreground),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      action.label,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: action.destructive
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return items;
      },
    );
  }
}
