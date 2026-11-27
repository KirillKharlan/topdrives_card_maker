import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Lets the person stop a running download.
class LamaDownloadToken {
  bool cancelled = false;
  HttpClient? _client;

  void cancel() {
    cancelled = true;
    _client?.close(force: true);
  }
}

/// The LaMa model file (big-lama exported to ONNX by Carve, Apache-2.0, fixed 512 x 512,
/// inputs image + mask, output 0..255). It is not part of the app: it is downloaded once,
/// checked with its SHA-256 and kept in the app's private folder (not in the backup).
class LamaModel {
  LamaModel._();

  static const sizeBytes = 208044816;
  static const sha256Hex = '1faef5301d78db7dda502fe59966957ec4b79dd64e16f03ed96913c7a4eb68d6';

  /// The original first, then a byte-identical copy on GitHub (the checksum is checked either way).
  static const urls = [
    'https://huggingface.co/Carve/LaMa-ONNX/resolve/main/lama_fp32.onnx',
    'https://github.com/neureps/carousel-fit-models/releases/download/lama-v1/lama-fp32-1faef5301d78.onnx',
  ];

  static Future<File> _file() async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/models');
    await dir.create(recursive: true);
    return File('${dir.path}/lama_fp32.onnx');
  }

  /// The model file when it is on the phone and complete, else null.
  static Future<File?> fileIfReady() async {
    final file = await _file();
    if (await file.exists() && await file.length() == sizeBytes) return file;
    return null;
  }

  static Future<bool> isReady() async => await fileIfReady() != null;

  static Future<void> delete() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }

  /// Downloads and checks the model. [onProgress] gets 0..1 (null when the size is not known).
  static Future<File> download({
    required void Function(double? fraction) onProgress,
    required LamaDownloadToken token,
  }) async {
    final target = await _file();
    Object? lastError;
    for (final url in urls) {
      if (token.cancelled) throw const HttpException('Cancelled');
      final part = File('${target.path}.part');
      try {
        await _downloadTo(url, part, onProgress, token);
        final digest = await sha256.bind(part.openRead()).first;
        if (digest.toString() != sha256Hex) {
          throw const HttpException('The downloaded file is damaged (checksum differs)');
        }
        if (await target.exists()) await target.delete();
        return await part.rename(target.path);
      } catch (e) {
        lastError = e;
        if (await part.exists()) await part.delete();
        if (token.cancelled) rethrow;
      }
    }
    throw lastError ?? const HttpException('Could not download the model');
  }

  static Future<void> _downloadTo(
    String url,
    File file,
    void Function(double? fraction) onProgress,
    LamaDownloadToken token,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    token._client = client;
    IOSink? sink;
    try {
      final request = await client.getUrl(Uri.parse(url));
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
        onProgress(total > 0 ? received / total : received / sizeBytes);
      }
      await sink.close();
      sink = null;
      if (received != sizeBytes) throw const HttpException('The download was cut short');
    } finally {
      token._client = null;
      await sink?.close().catchError((_) {});
      client.close();
    }
  }
}
