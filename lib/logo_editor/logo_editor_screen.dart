import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'background_remover.dart';
import 'checkerboard.dart';
import 'rgba_image.dart';

/// One step of the editing history. Replaying the list with the current
/// tolerance makes the sliders affect everything done so far.
class _Op {
  const _Op.edges()
      : x = null,
        y = null;
  const _Op.tap(this.x, this.y);

  final int? x;
  final int? y;

  bool get isEdges => x == null;
}

/// Background removal for a logo. Pops a PNG ([Uint8List]) when saved.
class LogoEditorScreen extends StatefulWidget {
  const LogoEditorScreen({super.key, required this.file});

  final File file;

  @override
  State<LogoEditorScreen> createState() => _LogoEditorScreenState();
}

class _LogoEditorScreenState extends State<LogoEditorScreen> {
  BackgroundRemover? _remover;
  ui.Image? _preview;
  List<_Op> _ops = [const _Op.edges()];
  double _tolerance = 40;
  double _edge = 1;
  bool _contiguous = true;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _preview?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.file.readAsBytes();
      final image = await RgbaImage.decode(bytes);
      _remover = BackgroundRemover(image);
      await _recompute();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not open this image.';
          _busy = false;
        });
      }
    }
  }

  Future<void> _recompute() async {
    final remover = _remover!;
    remover.reset();
    final tolerance = _tolerance.round();
    for (final op in _ops) {
      if (op.isEdges) {
        remover.removeFromEdges(tolerance);
      } else {
        remover.removeAt(op.x!, op.y!, tolerance, contiguous: _contiguous);
      }
    }
    final preview = await remover.compose(edge: _edge.round(), trim: false).toUiImage();
    if (!mounted) {
      preview.dispose();
      return;
    }
    setState(() {
      _preview?.dispose();
      _preview = preview;
      _busy = false;
    });
  }

  void _changeOps(List<_Op> ops) {
    setState(() {
      _ops = ops;
      _busy = true;
    });
    _recompute();
  }

  void _onTap(TapDownDetails details, Size box) {
    final remover = _remover;
    if (remover == null || _busy) return;
    final w = remover.source.width.toDouble();
    final h = remover.source.height.toDouble();
    final scale = min(box.width / w, box.height / h);
    final dx = (box.width - w * scale) / 2;
    final dy = (box.height - h * scale) / 2;
    final x = ((details.localPosition.dx - dx) / scale).floor();
    final y = ((details.localPosition.dy - dy) / scale).floor();
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    _changeOps([..._ops, _Op.tap(x, y)]);
  }

  Future<void> _save() async {
    final remover = _remover;
    if (remover == null) return;
    setState(() => _busy = true);
    final png = await remover.compose(edge: _edge.round(), trim: true).toPng();
    if (!mounted) return;
    Navigator.pop<Uint8List>(context, png);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remove background'),
        actions: [
          TextButton(
            onPressed: (_busy || _remover == null) ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : Column(
              children: [
                Expanded(child: _canvas()),
                _controls(),
              ],
            ),
    );
  }

  Widget _canvas() {
    return LayoutBuilder(builder: (context, constraints) {
      final box = Size(constraints.maxWidth, constraints.maxHeight);
      return GestureDetector(
        onTapDown: (d) => _onTap(d, box),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: CheckerboardPainter()),
            if (_preview != null) RawImage(image: _preview, fit: BoxFit.contain),
            if (_busy) const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    });
  }

  Widget _controls() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tap a colour on the picture to remove it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Row(
              children: [
                SizedBox(width: 92, child: Text('Tolerance ${_tolerance.round()}')),
                Expanded(
                  child: Slider(
                    value: _tolerance,
                    min: 5,
                    max: 150,
                    onChanged: (v) => setState(() => _tolerance = v),
                    onChangeEnd: (_) => _changeOps(_ops),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                SizedBox(width: 92, child: Text('Edge ${_edge.round()}')),
                Expanded(
                  child: Slider(
                    value: _edge,
                    min: 0,
                    max: 3,
                    divisions: 3,
                    onChanged: (v) => setState(() => _edge = v),
                    onChangeEnd: (_) => _changeOps(_ops),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Only connected area'),
              subtitle: const Text('Off: remove this colour everywhere'),
              value: _contiguous,
              onChanged: (v) {
                _contiguous = v;
                _changeOps(_ops);
              },
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _changeOps([..._ops, const _Op.edges()]),
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Auto'),
                ),
                OutlinedButton.icon(
                  onPressed: (_busy || _ops.isEmpty) ? null : () => _changeOps(_ops.sublist(0, _ops.length - 1)),
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _changeOps(const []),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
