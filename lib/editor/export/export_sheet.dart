import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../editor_controller.dart';
import 'card_exporter.dart';

/// Export options. By default the tags (above) and the prize marker (below)
/// are included, so the saved picture looks like the editor preview. The
/// cropped car photo can also be saved on its own.
Future<void> showExportSheet(BuildContext context, EditorController c) {
  final hasExtras = c.project.prize || c.project.tags.isNotEmpty;
  final hasPhoto = c.photoFile != null;
  var includeExtras = true;

  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        Future<void> deliver(
          Future<Uint8List> Function() makePng, {
          required bool share,
          required String suffix,
        }) async {
          Navigator.pop(sheetContext);
          final messenger = ScaffoldMessenger.of(context);
          try {
            final png = await makePng();
            if (share) {
              final safe = c.project.name.replaceAll(RegExp(r'[^\w\-]+'), '_');
              await CardExporter.share(png, '${safe.isEmpty ? 'card' : safe}$suffix');
            } else {
              await CardExporter.saveToGallery(png);
              messenger.showSnackBar(const SnackBar(content: Text('Saved to gallery')));
            }
          } catch (e) {
            messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
          }
        }

        Future<Uint8List> cardPng() => c.withoutVideo(
              () => CardExporter.capture((hasExtras && includeExtras) ? c.fullKey : c.cardKey),
            );

        Future<Uint8List> photoPng() => CardExporter.croppedPhoto(
              file: c.photoFile!,
              transform: c.project.photoTransform,
              fill: c.project.photoFill,
              background: c.template.photoBackground,
              smartFillFile: c.smartFillFile,
              cardWidth: c.template.width,
              cardHeight: c.template.height,
            );

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasExtras)
                  SwitchListTile(
                    title: const Text('Include tags and prize marker'),
                    subtitle: const Text('Off: only the card itself'),
                    value: includeExtras,
                    onChanged: (v) => setSheetState(() => includeExtras = v),
                  ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Save card to gallery'),
                  onTap: () => deliver(cardPng, share: false, suffix: ''),
                ),
                ListTile(
                  leading: const Icon(Icons.ios_share),
                  title: const Text('Share card'),
                  onTap: () => deliver(cardPng, share: true, suffix: ''),
                ),
                if (hasPhoto) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.crop),
                    title: const Text('Save cropped photo'),
                    subtitle: const Text('Only the photo, framed as on the card'),
                    onTap: () => deliver(photoPng, share: false, suffix: '_photo'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.ios_share),
                    title: const Text('Share cropped photo'),
                    onTap: () => deliver(photoPng, share: true, suffix: '_photo'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}
