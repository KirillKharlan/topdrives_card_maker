import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../video/video_exporter.dart';
import '../editor_controller.dart';
import 'card_exporter.dart';

/// Export options. By default the tags (above) and the prize marker (below)
/// are included, so the saved picture looks like the editor preview. The
/// cropped car photo can also be saved on its own.
Future<void> showExportSheet(BuildContext context, EditorController c) {
  final hasExtras = c.project.prize || c.project.tags.isNotEmpty;
  final hasPhoto = c.photoFile != null;
  var includeExtras = true;
  var videoFps = 30;
  var gifFps = 20;
  var gifScale = 1.0;

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

        // MP4 or GIF of the video card: every frame is rendered through the live card.
        Future<void> deliverVideo({required bool gif, required bool share}) async {
          Navigator.pop(sheetContext);
          final messenger = ScaffoldMessenger.of(context);
          final progress = ValueNotifier<double>(0);
          final cancel = ValueNotifier<bool>(false);
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: Text(gif ? 'Rendering GIF' : 'Rendering video'),
              content: ValueListenableBuilder<double>(
                valueListenable: progress,
                builder: (_, value, __) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: value),
                    const SizedBox(height: 8),
                    Text('${(value * 100).round()}%'),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => cancel.value = true, child: const Text('Cancel')),
              ],
            ),
          );
          File? file;
          Object? failure;
          try {
            final key = (hasExtras && includeExtras) ? c.fullKey : c.cardKey;
            file = gif
                ? await VideoExporter.exportGif(
                    context: context,
                    controller: c,
                    key: key,
                    fps: gifFps,
                    scale: gifScale,
                    progress: progress,
                    cancel: cancel,
                  )
                : await VideoExporter.exportMp4(
                    context: context,
                    controller: c,
                    key: key,
                    fps: videoFps,
                    progress: progress,
                    cancel: cancel,
                  );
          } on VideoExportCancelled {
            failure = null;
          } catch (e) {
            failure = e;
          }
          if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
          if (failure != null) {
            messenger.showSnackBar(SnackBar(content: Text('Video export failed: $failure')));
            return;
          }
          if (file == null) return;
          try {
            if (share) {
              final safe = c.project.name.replaceAll(RegExp(r'[^\w\-]+'), '_');
              await CardExporter.shareFile(file, safe.isEmpty ? 'card' : safe);
            } else {
              if (gif) {
                await CardExporter.saveImageFileToGallery(file);
              } else {
                await CardExporter.saveVideoToGallery(file);
              }
              messenger.showSnackBar(
                SnackBar(content: Text(gif ? 'GIF saved to gallery' : 'Video saved to gallery')),
              );
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
                if (c.project.hasVideo) ...[
                  ListTile(
                    leading: const Icon(Icons.movie_outlined),
                    title: const Text('Save video (MP4) to gallery'),
                    subtitle: Text(
                      '${(c.project.videoLengthMs / 1000).toStringAsFixed(1)} s, '
                      '${VideoExporter.frameCount(c, videoFps)} frames, full card size',
                    ),
                    onTap: () => deliverVideo(gif: false, share: false),
                  ),
                  ListTile(
                    leading: const Icon(Icons.ios_share),
                    title: const Text('Share video (MP4)'),
                    onTap: () => deliverVideo(gif: false, share: true),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text('Frames per second'),
                        const SizedBox(width: 12),
                        for (final fps in const [24, 30])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('$fps'),
                              selected: videoFps == fps,
                              onSelected: (_) => setSheetState(() => videoFps = fps),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.gif_box_outlined),
                    title: const Text('Save GIF to gallery'),
                    subtitle: Text(
                      '${VideoExporter.frameCount(c, gifFps)} frames, '
                      'about ${VideoExporter.gifMegabytes(c, gifFps, gifScale).round()} MB',
                    ),
                    onTap: () => deliverVideo(gif: true, share: false),
                  ),
                  ListTile(
                    leading: const Icon(Icons.ios_share),
                    title: const Text('Share GIF'),
                    onTap: () => deliverVideo(gif: true, share: true),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        const Text('GIF frames per second'),
                        for (final fps in const [10, 20, 25])
                          ChoiceChip(
                            label: Text('$fps'),
                            selected: gifFps == fps,
                            onSelected: (_) => setSheetState(() => gifFps = fps),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        const Text('GIF size'),
                        for (final entry in const {'Full': 1.0, '75%': 0.75, '50%': 0.5}.entries)
                          ChoiceChip(
                            label: Text(entry.key),
                            selected: gifScale == entry.value,
                            onSelected: (_) => setSheetState(() => gifScale = entry.value),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
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
