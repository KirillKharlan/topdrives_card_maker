import 'package:flutter/material.dart';

import '../editor_controller.dart';
import 'section_card.dart';

/// Text and number fields of the card.
class TextSection extends StatelessWidget {
  const TextSection({super.key, required this.controller});

  final EditorController controller;

  Widget _field(
    String label,
    String value,
    void Function(String) onChanged, {
    TextInputType? keyboard,
  }) {
    return TextFormField(
      initialValue: value,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
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
          _field('Top speed', p.topSpeed, (v) => c.update((x) => x.topSpeed = v),
              keyboard: number),
          _field('0-60', p.accel, (v) => c.update((x) => x.accel = v), keyboard: decimal),
          _field('Handling', p.handling, (v) => c.update((x) => x.handling = v),
              keyboard: number),
        ]),
      ],
    );
  }
}
