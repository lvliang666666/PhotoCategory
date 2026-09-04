import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';

class ClayCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;

  const ClayCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.radius = AppSpacing.radiusCard,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(
                alpha: isDark ? .16 : .32,
              ),
        ),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xFF765F55).withValues(alpha: isDark ? .18 : .085),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? .02 : .54),
            blurRadius: 5,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
