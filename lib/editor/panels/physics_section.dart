import 'package:flutter/material.dart';

import '../../data/models/car_physics.dart';
import '../editor_controller.dart';

/// The hidden numbers the game uses to simulate a race (power, mass, drag, tyres ...),
/// typed in by hand. Closed by default. Ground clearance, traction control, ABS and the
/// tyre type are picked from a list, everything else is a plain text field. They do not
/// depend on the numbers on the card and are put into the exported ZIP together with the
/// card's picture.
class PhysicsSection extends StatelessWidget {
  const PhysicsSection({super.key, required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.project;
    const fields = CarPhysics.fields;

    InputDecoration decoration(PhysicsField f) => InputDecoration(
          labelText: f.label,
          helperText: f.help,
          border: const OutlineInputBorder(),
          isDense: true,
        );

    Widget textField(PhysicsField f) => TextFormField(
          key: ValueKey('${p.id}-${f.key}'),
          initialValue: p.physics[f.key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: decoration(f),
          onChanged: (v) => c.update((x) => x.physics.set(f.key, v)),
        );

    // A list to pick from. Yes / No store 'true' / 'false'. A value that is not in the list
    // (typed in an older version) is added to it, so nothing is lost.
    Widget dropdown(PhysicsField f) {
      final stored = p.physics[f.key];
      final isFlag = f.kind == PhysicsKind.flag;
      final current = isFlag ? CarPhysics.flagValue(stored) : stored;
      final entries = <String, String>{
        '': 'Not set',
        if (isFlag) ...{'true': 'Yes', 'false': 'No'} else for (final o in f.options) o: o,
        if (!isFlag && current.isNotEmpty && !f.options.contains(current)) current: current,
      };
      return DropdownButtonFormField<String>(
        key: ValueKey('${p.id}-${f.key}-$current'),
        value: current,
        isExpanded: true,
        decoration: decoration(f),
        items: [
          for (final e in entries.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) => c.update((x) => x.physics.set(f.key, v ?? '')),
      );
    }

    Widget field(PhysicsField f) =>
        f.kind == PhysicsKind.number ? textField(f) : dropdown(f);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        // Not a PageStorageKey: the text fields inside would read the tile's saved state
        // (a bool) as their scroll position and fail, which showed up as grey boxes.
        key: const ValueKey('physics-section'),
        title: Text('Physics (hidden stats)', style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(
          p.physics.isEmpty
              ? 'For fan builds of the game'
              : '${p.physics.filled} of ${fields.length} filled in',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Typed in by hand, independent of the numbers on the card. Saved with the card '
            'and put into the exported ZIP. Ground clearance, traction control, ABS and the '
            'tyre type are chosen from a list, the other fields are typed '
            '(numbers become numbers in the ZIP).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < fields.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: field(fields[i])),
                  const SizedBox(width: 8),
                  Expanded(
                    child: i + 1 < fields.length ? field(fields[i + 1]) : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
