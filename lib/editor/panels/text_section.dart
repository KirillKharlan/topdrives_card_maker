import 'package:flutter/material.dart';

import '../editor_controller.dart';
import 'section_card.dart';

/// Top speed field (miles per hour on the card) with a button under it: if the number
/// typed in is in km/h, the button turns it into mph right in the field. Right after a
/// conversion the same button undoes it, so a second tap does not convert twice.
class _TopSpeedField extends StatefulWidget {
  const _TopSpeedField({required this.value, required this.onChanged});

  /// The card's top speed (mph).
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_TopSpeedField> createState() => _TopSpeedFieldState();
}

class _TopSpeedFieldState extends State<_TopSpeedField> {
  static const _mphPerKmh = 0.621371;

  late final TextEditingController _text = TextEditingController(text: widget.value);

  /// The km/h text that was in the field before the last conversion (null: not converted).
  String? _undoTo;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  static double? _number(String raw) => double.tryParse(raw.trim().replaceAll(',', '.'));

  bool get _canPress => _undoTo != null || _number(_text.text) != null;

  void _set(String value) {
    _text.text = value;
    _text.selection = TextSelection.collapsed(offset: value.length);
    widget.onChanged(value);
  }

  void _convertOrUndo() {
    final back = _undoTo;
    if (back != null) {
      setState(() => _undoTo = null);
      _set(back);
      return;
    }
    final kmh = _number(_text.text);
    if (kmh == null) return;
    final before = _text.text.trim();
    setState(() => _undoTo = before);
    _set((kmh * _mphPerKmh).round().toString());
  }

  @override
  Widget build(BuildContext context) {
    final undo = _undoTo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _text,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Top speed',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) {
            if (_undoTo != null) setState(() => _undoTo = null);
            widget.onChanged(v);
          },
        ),
        TextButton.icon(
          onPressed: _canPress ? _convertOrUndo : null,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: Icon(undo == null ? Icons.swap_horiz : Icons.undo, size: 18),
          label: Text(undo == null ? 'km/h \u2192 mph' : 'Undo ($undo)'),
        ),
      ],
    );
  }
}

/// Text and number fields of the card.
class TextSection extends StatelessWidget {
  const TextSection({super.key, required this.controller});

  final EditorController controller;

  Widget _field(
    String label,
    String value,
    void Function(String) onChanged, {
    TextInputType? keyboard,
    String? helper,
  }) {
    return TextFormField(
      initialValue: value,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }

  Widget _row(List<Widget> fields) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: fields[i]),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.project;
    const number = TextInputType.number;
    const decimal = TextInputType.numberWithOptions(decimal: true);
    return SectionCard(
      title: 'Car data',
      children: [
        _row([_field('Card name (in the app)', p.name, (v) => c.update((x) => x.name = v))]),
        _row([
          _field('Brand', p.brand, (v) => c.update((x) => x.brand = v)),
          _field('Model', p.model, (v) => c.update((x) => x.model = v)),
        ]),
        _row([
          _field('Year', p.year, (v) => c.update((x) => x.year = v), keyboard: number),
          _field('RQ', p.rq, (v) => c.update((x) => x.rq = v), keyboard: number),
        ]),
        _row([
          _TopSpeedField(
            value: p.topSpeed,
            onChanged: (v) => c.update((x) => x.topSpeed = v),
          ),
          _field(
            '0-60',
            p.accel,
            (v) => c.update((x) => x.accel = v),
            keyboard: decimal,
            helper: p.accelIsNotApplicable ? 'Shown as N/A (top speed is below 60)' : null,
          ),
          _field(c.template.fieldLabels['handling'] ?? 'Handling', p.handling,
              (v) => c.update((x) => x.handling = v),
              keyboard: number),
        ]),
        // Only some templates have a place for the weight.
        if (c.template.hasField('weight'))
          _row([
            _field('Weight', p.weight, (v) => c.update((x) => x.weight = v), keyboard: number),
          ]),
      ],
    );
  }
}
