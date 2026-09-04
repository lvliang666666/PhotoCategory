import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/clay_assets.dart';

class FloatingNavItem {
  final String assetPath;
  final String label;
  final double zoom;
  const FloatingNavItem(this.assetPath, this.label, this.zoom);
}

class FloatingBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const FloatingBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const _items = [
    FloatingNavItem(ClayAssets.photo, '相册', 1.58),
    FloatingNavItem(ClayAssets.gallery, '图库', 1.76),
    FloatingNavItem(ClayAssets.timeline, '时间线', 1.66),
    FloatingNavItem(ClayAssets.settings, '设置', 1.62),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: EdgeInsets.fromLTRB(14, 6, 14, bottom > 0 ? bottom : 10),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCapsule),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark ? .06 : .5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B554C).withValues(alpha: .16),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: .34),
            blurRadius: 5,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_items.length, (index) {
          final selected = index == selectedIndex;
          final item = _items[index];
          return Expanded(
            child: Semantics(
              selected: selected,
              button: true,
              label: item.label,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => onSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 61,
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary.withValues(alpha: .24)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: .2),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: .34),
                              blurRadius: 3,
                              offset: const Offset(-1, -1),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClayAssetIcon(
                        assetPath: item.assetPath,
                        size: selected ? 31 : 29,
                        zoom: item.zoom,
                        cacheWidth: 96,
                        radius: 9,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: selected
                                  ? Color.lerp(
                                      scheme.primary, scheme.onSurface, .34)
                                  : scheme.onSurfaceVariant,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
