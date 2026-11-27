import 'package:flutter/material.dart';

import '../../data/repositories/settings_repository.dart';
import '../../photo_fill/lama_model.dart';
import '../../ui/common/dialogs.dart';

/// Choose how the empty areas around a photo are filled: the fast built-in method, or the
/// LaMa neural network (its model, 208 MB, is downloaded once).
class FillEngineRow extends StatefulWidget {
  const FillEngineRow({super.key, required this.settings});

  final SettingsRepository settings;

  @override
  State<FillEngineRow> createState() => _FillEngineRowState();
}

class _FillEngineRowState extends State<FillEngineRow> {
  bool? _ready; // null while it is being checked

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final ready = await LamaModel.isReady();
    if (mounted) setState(() => _ready = ready);
  }

  Future<void> _download() async {
    final ok = await confirmDialog(
      context,
      title: 'Download the LaMa model?',
      message: 'The file is 208 MB (it may use mobile data, Wi-Fi is better). It is saved on the '
          'phone once, after that the fill works offline.',
      action: 'Download',
    );
    if (!ok || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final token = LamaDownloadToken();
    final progress = ValueNotifier<double?>(0);
    var dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Downloading the LaMa model'),
        content: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (_, value, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: value),
              const SizedBox(height: 12),
              Text(value == null ? 'Please wait…' : '${(value * 100).clamp(0, 100).round()} %'),
            ],
          ),
        ),
        actions: [TextButton(onPressed: token.cancel, child: const Text('Cancel'))],
      ),
    ).whenComplete(() => dialogOpen = false);

    void closeDialog() {
      if (dialogOpen) navigator.pop();
    }

    try {
      await LamaModel.download(onProgress: (f) => progress.value = f, token: token);
      closeDialog();
      messenger.showSnackBar(const SnackBar(content: Text('The LaMa model is ready.')));
    } catch (e) {
      closeDialog();
      messenger.showSnackBar(
        SnackBar(content: Text(token.cancelled ? 'Download cancelled.' : 'Download failed: $e')),
      );
    }
    await _refresh();
  }

  Future<void> _remove() async {
    final ok = await confirmDialog(
      context,
      title: 'Remove the LaMa model?',
      message: 'This frees 208 MB. You can download it again later.',
      action: 'Remove',
    );
    if (!ok) return;
    await LamaModel.delete();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        final lama = widget.settings.fillEngine == 'lama';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fill method:', style: small),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Fast (offline)'),
                  selected: !lama,
                  onSelected: (_) => widget.settings.setFillEngine('patchmatch'),
                ),
                ChoiceChip(
                  label: const Text('LaMa (neural network)'),
                  selected: lama,
                  onSelected: (_) => widget.settings.setFillEngine('lama'),
                ),
              ],
            ),
            if (lama) ...[
              const SizedBox(height: 4),
              if (_ready == false)
                Row(
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _download,
                      icon: const Icon(Icons.download),
                      label: const Text('Download model (208 MB)'),
                    ),
                  ],
                )
              else if (_ready == true)
                Row(
                  children: [
                    Expanded(child: Text('The LaMa model is on the phone.', style: small)),
                    TextButton(onPressed: _remove, child: const Text('Remove')),
                  ],
                ),
              Text(
                'LaMa draws the missing background with a neural network: better for trees, sky '
                'and road, slower than the fast method, and it needs about 1 GB of free memory. '
                'It works at 512 px, so the new part is a little softer than the photo.',
                style: small,
              ),
            ],
          ],
        );
      },
    );
  }
}
