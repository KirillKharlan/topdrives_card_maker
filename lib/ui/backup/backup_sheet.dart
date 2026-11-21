import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/backup_service.dart';
import '../common/dialogs.dart';

/// Backup and restore: one .zip file with everything in the app.
Future<void> showBackupSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Create backup'),
            subtitle: const Text('One .zip with all cards, photos, logos, videos, albums and settings'),
            onTap: () {
              Navigator.pop(sheetContext);
              _create(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore from backup'),
            subtitle: const Text('Replaces everything that is in the app now'),
            onTap: () {
              Navigator.pop(sheetContext);
              _restore(context);
            },
          ),
        ],
      ),
    ),
  );
}

void _showBusy(BuildContext context, String text) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: 20),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    ),
  );
}

Future<void> _create(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  _showBusy(context, 'Packing the backup…');
  try {
    final file = await BackupService.create();
    navigator.pop();
    await Share.shareXFiles([XFile(file.path)]);
  } catch (e) {
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
  }
}

Future<void> _restore(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final ok = await confirmDialog(
    context,
    title: 'Restore from backup?',
    message: 'Everything in the app now (cards, photos, logos, albums, settings) is replaced '
        'by the content of the backup file. The app closes afterwards.',
    action: 'Choose file',
  );
  if (!ok) return;
  final picked = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['zip'],
  );
  final path = picked?.files.single.path;
  if (path == null) return;
  if (!context.mounted) return;
  _showBusy(context, 'Restoring…');
  try {
    await BackupService.restore(File(path));
    navigator.pop();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Backup restored'),
        content: const Text('The app will close now. Open it again to see the restored data.'),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close app')),
        ],
      ),
    );
    exit(0);
  } catch (e) {
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text('Restore failed: $e')));
  }
}
