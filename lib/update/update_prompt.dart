import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update_checker.dart';

/// Checks for a newer release and tells the user. With [manual] = false
/// (app start) it stays silent unless an update exists, so an offline launch
/// shows nothing.
Future<void> checkForUpdates(BuildContext context, {required bool manual}) async {
  final result = await UpdateChecker.check();
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);

  switch (result.status) {
    case UpdateStatus.available:
      await _showUpdateDialog(context, result.info!);
    case UpdateStatus.upToDate:
      if (manual) messenger.showSnackBar(const SnackBar(content: Text('You have the latest version')));
    case UpdateStatus.failed:
      if (manual) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not check for updates. Are you offline?')),
        );
      }
    case UpdateStatus.notConfigured:
      if (manual) {
        messenger.showSnackBar(
          const SnackBar(content: Text('This build has no update source (local build).')),
        );
      }
  }
}

Future<void> _showUpdateDialog(BuildContext context, UpdateInfo info) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Update ${info.version} available'),
      content: SingleChildScrollView(
        child: Text(
          info.notes.isEmpty
              ? 'Download the new version and open it to update. Your cards and library are kept.'
              : '${info.notes}\n\nYour cards and library are kept.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            launchUrl(Uri.parse(info.downloadUrl), mode: LaunchMode.externalApplication);
          },
          child: const Text('Download'),
        ),
      ],
    ),
  );
}

/// "About" dialog: current version and a manual update check.
Future<void> showAppInfoDialog(BuildContext context) async {
  final info = await PackageInfo.fromPlatform();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Card Maker'),
      content: Text('Version ${info.version} (build ${info.buildNumber})'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            checkForUpdates(context, manual: true);
          },
          child: const Text('Check for updates'),
        ),
      ],
    ),
  );
}
