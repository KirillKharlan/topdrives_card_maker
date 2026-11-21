import 'package:flutter/material.dart';

import '../../data/beta_cards.dart';
import '../editor_controller.dart';
import 'section_card.dart';

/// Shown only for the beta template: the cards of the beta game that are closest to the
/// numbers typed into the card (top speed, 0-60, weight, grip, RQ, year, drive).
class BetaMatchesSection extends StatefulWidget {
  const BetaMatchesSection({super.key, required this.controller});

  final EditorController controller;

  @override
  State<BetaMatchesSection> createState() => _BetaMatchesSectionState();
}

class _BetaMatchesSectionState extends State<BetaMatchesSection> {
  late final Future<BetaMatcher> _matcher = BetaMatcher.load();

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Closest in the beta game',
      children: [
        FutureBuilder<BetaMatcher>(
          future: _matcher,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('The list of beta cards could not be loaded.', style: theme.textTheme.bodySmall);
            }
            final matcher = snapshot.data;
            if (matcher == null) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              );
            }
            final matches = matcher.nearest(c.project);
            if (matches.isEmpty) {
              return Text(
                'Fill in at least two of: top speed, 0-60, weight, grip, RQ. '
                'The beta cards with the closest numbers appear here.',
                style: theme.textTheme.bodySmall,
              );
            }
            final anyHidden = matches.any((m) => m.card.gripHidden);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final m in matches)
                  _MatchTile(
                    match: m,
                    classColor: c.template.classColors[m.card.carClass],
                  ),
                Text(
                  'Based on ${matcher.cards.length} cards read from screenshots, so the list is not complete. '
                  'In brackets: the beta card minus yours.'
                  '${anyHidden ? ' A grip of 100 or more is cut on the beta card and shown as 100+.' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match, required this.classColor});

  final BetaMatch match;
  final Color? classColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = match.card;
    final percent = (match.closeness * 100).round();
    final subtitle = [
      if (card.year != null) '${card.year}',
      if (card.country.isNotEmpty) card.country,
    ].join(' \u00b7 ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RatingBadge(rating: card.rating, color: classColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        card.title,
                        style: theme.textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$percent%', style: theme.textTheme.titleSmall),
                  ],
                ),
                if (subtitle.isNotEmpty) Text(subtitle, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [for (final part in match.parts) _PartLabel(part: part)],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: match.closeness, minHeight: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PartLabel extends StatelessWidget {
  const _PartLabel({required this.part});

  final BetaPart part;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = part.diff.isEmpty ? '${part.label} ${part.value}' : '${part.label} ${part.value} (${part.diff})';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: theme.textTheme.bodySmall),
    );
  }
}

/// The rating in the colour of its class, like the badge in the lower left corner of the beta card.
class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating, required this.color});

  final int? rating;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? Colors.grey;
    final dark = ThemeData.estimateBrightnessForColor(fill) == Brightness.dark;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(6)),
      child: Text(
        rating == null ? '-' : '$rating',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: dark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }
}
