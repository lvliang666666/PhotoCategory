import 'package:flutter/material.dart';

class PastelIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double size;
  final Widget? customIcon;

  const PastelIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.size = 44,
    this.customIcon,
  });

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor ?? Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(size * .38),
            border: Border.all(color: Colors.white.withValues(alpha: .32)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6E554B).withValues(alpha: .2),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: .4),
                blurRadius: 4,
                offset: const Offset(-2, -2),
              ),
            ],
          ),
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor:
                  foregroundColor ?? Theme.of(context).colorScheme.onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(size * .38),
              ),
            ),
            icon: customIcon ?? Icon(icon, size: size * .5),
          ),
        ),
      );
}
