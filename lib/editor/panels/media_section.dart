import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/media_item.dart';
import '../../data/models/photo_transform.dart';
import '../../ui/library/library_screen.dart';
import '../editor_controller.dart';
import 'section_card.dart';

/// Car photo (library, replace, remove, zoom) and brand logo.
class MediaSection extends StatelessWidget {
  const MediaSection({super.key, required this.controller});

  final EditorController controller;

  Future<void> _photoFromLibrary(BuildContext context) async {
    final item = await Navigator.push<MediaItem>(
      context,
      MaterialPageRoute(
        builder: (_) => LibraryScreen.photos(controller.store, pickMode: true),
      ),
    );
    if (item != null) controller.setPhoto(item.id);
  }

  Future<void> _photoFromGallery() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final item = await controller.store.photos.addFromPath(file.path);
    controller.setPhoto(item.id);
  }

  Future<void> _logoFromLibrary(BuildContext context) async {
    final item = await Navigator.push<MediaItem>(
      context,
      MaterialPageRoute(
        builder: (_) => LibraryScreen.logos(controller.store, pickMode: true),
      ),
    );
    if (item != null) controller.setLogo(item.id);
  }

  Future<void> _logoFromGallery() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final item = await controller.store.logos.addFromPath(file.path);
    controller.setLogo(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final p = controller.project;
    final hasPhoto = p.photoId != null;
    final hasLogo = p.logoId != null;

    return Column(
      children: [
        SectionCard(
          title: 'Car photo',
          children: [
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _photoFromLibrary(context),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(hasPhoto ? 'Replace (library)' : 'Library'),
                ),
                OutlinedButton.icon(
                  onPressed: _photoFromGallery,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('From gallery'),
                ),
                if (hasPhoto)
                  OutlinedButton.icon(
                    onPressed: () => controller.setPhoto(null),
                    icon: const Icon(Icons.hide_image_outlined),
                    label: const Text('Remove'),
                  ),
              ],
            ),
            if (hasPhoto) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.zoom_in),
                  Expanded(
                    child: Slider(
                      value: p.photoTransform.scale,
                      min: 1,
                      max: PhotoTransform.maxScale,
                      onChanged: controller.setPhotoScale,
                    ),
                  ),
                  TextButton(
                    onPressed: controller.resetPhotoTransform,
                    child: const Text('Reset'),
                  ),
                ],
              ),
              Text(
                'Drag and pinch on the card to frame the photo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        SectionCard(
          title: 'Brand logo',
          children: [
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _logoFromLibrary(context),
                  icon: const Icon(Icons.shield_outlined),
                  label: Text(hasLogo ? 'Replace (library)' : 'Library'),
                ),
                OutlinedButton.icon(
                  onPressed: _logoFromGallery,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('From gallery'),
                ),
                if (hasLogo)
                  OutlinedButton.icon(
                    onPressed: () => controller.setLogo(null),
                    icon: const Icon(Icons.hide_image_outlined),
                    label: const Text('Remove'),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
