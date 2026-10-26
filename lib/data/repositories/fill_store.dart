import 'dart:io';
import 'dart:typed_data';

/// Generated fill pictures, one file per generation. A new file name is used
/// every time, so Flutter's image cache never shows an old picture.
class FillStore {
  late final Directory _dir;

  Future<void> init(Directory root) async {
    _dir = Directory('${root.path}/fills');
    await _dir.create(recursive: true);
  }

  File fileOf(String name) => File('${_dir.path}/$name');

  Future<String> save(String projectId, Uint8List png, {String? replacing}) async {
    final name = '${projectId}_${DateTime.now().microsecondsSinceEpoch}.png';
    await fileOf(name).writeAsBytes(png, flush: true);
    await delete(replacing);
    return name;
  }

  Future<void> delete(String? name) async {
    if (name == null) return;
    final file = fileOf(name);
    if (await file.exists()) await file.delete();
  }
}
