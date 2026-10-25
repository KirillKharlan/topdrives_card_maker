import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/layout_tweaks.dart';
import '../data/repositories/settings_repository.dart';
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
Future<void> showAppInfoDialog(BuildContext context, SettingsRepository settings) async {
  final info = await PackageInfo.fromPlatform();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Card Maker'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Version ${info.version} (build ${info.buildNumber})'),
          const SizedBox(height: 16),
          const Text('Fine-tune: tyre name height'),
          ValueListenableBuilder<double>(
            valueListenable: LayoutTweaks.tyreNameOffset,
            builder: (context, offset, _) => Row(
              children: [
                Expanded(
                  child: Slider(
                    value: offset.clamp(-5.0, 5.0).toDouble(),
                    min: -5,
                    max: 5,
                    divisions: 40,
                    label: offset.toStringAsFixed(2),
                    onChanged: (v) => LayoutTweaks.tyreNameOffset.value = v,
                    onChangeEnd: settings.setTyreNameOffset,
                  ),
                ),
                SizedBox(width: 44, child: Text(offset.toStringAsFixed(2))),
              ],
            ),
          ),
          Text(
            'Plus moves the name down, minus up. Use it if the name is not level '
            'with the T of "Tyres".',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
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
