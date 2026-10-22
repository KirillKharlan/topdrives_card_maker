import 'dart:convert';
import 'dart:io';

Future<Object?> readJsonFile(File file) async {
  if (!await file.exists()) return null;
  try {
    return jsonDecode(await file.readAsString());
  } catch (_) {
    return null;
  }
}

/// Writes via a temp file so a crash never leaves a half-written JSON.
Future<void> writeJsonFile(File file, Object data) async {
  final tmp = File('${file.path}.tmp');
  await tmp.writeAsString(jsonEncode(data), flush: true);
  await tmp.rename(file.path);
}
