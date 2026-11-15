import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/layout_tweaks.dart';
import '../data/repositories/settings_repository.dart';
import 'apk_installer.dart';
import 'update_checker.dart';
import 'update_downloader.dart';

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
              ? 'The new version is downloaded and installed over the old one. Your cards and library are kept.'
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
            if (info.isDirectApk) {
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => _DownloadDialog(info: info),
              );
            } else {
              launchUrl(Uri.parse(info.downloadUrl), mode: LaunchMode.externalApplication);
            }
          },
          child: Text(info.isDirectApk ? 'Update now' : 'Download'),
        ),
      ],
    ),
  );
}

/// Downloads the new APK with a progress bar and opens the system installer.
/// If anything fails the person can still open the download in the browser.
class _DownloadDialog extends StatefulWidget {
  const _DownloadDialog({required this.info});

  final UpdateInfo info;

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

enum _Phase { downloading, needsPermission, failed }

class _DownloadDialogState extends State<_DownloadDialog> {
  final _token = DownloadToken();
  _Phase _phase = _Phase.downloading;
  double? _progress;
  String _error = '';
  File? _apk;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _token.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    try {
      final file = await UpdateDownloader.download(
        widget.info,
        token: _token,
        onProgress: (v) {
          if (mounted) setState(() => _progress = v);
        },
      );
      _apk = file;
      await _install();
    } catch (e) {
      if (_token.cancelled || !mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = '$e';
      });
    }
  }

  Future<void> _install() async {
    final apk = _apk;
    if (apk == null || !mounted) return;
    try {
      final outcome = await ApkInstaller.install(apk);
      if (!mounted) return;
      if (outcome == InstallOutcome.started) {
        Navigator.pop(context);
      } else {
        setState(() => _phase = _Phase.needsPermission);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = 'Could not open the installer: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.downloading:
        final percent = _progress == null ? '' : '${(_progress! * 100).round()}%';
        return AlertDialog(
          title: Text('Downloading ${widget.info.version}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(percent),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _token.cancel();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      case _Phase.needsPermission:
        return AlertDialog(
          title: const Text('Allow installing'),
          content: const Text(
            'Android needs your permission to install updates from this app. Allow it in '
            'the settings page that opened, come back and press Install.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            FilledButton(onPressed: _install, child: const Text('Install')),
          ],
        );
      case _Phase.failed:
        return AlertDialog(
          title: const Text('Update failed'),
          content: Text(_error),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                launchUrl(Uri.parse(widget.info.downloadUrl), mode: LaunchMode.externalApplication);
              },
              child: const Text('Open in browser'),
            ),
          ],
        );
    }
  }
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
