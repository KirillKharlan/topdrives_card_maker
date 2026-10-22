import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/media_item.dart';
import '../../data/repositories/app_store.dart';
import '../../data/repositories/media_library.dart';
import '../common/dialogs.dart';

/// Grid of stored images. Used for car photos and for logos.
/// With [pickMode] a tap returns the chosen [MediaItem] to the caller.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
    super.key,
    required this.title,
    required this.library,
    required this.usageCount,
    required this.onDelete,
    this.pickMode = false,
    this.round = false,
  });

  LibraryScreen.photos(AppStore store, {Key? key, bool pickMode = false})
      : this(
          key: key,
          title: 'Car photos',
          library: store.photos,
          usageCount: store.projects.countUsingPhoto,
          onDelete: store.deletePhoto,
          pickMode: pickMode,
        );

  LibraryScreen.logos(AppStore store, {Key? key, bool pickMode = false})
      : this(
          key: key,
          title: 'Logos',
          library: store.logos,
          usageCount: store.projects.countUsingLogo,
          onDelete: store.deleteLogo,
          pickMode: pickMode,
          round: true,
        );

  final String title;
  final MediaLibrary library;
  final int Function(String id) usageCount;
  final Future<void> Function(String id) onDelete;
  final bool pickMode;
  final bool round;

  Future<void> _add() async {
    final files = await ImagePicker().pickMultiImage();
    for (final f in files) {
      await library.addFromPath(f.path);
    }
  }

  Future<void> _delete(BuildContext context, MediaItem item) async {
    final n = usageCount(item.id);
    final ok = await confirmDialog(
      context,
      title: 'Delete from library?',
      message: n == 0
          ? 'This image is not used in any card.'
          : 'It is used in $n card(s). The cards stay, but lose this image.',
    );
    if (ok) await onDelete(item.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(pickMode ? 'Choose: $title' : title)),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        tooltip: 'Add from gallery',
        child: const Icon(Icons.add_photo_alternate_outlined),
      ),
      body: ListenableBuilder(
        listenable: library,
        builder: (context, _) {
          final items = library.items;
          if (items.isEmpty) {
            return const Center(child: Text('Nothing here yet. Tap + to add images.'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              final file = library.fileOf(item.id);
              final image = file == null
                  ? const SizedBox.shrink()
                  : Image.file(file, fit: BoxFit.cover, cacheWidth: 400);
              return GestureDetector(
                onTap: pickMode ? () => Navigator.pop(context, item) : null,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    round
                        ? ClipOval(child: image)
                        : ClipRRect(borderRadius: BorderRadius.circular(8), child: image),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(context, item),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
