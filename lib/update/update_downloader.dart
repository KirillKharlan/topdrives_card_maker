import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'update_checker.dart';

/// Lets the person stop a running download.
class DownloadToken {
  bool cancelled = false;
  HttpClient? _client;

  void cancel() {
    cancelled = true;
    _client?.close(force: true);
  }
}

/// Downloads the APK of a release into the app's cache (folder `updates/`, the one
/// the installer is allowed to share). Older downloads are deleted first.
class UpdateDownloader {
  UpdateDownloader._();

  /// [onProgress] gets 0..1, or null when the server did not tell the file size.
  static Future<File> download(
    UpdateInfo info, {
    required void Function(double? fraction) onProgress,
    required DownloadToken token,
  }) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final file = File('${dir.path}/card-maker-${info.version}.apk');

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    token._client = client;
    IOSink? sink;
    try {
      // GitHub answers with a redirect to its file storage; HttpClient follows it.
      final request = await client.getUrl(Uri.parse(info.downloadUrl));
      request.headers.set('User-Agent', 'card-maker-app');
      final response = await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw HttpException('The server answered ${response.statusCode}');
      }
      final total = response.contentLength; // -1 when unknown
      var received = 0;
      sink = file.openWrite();
      await for (final chunk in response) {
        if (token.cancelled) throw const HttpException('Cancelled');
        sink.add(chunk);
        received += chunk.length;
        onProgress(total > 0 ? received / total : null);
      }
      await sink.close();
      sink = null;
      if (total > 0 && received != total) {
        throw const HttpException('The download was cut short');
      }
      return file;
    } catch (_) {
      await sink?.close().catchError((_) {});
      if (await file.exists()) await file.delete();
      rethrow;
    } finally {
      token._client = null;
      client.close();
    }
  }
}
