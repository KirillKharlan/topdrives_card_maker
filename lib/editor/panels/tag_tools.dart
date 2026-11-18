import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/card_tag.dart';
import '../../data/tag_images.dart';
import '../../logo_editor/logo_editor_screen.dart';
import '../../logo_editor/logo_trimmer.dart';
import '../../logo_editor/rgba_image.dart';
import '../canvas/custom_tag_view.dart';
import '../export/card_exporter.dart';

/// Makes a tag from a picture of the phone's gallery (for example a screenshot of a tag).
/// Asks for a name and whether the background should be removed. Returns the new tag
/// (its picture is already stored), or null when cancelled.
Future<CardTag?> createTagFromPhoto(BuildContext context) async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (picked == null || !context.mounted) return null;

  final dot = picked.name.lastIndexOf('.');
  final suggestion = dot > 0 ? picked.name.substring(0, dot) : picked.name;
  final nameController = TextEditingController(text: suggestion);
  var removeBackground = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Tag from photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 64,
              child: Image.file(
                File(picked.path),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Tag name', border: OutlineInputBorder()),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Remove background'),
              subtitle: const Text('Opens the background editor next'),
              value: removeBackground,
              onChanged: (v) => setState(() => removeBackground = v),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Add')),
        ],
      ),
    ),
  );
  final typed = nameController.text.trim();
  nameController.dispose();
  if (ok != true || !context.mounted) return null;

  final file = File(picked.path);
  Uint8List png;
  if (removeBackground) {
    final edited = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(builder: (_) => LogoEditorScreen(file: file)),
    );
    if (edited == null) return null;
    png = edited;
  } else {
    // Plain or transparent margins around the tag are cut off; otherwise the picture is kept.
    final trimmed = await trimLogoMargins(file);
    png = trimmed ?? await (await RgbaImage.decode(await file.readAsBytes(), maxSide: 900)).toPng();
  }
  final fileName = await TagImages.add(png);
  return CardTag(image: fileName, text: typed.isEmpty ? 'Tag' : typed);
}

/// Saves a tag as a PNG picture to the phone's gallery. Returns a sentence for the person
/// (done, or why it did not work); the picker shows it, because a snack bar would hide
/// behind the picker sheet.
Future<String> saveTagToPhone(CardTag tag) async {
  try {
    Uint8List png;
    if (tag.isImage) {
      final file = TagImages.fileOf(tag.image!);
      if (file == null || !await file.exists()) throw StateError('the picture of this tag is missing');
      png = await file.readAsBytes();
    } else if (tag.asset != null) {
      png = (await rootBundle.load(tag.asset!)).buffer.asUint8List();
    } else {
      png = await CustomTagView.renderPng(tag.text ?? '', tag.colorValue ?? 0xFFF2C21B);
    }
    await CardExporter.saveToGallery(png);
    return 'Tag saved to the gallery.';
  } catch (e) {
    return 'Could not save the tag: $e';
  }
}
