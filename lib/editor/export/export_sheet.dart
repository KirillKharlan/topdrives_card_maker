import 'package:flutter/material.dart';

import '../editor_controller.dart';
import 'card_exporter.dart';

Future<void> showExportSheet(BuildContext context, EditorController c) {
  final hasExtras = c.project.prize || c.project.tagAsset != null;
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      Future<void> run(GlobalKey key, {required bool share}) async {
        Navigator.pop(sheetContext);
        final messenger = ScaffoldMessenger.of(context);
        try {
          final png = await CardExporter.capture(key);
          if (share) {
            final safe = c.project.name.replaceAll(RegExp(r'[^\w\-]+'), '_');
            await CardExporter.share(png, safe.isEmpty ? 'card' : safe);
          } else {
            await CardExporter.saveToGallery(png);
            messenger.showSnackBar(const SnackBar(content: Text('Saved to gallery')));
          }
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
        }
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Save card to gallery'),
              onTap: () => run(c.cardKey, share: false),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Share card'),
              onTap: () => run(c.cardKey, share: true),
            ),
            if (hasExtras) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Save card + tag/banner'),
                onTap: () => run(c.fullKey, share: false),
              ),
              ListTile(
                leading: const Icon(Icons.ios_share),
                title: const Text('Share card + tag/banner'),
                onTap: () => run(c.fullKey, share: true),
              ),
            ],
          ],
        ),
      );
    },
  );
}
