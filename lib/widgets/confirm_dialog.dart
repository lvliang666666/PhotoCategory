import 'package:flutter/material.dart';

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = '确定',
    this.cancelLabel = '取消',
    this.isDestructive = false,
  });

  /// Show the dialog and return true if the user confirmed.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = '确定',
    String cancelLabel = '取消',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        isDestructive ? Icons.delete_outline_rounded : Icons.help_rounded,
        color: isDestructive
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5)),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: isDestructive
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error)
                  : null,
              child: Text(confirmLabel),
            ),
          ),
        ]),
      ],
    );
  }
}
