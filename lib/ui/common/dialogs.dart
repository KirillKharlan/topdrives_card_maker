import 'package:flutter/material.dart';

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}
