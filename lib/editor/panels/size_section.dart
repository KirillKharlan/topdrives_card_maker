import 'package:flutter/material.dart';

import '../editor_controller.dart';
import 'section_card.dart';

/// Per-card size of the brand, the model, the year and the tags (1.0 = template size).
class SizeSection extends StatelessWidget {
  const SizeSection({super.key, required this.controller});

  final EditorController controller;

  Widget _slider(String label, double value, void Function(double) onChanged) {
    return Row(
      children: [
        SizedBox(width: 118, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(0.6, 1.6).toDouble(),
            min: 0.6,
            max: 1.6,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 40, child: Text('x${value.toStringAsFixed(2)}')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.project;
    return SectionCard(
      title: 'Sizes',
      children: [
        _slider('Brand', p.brandScale, c.setBrandScale),
        _slider('Model (max)', p.modelScale, c.setModelScale),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            'The brand always keeps this size. The model is never larger than its size, '
            'a long model gets smaller to fit.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        _slider('Year', p.yearScale, c.setYearScale),
        _slider('Tags', p.tagScale, c.setTagScale),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              c.setBrandScale(1.0);
              c.setModelScale(1.0);
              c.setYearScale(1.0);
              c.setTagScale(1.0);
            },
            child: const Text('Reset sizes'),
          ),
        ),
      ],
    );
  }
}
