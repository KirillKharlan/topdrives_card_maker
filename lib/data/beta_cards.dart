import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import 'models/card_project.dart';

/// One card of the beta game, read from the screenshots the user collected
/// (assets/data/beta_cards.json, made by tool/make_beta_cards_json.py).
class BetaCard {
  const BetaCard({
    required this.name,
    this.nameUncertain = false,
    this.year,
    this.country = '',
    this.rating,
    this.speed,
    this.accel,
    this.weight,
    this.drive = '',
    this.grip,
    this.gripHidden = false,
    this.carClass = '',
  });

  /// Empty when the name could not be read from the screenshot.
  final String name;

  /// The name was guessed (blurry screenshot): shown with a question mark.
  final bool nameUncertain;
  final int? year;
  final String country;

  /// The number in the lower left corner of the card (RQ).
  final int? rating;

  /// Miles per hour, seconds for 0-60, weight as printed on the card.
  final double? speed;
  final double? accel;
  final double? weight;

  /// 4WD / RWD / FWD, or '' when unknown.
  final String drive;

  /// Null when [gripHidden]: the beta card has room for two digits, so a grip of 100 or more is cut.
  final double? grip;
  final bool gripHidden;

  /// S, A, B, C or D, taken from the rating (the colour of the rating badge).
  final String carClass;

  String get title => name.isEmpty ? 'Name not read' : (nameUncertain ? '$name ?' : name);

  factory BetaCard.fromJson(Map<String, dynamic> j) => BetaCard(
        name: (j['n'] as String?) ?? '',
        nameUncertain: j['q'] != null,
        year: (j['y'] as num?)?.toInt(),
        country: (j['c'] as String?) ?? '',
        rating: (j['r'] as num?)?.toInt(),
        speed: (j['s'] as num?)?.toDouble(),
        accel: (j['z'] as num?)?.toDouble(),
        weight: (j['w'] as num?)?.toDouble(),
        drive: (j['d'] as String?) ?? '',
        grip: (j['g'] as num?)?.toDouble(),
        gripHidden: j['gh'] != null,
        carClass: (j['cls'] as String?) ?? '',
      );
}

/// One compared value: what the reference card has and how it differs from the card being made.
class BetaPart {
  const BetaPart({required this.label, required this.value, this.diff = ''});

  final String label;
  final String value;

  /// Reference minus yours ("+8", "-0.3", "="), empty when there is nothing to compare.
  final String diff;
}

class BetaMatch {
  const BetaMatch({required this.card, required this.distance, required this.parts});

  final BetaCard card;

  /// 0 = identical; 1 = every compared value is one "tolerance" away on average.
  final double distance;
  final List<BetaPart> parts;

  /// 1.0 = identical, falls towards 0 the further away the card is.
  double get closeness => math.exp(-distance / 2);
}

/// The query: numbers typed into the card that is being made.
class _Query {
  const _Query({
    this.speed,
    this.accel,
    this.weight,
    this.grip,
    this.rating,
    this.year,
    this.drive = '',
    this.carClass = '',
  });

  final double? speed;
  final double? accel;
  final double? weight;
  final double? grip;
  final int? rating;
  final int? year;
  final String drive;
  final String carClass;

  /// How many of the five stats are filled in (the year is too weak to search by itself).
  int get statCount {
    var n = 0;
    if (speed != null) n++;
    if (accel != null) n++;
    if (weight != null) n++;
    if (grip != null) n++;
    if (rating != null) n++;
    return n;
  }

  static double? _number(String raw) {
    final t = raw.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  static int? _yearOf(String raw) {
    final v = int.tryParse(raw.trim());
    if (v == null) return null;
    if (v >= 100) return v;
    return v <= 30 ? 2000 + v : 1900 + v;
  }

  factory _Query.from(CardProject p) => _Query(
        speed: _number(p.topSpeed),
        accel: p.accelIsNotApplicable ? null : _number(p.accel),
        weight: _number(p.weight),
        grip: _number(p.handling),
        rating: int.tryParse(p.rq.trim()),
        year: _yearOf(p.year),
        drive: p.drive.trim().toUpperCase(),
        carClass: p.carClass.trim().toUpperCase(),
      );
}

/// Finds the beta cards whose numbers are closest to the card the person is making.
///
/// Every filled-in value is compared with the same value of the reference card and the difference is
/// divided by a "tolerance" (what counts as close: 8 mph, 0.4 s, 100 weight, 6 grip, 1.5 rating, 4 years).
/// The distance is the weighted mean of the squared results, plus a penalty for another drive.
class BetaMatcher {
  BetaMatcher(this.cards);

  final List<BetaCard> cards;

  static const double _tolSpeed = 8;
  static const double _tolAccel = 0.4;
  static const double _tolWeight = 100;
  static const double _tolGrip = 6;
  static const double _tolRating = 1.5;
  static const double _tolYear = 4;

  static const double _weightRating = 1.2;
  static const double _weightYear = 0.5;
  static const double _driveMismatch = 1.0;
  static const double _classMismatch = 0.5;

  static BetaMatcher? _cache;

  /// Reads the bundled list once and keeps it.
  static Future<BetaMatcher> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/data/beta_cards.json');
    final list = jsonDecode(raw) as List<dynamic>;
    final matcher = BetaMatcher([
      for (final e in list) BetaCard.fromJson(e as Map<String, dynamic>),
    ]);
    _cache = matcher;
    return matcher;
  }

  /// The [limit] closest cards, best first. Empty until at least two stats are filled in.
  List<BetaMatch> nearest(CardProject project, {int limit = 5}) {
    final q = _Query.from(project);
    if (q.statCount < 2) return const <BetaMatch>[];
    final found = <BetaMatch>[];
    for (final card in cards) {
      final m = _score(q, card);
      if (m != null) found.add(m);
    }
    found.sort((a, b) => a.distance.compareTo(b.distance));
    return found.length > limit ? found.sublist(0, limit) : found;
  }

  static String _signed(double d, int decimals) {
    final t = d.toStringAsFixed(decimals);
    if (double.parse(t) == 0) return '=';
    return d > 0 ? '+$t' : t;
  }

  BetaMatch? _score(_Query q, BetaCard c) {
    var weightSum = 0.0;
    var sum = 0.0;
    var used = 0;
    final parts = <BetaPart>[];

    void add({
      required String label,
      required double? want,
      required double? have,
      required double tolerance,
      required int decimals,
      double weight = 1.0,
    }) {
      if (have == null) return;
      if (want == null) {
        // Nothing typed in yet: the value of the beta card is still shown, it just is not compared.
        parts.add(BetaPart(label: label, value: have.toStringAsFixed(decimals)));
        return;
      }
      final z = (want - have) / tolerance;
      weightSum += weight;
      sum += weight * z * z;
      used++;
      parts.add(BetaPart(
        label: label,
        value: have.toStringAsFixed(decimals),
        diff: _signed(have - want, decimals),
      ));
    }

    add(label: 'Top speed', want: q.speed, have: c.speed, tolerance: _tolSpeed, decimals: 0);
    add(label: '0-60', want: q.accel, have: c.accel, tolerance: _tolAccel, decimals: 1);
    add(label: 'Weight', want: q.weight, have: c.weight, tolerance: _tolWeight, decimals: 0);

    final wantGrip = q.grip;
    if (wantGrip != null) {
      if (c.gripHidden) {
        // The card only shows the first digits of a grip of 100 or more.
        final z = wantGrip >= 100 ? 0.0 : (100 - wantGrip) / _tolGrip;
        weightSum += 1.0;
        sum += z * z;
        used++;
        parts.add(BetaPart(
          label: 'Grip',
          value: '100+',
          diff: wantGrip >= 100 ? '' : _signed(100 - wantGrip, 0),
        ));
      } else {
        add(label: 'Grip', want: wantGrip, have: c.grip, tolerance: _tolGrip, decimals: 0);
      }
    } else if (c.gripHidden) {
      parts.add(const BetaPart(label: 'Grip', value: '100+'));
    } else {
      add(label: 'Grip', want: null, have: c.grip, tolerance: _tolGrip, decimals: 0);
    }

    add(
      label: 'RQ',
      want: q.rating?.toDouble(),
      have: c.rating?.toDouble(),
      tolerance: _tolRating,
      decimals: 0,
      weight: _weightRating,
    );
    add(
      label: 'Year',
      want: q.year?.toDouble(),
      have: c.year?.toDouble(),
      tolerance: _tolYear,
      decimals: 0,
      weight: _weightYear,
    );

    if (used < 2 || weightSum <= 0) return null;
    var distance = sum / weightSum;

    if (c.drive.isNotEmpty) {
      if (q.drive.isNotEmpty) {
        final same = q.drive == c.drive;
        if (!same) distance += _driveMismatch;
        parts.add(BetaPart(label: 'Drive', value: c.drive, diff: same ? '' : 'differs'));
      } else {
        parts.add(BetaPart(label: 'Drive', value: c.drive));
      }
    }
    // Without an RQ the class is the next best hint of how strong the car is.
    if (q.rating == null && q.carClass.isNotEmpty && c.carClass.isNotEmpty && q.carClass != c.carClass) {
      distance += _classMismatch;
    }
    return BetaMatch(card: c, distance: distance, parts: parts);
  }
}
