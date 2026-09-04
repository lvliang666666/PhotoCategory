import 'package:flutter/material.dart';

import '../core/theme/clay_assets.dart';
import 'clay_card.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: ClayCard(
            radius: 30,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 25, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 112,
                    height: 96,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6E554B).withValues(alpha: .14),
                          blurRadius: 13,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const ClayAssetIcon(
                      assetPath: ClayAssets.photo,
                      size: 100,
                      zoom: 1.52,
                      cacheWidth: 320,
                      radius: 24,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 220,
                      child: FilledButton.icon(
                        onPressed: onAction,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(actionLabel!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
