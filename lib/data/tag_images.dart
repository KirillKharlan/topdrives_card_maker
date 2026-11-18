import 'dart:io';
import 'dart:typed_data';

/// Pictures that tags were made from ("tag from photo"). A tag refers to its picture by
/// file name; the files live in the app's own folder `tag_images`.
class TagImages {
  TagImages._();

  static Directory? _dir;

  static Future<void> init(Directory root) async {
    final dir = Directory('${root.path}/tag_images');
    await dir.create(recursive: true);
    _dir = dir;
  }

  /// The picture file of a tag, or null before [init].
  static File? fileOf(String name) {
    final dir = _dir;
    return dir == null ? null : File('${dir.path}/$name');
  }

  /// Stores a PNG and returns its file name.
  static Future<String> add(Uint8List png) async {
    final dir = _dir;
    if (dir == null) throw StateError('The tag folder is not ready yet.');
    final name = '${DateTime.now().microsecondsSinceEpoch}.png';
    await File('${dir.path}/$name').writeAsBytes(png, flush: true);
    return name;
  }
}
