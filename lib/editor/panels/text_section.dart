import 'package:flutter/material.dart';

import '../editor_controller.dart';
import 'section_card.dart';

/// Top speed field. The card shows miles per hour; tap the unit inside the field to
/// switch it to km/h: the number is then typed in km/h and the card gets it converted.
class _TopSpeedField extends StatefulWidget {
  const _TopSpeedField({required this.value, required this.onChanged});

  /// The card's top speed (always mph).
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_TopSpeedField> createState() => _TopSpeedFieldState();
}

class _TopSpeedFieldState extends State<_TopSpeedField> {
  static const _mphPerKmh = 0.621371;

  late final TextEditingController _text = TextEditingController(text: widget.value);
  bool _kmh = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  static double? _number(String raw) => double.tryParse(raw.trim().replaceAll(',', '.'));

  /// km/h text -> whole mph, or '' when it is not a number.
  static String _toMph(String raw) {
    final kmh = _number(raw);
    return kmh == null ? '' : (kmh * _mphPerKmh).round().toString();
  }

  void _changed(String raw) => widget.onChanged(_kmh ? _toMph(raw) : raw);

  void _toggleUnit() {
    setState(() {
      _kmh = !_kmh;
      if (_kmh) {
        // Same speed, shown in km/h; the card keeps its value until the number is edited.
        final mph = _number(widget.value);
        _text.text = mph == null ? '' : (mph / _mphPerKmh).round().toString();
      } else {
        _text.text = widget.value;
      }
      _text.selection = TextSelection.collapsed(offset: _text.text.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return TextField(
      controller: _text,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Top speed',
        helperText: _kmh ? '= ${widget.value.isEmpty ? '?' : widget.value} mph on the card' : null,
        helperMaxLines: 2,
        border: const OutlineInputBorder(),
        isDense: true,
        suffix: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleUnit,
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              _kmh ? 'km/h \u21C4' : 'mph \u21C4',
              style: style?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ),
      ),
      onChanged: _changed,
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
          _field('Handling', p.handling, (v) => c.update((x) => x.handling = v),
              keyboard: number),
        ]),
      ],
    );
  }
}
