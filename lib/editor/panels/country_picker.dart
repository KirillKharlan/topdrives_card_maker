import 'package:flutter/material.dart';

import '../../data/iso_countries.dart';
import '../../ui/common/country_flag_thumb.dart';
import '../../ui/common/search_field.dart';

/// Bottom sheet with every country: search by name or code, one compact row
/// per country. Returns the chosen code (a typed 2-3 letter code that is not
/// in the list is returned too), or null when closed.
Future<String?> showCountryPicker(BuildContext context, {required String selected}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CountryPickerSheet(selected: selected.toUpperCase()),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.selected});

  final String selected;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final results = IsoCountries.search(_query);
    final typed = _query.trim().toUpperCase();
    final canUseTyped = results.isEmpty && RegExp(r'^[A-Z0-9]{2,3}$').hasMatch(typed);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Choose country', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Text('${results.length}', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            SearchField(
              controller: _controller,
              hint: 'Search by name or code',
              onChanged: (v) => setState(() => _query = v),
            ),
            Expanded(
              child: canUseTyped
                  ? ListTile(
                      leading: const Icon(Icons.add),
                      title: Text('Use "$typed" as a custom code'),
                      onTap: () => Navigator.pop(context, typed),
                    )
                  : results.isEmpty
                      ? const Center(child: Text('Nothing found.'))
                      : ListView.builder(
                          itemExtent: 44,
                          itemCount: results.length,
                          itemBuilder: (_, i) => _row(context, results[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IsoCountry country) {
    final scheme = Theme.of(context).colorScheme;
    final selected = country.code == widget.selected;
    return InkWell(
      onTap: () => Navigator.pop(context, country.code),
      child: Container(
        color: selected ? scheme.primaryContainer : null,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            CountryFlagThumb(code: country.code, width: 30, height: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(country.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(country.code, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (selected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
