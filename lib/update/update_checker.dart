import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import 'app_version.dart';

enum UpdateStatus { notConfigured, failed, upToDate, available }

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.notes,
  });

  final AppVersion version;

  /// Direct link to the APK (falls back to the release page).
  final String downloadUrl;
  final String notes;
}

class UpdateCheckResult {
  const UpdateCheckResult(this.status, [this.info]);

  final UpdateStatus status;
  final UpdateInfo? info;
}

/// Looks at the latest GitHub Release of this repository. The repository name
/// is injected by CI (--dart-define=GITHUB_REPO=owner/repo); local debug builds
/// have no update source and simply skip the check.
class UpdateChecker {
  UpdateChecker._();

  static const repo = String.fromEnvironment('GITHUB_REPO');

  static Future<UpdateCheckResult> check() async {
    if (repo.isEmpty) return const UpdateCheckResult(UpdateStatus.notConfigured);

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client
          .getUrl(Uri.parse('https://api.github.com/repos/$repo/releases/latest'));
      request.headers.set('Accept', 'application/vnd.github+json');
      request.headers.set('User-Agent', 'card-maker-app');
      final response = await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return const UpdateCheckResult(UpdateStatus.failed);

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final latest = AppVersion.tryParse(json['tag_name'] as String? ?? '');
      final current = AppVersion.tryParse((await PackageInfo.fromPlatform()).version);
      if (latest == null || current == null) {
        return const UpdateCheckResult(UpdateStatus.failed);
      }
      if (latest.compareTo(current) <= 0) {
        return const UpdateCheckResult(UpdateStatus.upToDate);
      }

      final pageUrl = json['html_url'] as String? ?? 'https://github.com/$repo/releases';
      var apkUrl = pageUrl;
      for (final asset in (json['assets'] as List?) ?? const []) {
        if (asset is Map && (asset['name'] as String? ?? '').endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String? ?? pageUrl;
          break;
        }
      }
      var notes = ((json['body'] as String?) ?? '').trim();
      if (notes.length > 600) notes = '${notes.substring(0, 600)}…';

      return UpdateCheckResult(
        UpdateStatus.available,
        UpdateInfo(version: latest, downloadUrl: apkUrl, notes: notes),
      );
    } catch (_) {
      return const UpdateCheckResult(UpdateStatus.failed);
    } finally {
      client.close();
    }
  }
}
