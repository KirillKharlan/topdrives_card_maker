import 'package:flutter/material.dart';

import '../../core/app_constants.dart';
import '../../data/country_flags.dart';
import '../../data/models/card_style.dart';
import '../../ui/common/dialogs.dart';
import '../editor_controller.dart';
import 'section_card.dart';

/// Pick-one options: style, class, drive, tyres, country.
class OptionsSection extends StatelessWidget {
  const OptionsSection({super.key, required this.controller});

  final EditorController controller;

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

  /// Asks for a short text; returns it, or null when cancelled.
  Future<String?> _askText(
    BuildContext context, {
    required String title,
    required String hint,
    required int maxLength,
    String? helper,
    TextCapitalization capitalization = TextCapitalization.none,
  }) async {
    final input = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLength: maxLength,
          textCapitalization: capitalization,
          decoration: InputDecoration(hintText: hint, helperText: helper, helperMaxLines: 3),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, input.text), child: const Text('Add')),
        ],
      ),
    );
    input.dispose();
    return text;
  }

  Future<void> _addDrive(BuildContext context) async {
    final text = await _askText(
      context,
      title: 'Custom drive',
      hint: 'e.g. AWD',
      maxLength: 4,
      helper: 'The card shows only the first letter, the frame already has \"WD\" after it.',
      capitalization: TextCapitalization.characters,
    );
    if (text == null) return;
    final value = await controller.store.settings.addDrive(text);
    if (value != null) controller.update((p) => p.drive = value);
  }

  Future<void> _addTyre(BuildContext context) async {
    final text = await _askText(
      context,
      title: 'Custom tyres',
      hint: 'e.g. Rally',
      maxLength: 14,
      helper: 'Shown in capitals before the word \"Tyres\" of the frame.',
      capitalization: TextCapitalization.words,
    );
    if (text == null) return;
    final value = await controller.store.settings.addTyre(text);
    if (value != null) controller.update((p) => p.tyre = value);
  }

  Future<void> _removeCustom(
    BuildContext context,
    String value,
    Future<void> Function(String) remove,
  ) async {
    final ok = await confirmDialog(
      context,
      title: 'Remove \"$value\"?',
      message: 'It will be removed from the list. Cards that use it keep their text.',
      action: 'Remove',
    );
    if (ok) await remove(value);
  }

  /// Built-in values, the user's own ones (long-press to remove) and a Custom button.
  Widget _customChips(
    BuildContext context, {
    required List<String> builtIn,
    required List<String> custom,
    required String selected,
    required void Function(String) onSelect,
    required VoidCallback onAdd,
    required Future<void> Function(String) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final v in builtIn)
              ChoiceChip(
                label: Text(v),
                selected: v == selected,
                onSelected: (_) => onSelect(v == selected ? '' : v),
              ),
            for (final v in custom)
              GestureDetector(
                onLongPress: () => _removeCustom(context, v, onRemove),
                child: ChoiceChip(
                  label: Text(v),
                  selected: v == selected,
                  onSelected: (_) => onSelect(v == selected ? '' : v),
                ),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Custom'),
              onPressed: onAdd,
            ),
          ],
        ),
        if (custom.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Long-press a custom value to remove it.', style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
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
          title: 'Style',
          children: [
            if (c.store.templates.length > 1) ...[
              const Text('Template'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final t in c.store.templates.values)
                    ChoiceChip(
                      label: Text(t.name),
                      selected: t.id == p.templateId,
                      onSelected: (_) => c.setTemplate(t.id == p.templateId ? '' : t.id),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Text('Text sizes'),
              const SizedBox(height: 4),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final style in CardStyle.values)
                  ChoiceChip(
                    label: Text(style.label),
                    selected: style == p.cardStyle,
                    onSelected: (_) => c.setCardStyle(style),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(p.cardStyle.hint, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
        SectionCard(
          title: 'Class',
          // Tapping the chosen class again clears it, like the template chips.
          children: [
            // The classes the chosen template has a frame for (the beta template has five),
            // tinted with the colour of the class when the template gives one.
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final v in c.template.classes)
                  ChoiceChip(
                    avatar: c.template.classColors[v] == null
                        ? null
                        : CircleAvatar(backgroundColor: c.template.classColors[v], radius: 7),
                    label: Text(v),
                    selected: v == p.carClass,
                    onSelected: (_) => c.update((x) => x.carClass = x.carClass == v ? '' : v),
                  ),
              ],
            ),
          ],
        ),
        SectionCard(
          title: 'Drive',
          children: [
            ListenableBuilder(
              listenable: c.store.settings,
              builder: (context, _) => _customChips(
                context,
                builtIn: AppConstants.drives,
                custom: c.store.settings.customDrives,
                selected: p.drive,
                onSelect: (v) => c.update((x) => x.drive = v),
                onAdd: () => _addDrive(context),
                onRemove: c.store.settings.removeDrive,
              ),
            ),
          ],
        ),
        if (c.template.hasField('tyre'))
          SectionCard(
          title: 'Tyres',
          children: [
            ListenableBuilder(
              listenable: c.store.settings,
              builder: (context, _) => _customChips(
                context,
                builtIn: AppConstants.tyres,
                custom: c.store.settings.customTyres,
                selected: p.tyre,
                onSelect: (v) => c.update((x) => x.tyre = v),
                onAdd: () => _addTyre(context),
                onRemove: c.store.settings.removeTyre,
              ),
            ),
          ],
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
                        onSelected: (_) => c.update((x) => x.country = code == p.country ? '' : code),
                      ),
                    for (final code in custom)
                      GestureDetector(
                        onLongPress: () => _removeCountry(context, code),
                        child: ChoiceChip(
                          label: Text(code),
                          selected: code == p.country,
                          onSelected: (_) => c.update((x) => x.country = code == p.country ? '' : code),
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Flag behind the code'),
              subtitle: Text(
                p.country.isEmpty
                    ? 'Choose a country first.'
                    : CountryFlags.has(p.country)
                        ? 'Shows the flag of ${p.country} in the country block.'
                        : 'No flag for ${p.country}.',
              ),
              value: p.showFlag,
              onChanged: (v) => c.update((x) => x.showFlag = v),
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
