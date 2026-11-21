import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/card_project.dart';
import '../../data/repositories/app_store.dart';
import '../../editor/export/album_exporter.dart';
import '../../editor/export/card_exporter.dart';

enum _Mode { gallery, share, collageGallery, collageShare }

/// Export many cards at once: separate PNGs (gallery or share) or one collage.
Future<void> showAlbumExportSheet(
  BuildContext context,
  AppStore store,
  List<CardProject> cards, {
  required String name,
}) {
  if (cards.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No cards to export')));
    return Future.value();
  }
  var extras = true;
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        void go(_Mode mode) {
          Navigator.pop(sheetContext);
          _run(context, store, cards, name, extras, mode);
        }

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      cards.length == 1 ? 'Export 1 card' : 'Export ${cards.length} cards',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Tags and prize marker'),
                  subtitle: const Text('For the cards that have them'),
                  value: extras,
                  onChanged: (v) => setSheetState(() => extras = v),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Save PNGs to gallery'),
                  onTap: () => go(_Mode.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.ios_share),
                  title: const Text('Share PNGs'),
                  onTap: () => go(_Mode.share),
                ),
                ListTile(
                  leading: const Icon(Icons.grid_view),
                  title: const Text('Save collage to gallery'),
                  subtitle: const Text('One picture, 3 cards in a row'),
                  onTap: () => go(_Mode.collageGallery),
                ),
                ListTile(
                  leading: const Icon(Icons.ios_share),
                  title: const Text('Share collage'),
                  onTap: () => go(_Mode.collageShare),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

String _safe(String text) => text.replaceAll(RegExp(r'[^\w\-]+'), '_');

String _titleOf(CardProject p) {
  final text = '${p.brand} ${p.model}'.trim();
  return text.isEmpty ? p.name : text;
}

Future<void> _run(
  BuildContext context,
  AppStore store,
  List<CardProject> cards,
  String name,
  bool extras,
  _Mode mode,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final progress = ValueNotifier<int>(0);
  var cancelled = false;
  var dialogOpen = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text('Exporting'),
      content: ValueListenableBuilder<int>(
        valueListenable: progress,
        builder: (_, done, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: done / cards.length),
            const SizedBox(height: 12),
            Text('$done / ${cards.length}'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => cancelled = true, child: const Text('Cancel')),
      ],
    ),
  ).whenComplete(() => dialogOpen = false);

  void closeDialog() {
    if (dialogOpen) navigator.pop();
  }

  try {
    final collage = mode == _Mode.collageGallery || mode == _Mode.collageShare;
    final pngs = <Uint8List>[];
    final files = <XFile>[];
    final dir = await getTemporaryDirectory();
    var saved = 0;
    for (var i = 0; i < cards.length; i++) {
      if (cancelled) break;
      if (!context.mounted) throw StateError('the screen was closed');
      final card = cards[i];
      final width = store.templateFor(card).width;
      final png = await AlbumExporter.renderCard(
        context,
        store,
        card,
        extras: extras,
        pixelRatio: collage ? 800 / width : null,
      );
      switch (mode) {
        case _Mode.gallery:
          await CardExporter.saveToGallery(png);
        case _Mode.share:
          final file = File('${dir.path}/${_safe(name)}_${i + 1}_${_safe(_titleOf(card))}.png');
          await file.writeAsBytes(png, flush: true);
          files.add(XFile(file.path));
        case _Mode.collageGallery:
        case _Mode.collageShare:
          pngs.add(png);
      }
      saved++;
      progress.value = saved;
    }
    closeDialog();
    if (cancelled && saved < cards.length) {
      messenger.showSnackBar(SnackBar(content: Text('Cancelled after $saved cards')));
      if (mode != _Mode.gallery) return;
    }
    switch (mode) {
      case _Mode.gallery:
        if (!cancelled) {
          messenger.showSnackBar(SnackBar(content: Text('Saved $saved cards to gallery')));
        }
      case _Mode.share:
        if (files.isNotEmpty) await Share.shareXFiles(files);
      case _Mode.collageGallery:
      case _Mode.collageShare:
        if (pngs.isEmpty) return;
        final picture = await AlbumExporter.collage(pngs);
        if (mode == _Mode.collageGallery) {
          await CardExporter.saveToGallery(picture);
          messenger.showSnackBar(const SnackBar(content: Text('Collage saved to gallery')));
        } else {
          await CardExporter.share(picture, '${_safe(name)}_collage');
        }
    }
  } catch (e) {
    closeDialog();
    messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}
