import 'package:flutter/material.dart';

import '../editor_controller.dart';
import 'section_card.dart';

/// Per-card size of the brand/model line, the year and the tags (1.0 = template size).
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
        _slider('Brand + model', p.titleScale, c.setTitleScale),
        _slider('Year', p.yearScale, c.setYearScale),
        _slider('Tags', p.tagScale, c.setTagScale),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              c.setTitleScale(1.0);
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
