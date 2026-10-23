import 'package:flutter/material.dart';

import '../editor_controller.dart';
import 'card_exporter.dart';

/// Export options. By default the tag (above) and the prize marker (below)
/// are included, so the saved picture looks like the editor preview.
Future<void> showExportSheet(BuildContext context, EditorController c) {
  final hasExtras = c.project.prize || c.project.tagAsset != null;
  var includeExtras = true;

  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        Future<void> run({required bool share}) async {
          final key = (hasExtras && includeExtras) ? c.fullKey : c.cardKey;
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
              if (hasExtras)
                SwitchListTile(
                  title: const Text('Include tag and prize marker'),
                  subtitle: const Text('Off: only the card itself'),
                  value: includeExtras,
                  onChanged: (v) => setSheetState(() => includeExtras = v),
                ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Save to gallery'),
                onTap: () => run(share: false),
              ),
              ListTile(
                leading: const Icon(Icons.ios_share),
                title: const Text('Share'),
                onTap: () => run(share: true),
              ),
            ],
          ),
        );
      },
    ),
  );
}
