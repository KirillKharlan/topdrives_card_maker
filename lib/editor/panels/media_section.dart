import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/media_item.dart';
import '../../data/models/photo_fill.dart';
import '../../data/models/photo_transform.dart';
import '../../logo_editor/logo_editor_screen.dart';
import '../../ui/library/library_screen.dart';
import '../canvas/logo_tile.dart';
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

  /// Opens the background remover; the result is saved as a NEW logo in the
  /// library (the original stays untouched) and selected for this card.
  Future<void> _removeLogoBackground(BuildContext context) async {
    final file = controller.logoFile;
    if (file == null) return;
    final png = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(builder: (_) => LogoEditorScreen(file: file)),
    );
    if (png == null) return;
    final item = await controller.store.logos.addFromBytes(png);
    controller.setLogo(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final p = controller.project;
    final hasPhoto = p.photoId != null;
    final hasLogo = p.logoId != null;
    final logoFile = controller.logoFile;
    final logoSlot = controller.template.logo;

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
                      value: p.photoTransform.scale
                          .clamp(PhotoTransform.minScale, PhotoTransform.maxScale)
                          .toDouble(),
                      min: PhotoTransform.minScale,
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
              Row(
                children: [
                  const Icon(Icons.rotate_right),
                  Expanded(
                    child: Slider(
                      value: radiansToDegrees(p.photoTransform.rotation)
                          .clamp(-180.0, 180.0)
                          .toDouble(),
                      min: -180,
                      max: 180,
                      onChanged: (v) => controller.setPhotoRotation(degreesToRadians(v)),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Rotate left 90°',
                    icon: const Icon(Icons.rotate_90_degrees_ccw),
                    onPressed: () => controller.rotatePhotoBy(degreesToRadians(-90)),
                  ),
                  IconButton(
                    tooltip: 'Rotate right 90°',
                    icon: const Icon(Icons.rotate_90_degrees_cw),
                    onPressed: () => controller.rotatePhotoBy(degreesToRadians(90)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Empty areas (photo does not reach the card edges):',
                  style: Theme.of(context).textTheme.bodySmall),
              Wrap(
                spacing: 8,
                children: [
                  for (final fill in PhotoFill.values)
                    ChoiceChip(
                      label: Text(fill.label),
                      selected: p.photoFill == fill,
                      onSelected: (_) => controller.setPhotoFill(fill),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Drag, pinch and twist (two fingers) on the card to frame the photo. '
                'Where the photo ends before the card edge, the gap is filled automatically.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        SectionCard(
          title: 'Brand logo',
          children: [
            if (hasLogo && logoFile != null) ...[
              // Same size ratio as the logo slot on the card, so what you see
              // here is what ends up on the card.
              Center(
                child: SizedBox(
                  width: 220,
                  child: FittedBox(
                    child: SizedBox(
                      width: logoSlot.w,
                      height: logoSlot.h,
                      child: ColoredBox(
                        color: const Color(0xFF4B4339),
                        child: LogoTile(
                          file: logoFile,
                          scale: p.logoScale,
                          padding: logoSlot.padding,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.photo_size_select_large),
                  Expanded(
                    child: Slider(
                      value: p.logoScale.clamp(0.3, 2.5).toDouble(),
                      min: 0.3,
                      max: 2.5,
                      onChanged: controller.setLogoScale,
                    ),
                  ),
                  TextButton(
                    onPressed: () => controller.setLogoScale(1.0),
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
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
                    onPressed: () => _removeLogoBackground(context),
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Remove background'),
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
