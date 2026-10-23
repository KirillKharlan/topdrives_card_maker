import 'package:flutter/material.dart';

import '../../core/app_constants.dart';
import '../../ui/common/dialogs.dart';
import '../editor_controller.dart';
import 'section_card.dart';

/// Pick-one options: class, drive, tyres, country.
class OptionsSection extends StatelessWidget {
  const OptionsSection({super.key, required this.controller});

  final EditorController controller;

  Widget _chips(List<String> values, String selected, void Function(String) onSelect) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final v in values)
          ChoiceChip(label: Text(v), selected: v == selected, onSelected: (_) => onSelect(v)),
      ],
    );
  }

  Future<void> _addCountry(BuildContext context) async {
    final input = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Custom country code'),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLength: 3,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'e.g. PL'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, input.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    input.dispose();
    if (code == null) return;
    await controller.store.settings.addCountry(code);
    final normalized = code.trim().toUpperCase();
    if (normalized.isNotEmpty) controller.update((p) => p.country = normalized);
  }

  Future<void> _removeCountry(BuildContext context, String code) async {
    final ok = await confirmDialog(
      context,
      title: 'Remove "$code"?',
      message: 'The custom country code will be removed from the list.',
      action: 'Remove',
    );
    if (ok) await controller.store.settings.removeCountry(code);
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.project;
    return Column(
      children: [
        SectionCard(
          title: 'Class',
          children: [_chips(AppConstants.carClasses, p.carClass, (v) => c.update((x) => x.carClass = v))],
        ),
        SectionCard(
          title: 'Drive',
          children: [_chips(AppConstants.drives, p.drive, (v) => c.update((x) => x.drive = v))],
        ),
        SectionCard(
          title: ' ',
          children: [_chips(AppConstants.tyres, p.tyre, (v) => c.update((x) => x.tyre = v))],
        ),
        SectionCard(
          title: 'Country',
          children: [
            ListenableBuilder(
              listenable: c.store.settings,
              builder: (context, _) {
                final custom = c.store.settings.customCountries;
                return Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final code in AppConstants.builtInCountries)
                      ChoiceChip(
                        label: Text(code),
                        selected: code == p.country,
                        onSelected: (_) => c.update((x) => x.country = code),
                      ),
                    for (final code in custom)
                      GestureDetector(
                        onLongPress: () => _removeCountry(context, code),
                        child: ChoiceChip(
                          label: Text(code),
                          selected: code == p.country,
                          onSelected: (_) => c.update((x) => x.country = code),
                        ),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('Custom'),
                      onPressed: () => _addCountry(context),
                    ),
                  ],
                );
              },
            ),
            if (c.store.settings.customCountries.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Long-press a custom code to remove it.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
