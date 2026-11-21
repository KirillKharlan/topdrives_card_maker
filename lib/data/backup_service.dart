import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';

/// Backup of everything the app keeps (cards, photos, logos, videos, albums,
/// settings) as one .zip file, and restoring from such a file.
class BackupService {
  BackupService._();

  static const _rootName = 'card_maker';

  static Future<Directory> _docs() => getApplicationDocumentsDirectory();

  /// Writes the backup into the temporary folder and returns the file.
  static Future<File> create() async {
    final docs = await _docs();
    final root = Directory('${docs.path}/$_rootName');
    final tmp = await getTemporaryDirectory();
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}';
    final out = File('${tmp.path}/card_maker_backup_$stamp.zip');
    if (await out.exists()) await out.delete();
    final rootPath = root.path;
    final outPath = out.path;
    await Isolate.run<void>(() async {
      final encoder = ZipFileEncoder();
      await Future<void>.sync(() => encoder.zipDirectory(Directory(rootPath), filename: outPath));
    });
    return out;
  }

  /// Replaces all data of the app with the content of [zip]. The old data is
  /// kept until the new data is in place. The app has to be restarted after
  /// this, the screens still hold the old data in memory.
  static Future<void> restore(File zip) async {
    final docs = await _docs();
    final root = Directory('${docs.path}/$_rootName');
    final stage = Directory('${docs.path}/${_rootName}_restore');
    final old = Directory('${docs.path}/${_rootName}_before_restore');
    if (await stage.exists()) await stage.delete(recursive: true);
    await stage.create(recursive: true);
    final zipPath = zip.path;
    final stagePath = stage.path;
    try {
      await Isolate.run<void>(() async {
        await Future<void>.sync(() => extractFileToDisk(zipPath, stagePath));
      });
      const known = ['projects', 'photos', 'logos', 'videos', 'albums.json', 'settings.json'];
      final found = stage.listSync().any((e) => known.contains(e.uri.pathSegments
          .where((s) => s.isNotEmpty)
          .last));
      if (!found) throw const FormatException('This file is not a Card Maker backup.');
    } catch (_) {
      if (await stage.exists()) await stage.delete(recursive: true);
      rethrow;
    }
    if (await old.exists()) await old.delete(recursive: true);
    if (await root.exists()) await root.rename(old.path);
    try {
      await stage.rename(root.path);
    } catch (_) {
      if (await old.exists()) await old.rename(root.path);
      rethrow;
    }
    if (await old.exists()) await old.delete(recursive: true);
  }
}
