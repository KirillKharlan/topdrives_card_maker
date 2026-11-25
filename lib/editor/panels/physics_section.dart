import 'package:flutter/material.dart';

import '../../data/models/car_physics.dart';
import '../editor_controller.dart';

/// The hidden numbers the game uses to simulate a race (power, mass, drag, tyres ...),
/// typed in by hand. Closed by default. They do not depend on the numbers on the card
/// and are put into the exported ZIP together with the card's picture.
class PhysicsSection extends StatelessWidget {
  const PhysicsSection({super.key, required this.controller});

  final EditorController controller;

  InputDecoration _decoration(PhysicsField f) => InputDecoration(
        labelText: f.label,
        helperText: f.help,
        border: const OutlineInputBorder(),
        isDense: true,
      );

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.project;
    final numbers = [for (final f in CarPhysics.fields) if (f.kind == PhysicsKind.number) f];
    final flags = [for (final f in CarPhysics.fields) if (f.kind == PhysicsKind.flag) f];
    final tyre = CarPhysics.fields.firstWhere((f) => f.kind == PhysicsKind.tyre);

    Widget numberField(PhysicsField f) => TextFormField(
          key: ValueKey('${p.id}-${f.key}'),
          initialValue: p.physics[f.key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: _decoration(f),
          onChanged: (v) => c.update((x) => x.physics.set(f.key, v)),
        );

    Widget flagField(PhysicsField f) => DropdownButtonFormField<String>(
          key: ValueKey('${p.id}-${f.key}-${p.physics[f.key]}'),
          value: p.physics[f.key],
          decoration: _decoration(f),
          items: const [
            DropdownMenuItem(value: '', child: Text('Not set')),
            DropdownMenuItem(value: 'true', child: Text('Yes')),
            DropdownMenuItem(value: 'false', child: Text('No')),
          ],
          onChanged: (v) => c.update((x) => x.physics.set(f.key, v ?? '')),
        );

    Widget row(List<Widget> fields) => Padding(
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

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const PageStorageKey('physics-section'),
        title: Text('Physics (hidden stats)', style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(
          p.physics.isEmpty
              ? 'For fan builds of the game'
              : '${p.physics.filled} of ${CarPhysics.fields.length} filled in',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Typed in by hand, independent of the numbers on the card. Saved with the card '
            'and put into the exported ZIP.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < numbers.length; i += 2)
            row([
              numberField(numbers[i]),
              if (i + 1 < numbers.length) numberField(numbers[i + 1]),
            ]),
          row([for (final f in flags) flagField(f)]),
          row([
            DropdownButtonFormField<String>(
              key: ValueKey('${p.id}-${tyre.key}-${p.physics[tyre.key]}'),
              value: p.physics[tyre.key],
              decoration: _decoration(tyre),
              items: [
                const DropdownMenuItem(value: '', child: Text('Not set')),
                for (final t in CarPhysics.tyreTypes) DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) => c.update((x) => x.physics.set(tyre.key, v ?? '')),
            ),
          ]),
        ],
      ),
    );
  }
}
