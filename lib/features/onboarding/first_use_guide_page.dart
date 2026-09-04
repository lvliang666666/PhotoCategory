import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../settings/photo_source_controller.dart';

class FirstUseGuidePage extends StatelessWidget {
  const FirstUseGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 72, color: colorScheme.primary),
                  const SizedBox(height: 24),
                  Text('由你选择每一张照片',
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              )),
                  const SizedBox(height: 16),
                  const Text(
                    '应用不会扫描系统图库，也不会自动导入照片。只有你点击“导入照片”并主动选择的图片，才会出现在应用中。',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  _ChoiceCard(
                    icon: Icons.add_photo_alternate_outlined,
                    title: '开始整理照片',
                    subtitle: '无需全图库权限，进入相册后按需手动导入。',
                    onTap: () => context
                        .read<PhotoSourceController>()
                        .completeFirstUse(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Icon(icon, size: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
      );
}
