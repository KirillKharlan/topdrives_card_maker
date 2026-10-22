import 'dart:math';

/// "1.2.3" style version with numeric comparison (so 1.10.0 > 1.9.0).
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.parts);

  final List<int> parts;

  /// Accepts "v1.2.3", "1.2.3+4", "1.2.3-beta".
  static AppVersion? tryParse(String raw) {
    var text = raw.trim();
    if (text.startsWith('v') || text.startsWith('V')) text = text.substring(1);
    text = text.split('+').first.split('-').first;
    final numbers = <int>[];
    for (final piece in text.split('.')) {
      final n = int.tryParse(piece);
      if (n == null) return null;
      numbers.add(n);
    }
    return numbers.isEmpty ? null : AppVersion(numbers);
  }

  @override
  int compareTo(AppVersion other) {
    final length = max(parts.length, other.parts.length);
    for (var i = 0; i < length; i++) {
      final a = i < parts.length ? parts[i] : 0;
      final b = i < other.parts.length ? other.parts[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }

  @override
  String toString() => parts.join('.');
}
