import 'package:flutter/material.dart';

import '../../data/models/card_tag.dart';
import '../canvas/custom_tag_view.dart';

/// Tag constructor: type a title and pick the border colour; the fill is the
/// same colour, darkened, and the tag width follows the text. Returns the new
/// (or edited) tag, or null if cancelled.
Future<CardTag?> showTagEditor(BuildContext context, {CardTag? initial}) {
  return showModalBottomSheet<CardTag>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TagEditor(initial: initial),
  );
}

class _TagEditor extends StatefulWidget {
  const _TagEditor({this.initial});

  final CardTag? initial;

  @override
  State<_TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<_TagEditor> {
  static const _presets = <int>[
    0xFFF2C21B, // yellow
    0xFFFF8A1F, // orange
    0xFFF24A30, // red-orange
    0xFFDA2525, // red
    0xFFC20A4B, // crimson
    0xFFF26788, // pink
    0xFF8E44FF, // purple
    0xFF1E3AD3, // blue
    0xFF3AA9FF, // light blue
    0xFF1FB8A6, // teal
    0xFF3AA930, // green
    0xFFBFBFBF, // grey
  ];

  late final TextEditingController _text =
      TextEditingController(text: widget.initial?.text ?? '');
  late int _color = widget.initial?.colorValue ?? _presets.first;
  late final TextEditingController _hex = TextEditingController(text: _hexOf(_color));

  static String _hexOf(int argb) =>
      (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  @override
  void dispose() {
    _text.dispose();
    _hex.dispose();
    super.dispose();
  }

  void _setColor(int argb) {
    setState(() {
      _color = argb | 0xFF000000;
      _hex.text = _hexOf(_color);
    });
  }

  void _onHex(String value) {
    if (value.length != 6) return;
    final parsed = int.tryParse(value, radix: 16);
    if (parsed != null) setState(() => _color = 0xFF000000 | parsed);
  }

  @override
  Widget build(BuildContext context) {
    final title = _text.text.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Custom tag', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: const Color(0xFF1E1E1E),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: CustomTagView(
                      text: title.isEmpty ? 'Your tag' : title,
                      colorValue: _color,
                      height: 50,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                autofocus: true,
                maxLength: 32,
                decoration: const InputDecoration(
                  labelText: 'Tag text',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 4),
              Text('Border colour', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final preset in _presets)
                    GestureDetector(
                      onTap: () => _setColor(preset),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(preset),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: preset == _color ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _hex,
                maxLength: 6,
                decoration: const InputDecoration(
                  prefixText: '#',
                  labelText: 'Hex colour (RRGGBB)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _onHex,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: title.isEmpty
                        ? null
                        : () => Navigator.pop(
                              context,
                              CardTag(text: title, colorValue: _color),
                            ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
