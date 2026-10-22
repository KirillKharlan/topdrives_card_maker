import 'dart:typed_data';

import 'rgba_image.dart';

/// Removes a plain background from a logo, fully offline and without any
/// ML model: it floods outwards from the picture edges (or from a tapped
/// point) over pixels whose colour is close to the starting colour.
///
/// Works well for logos on a flat or near-flat background (white, black,
/// a single colour). It cannot cut a car out of a busy photo.
class BackgroundRemover {
  BackgroundRemover(this.source) : _removed = Uint8List(source.width * source.height) {
    reset();
  }

  final RgbaImage source;

  /// 1 = background (removed), 0 = kept.
  final Uint8List _removed;

  /// Back to the original; pixels that are already transparent count as removed.
  void reset() {
    final d = source.data;
    for (var p = 0; p < _removed.length; p++) {
      _removed[p] = d[p * 4 + 3] < 16 ? 1 : 0;
    }
  }

  /// Removes the dominant colour found along the picture border, spreading
  /// inwards. [tolerance] is the allowed RGB distance (0..441).
  void removeFromEdges(int tolerance) {
    final w = source.width;
    final h = source.height;
    final d = source.data;

    final border = <int>[];
    for (var x = 0; x < w; x++) {
      border.add(x);
      border.add((h - 1) * w + x);
    }
    for (var y = 1; y < h - 1; y++) {
      border.add(y * w);
      border.add(y * w + w - 1);
    }

    int bucket(int i) => ((d[i] >> 4) << 8) | ((d[i + 1] >> 4) << 4) | (d[i + 2] >> 4);

    final counts = <int, int>{};
    for (final p in border) {
      if (_removed[p] == 1) continue;
      final key = bucket(p * 4);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    if (counts.isEmpty) return;

    var bestKey = -1;
    var bestCount = 0;
    counts.forEach((key, count) {
      if (count > bestCount) {
        bestCount = count;
        bestKey = key;
      }
    });

    var sr = 0, sg = 0, sb = 0, n = 0;
    for (final p in border) {
      if (_removed[p] == 1) continue;
      final i = p * 4;
      if (bucket(i) != bestKey) continue;
      sr += d[i];
      sg += d[i + 1];
      sb += d[i + 2];
      n++;
    }
    _flood(border, sr ~/ n, sg ~/ n, sb ~/ n, tolerance);
  }

  /// "Magic wand": removes the colour under ([x],[y]). With [contiguous] only
  /// the connected area is removed, otherwise every similar pixel (which also
  /// punches holes into the logo where the same colour appears inside it).
  void removeAt(int x, int y, int tolerance, {bool contiguous = true}) {
    final w = source.width;
    final h = source.height;
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final p = y * w + x;
    if (_removed[p] == 1) return;
    final d = source.data;
    final i = p * 4;
    final r = d[i], g = d[i + 1], b = d[i + 2];
    if (contiguous) {
      _flood([p], r, g, b, tolerance);
      return;
    }
    final tolSq = tolerance * tolerance;
    for (var q = 0; q < w * h; q++) {
      if (_removed[q] == 1) continue;
      final j = q * 4;
      final dr = d[j] - r, dg = d[j + 1] - g, db = d[j + 2] - b;
      if (dr * dr + dg * dg + db * db <= tolSq) _removed[q] = 1;
    }
  }

  void _flood(List<int> seeds, int r, int g, int b, int tolerance) {
    final w = source.width;
    final h = source.height;
    final d = source.data;
    final tolSq = tolerance * tolerance;
    final stack = <int>[];

    bool matches(int p) {
      final i = p * 4;
      final dr = d[i] - r, dg = d[i + 1] - g, db = d[i + 2] - b;
      return dr * dr + dg * dg + db * db <= tolSq;
    }

    void push(int p) {
      if (_removed[p] == 0 && matches(p)) {
        _removed[p] = 1;
        stack.add(p);
      }
    }

    for (final s in seeds) {
      push(s);
    }
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      final x = p % w;
      final y = p ~/ w;
      if (x > 0) push(p - 1);
      if (x < w - 1) push(p + 1);
      if (y > 0) push(p - w);
      if (y < h - 1) push(p + w);
    }
  }

  /// Builds the result. [edge] (0..3) cleans the cut line: it eats up to
  /// edge~/2 pixels of leftover background halo and softens the border.
  /// With [trim] the transparent margins are cropped away.
  RgbaImage compose({int edge = 1, bool trim = true}) {
    final w = source.width;
    final h = source.height;
    final d = source.data;

    var mask = Uint8List.fromList(_removed);
    for (var k = 0; k < edge ~/ 2; k++) {
      mask = _growRemoved(mask, w, h);
    }

    var alpha = Uint8List(w * h);
    for (var p = 0; p < alpha.length; p++) {
      alpha[p] = mask[p] == 1 ? 0 : d[p * 4 + 3];
    }
    for (var k = 0; k < edge; k++) {
      alpha = _blur(alpha, w, h);
    }

    final out = Uint8List(w * h * 4);
    for (var p = 0; p < alpha.length; p++) {
      final a = alpha[p];
      if (a == 0) continue;
      final i = p * 4;
      out[i] = d[i];
      out[i + 1] = d[i + 1];
      out[i + 2] = d[i + 2];
      out[i + 3] = a;
    }

    final full = RgbaImage(w, h, out);
    return trim ? _trim(full) : full;
  }

  static Uint8List _growRemoved(Uint8List mask, int w, int h) {
    final out = Uint8List.fromList(mask);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = y * w + x;
        if (mask[p] == 1) continue;
        if ((x > 0 && mask[p - 1] == 1) ||
            (x < w - 1 && mask[p + 1] == 1) ||
            (y > 0 && mask[p - w] == 1) ||
            (y < h - 1 && mask[p + w] == 1)) {
          out[p] = 1;
        }
      }
    }
    return out;
  }

  static Uint8List _blur(Uint8List a, int w, int h) {
    final out = Uint8List(a.length);
    for (var y = 0; y < h; y++) {
      final y0 = y > 0 ? y - 1 : 0;
      final y1 = y < h - 1 ? y + 1 : h - 1;
      for (var x = 0; x < w; x++) {
        final x0 = x > 0 ? x - 1 : 0;
        final x1 = x < w - 1 ? x + 1 : w - 1;
        var sum = 0;
        for (var yy = y0; yy <= y1; yy++) {
          for (var xx = x0; xx <= x1; xx++) {
            sum += a[yy * w + xx];
          }
        }
        out[y * w + x] = sum ~/ ((x1 - x0 + 1) * (y1 - y0 + 1));
      }
    }
    return out;
  }

  static RgbaImage _trim(RgbaImage image) {
    final w = image.width;
    final h = image.height;
    final d = image.data;
    var minX = w, minY = h, maxX = -1, maxY = -1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (d[(y * w + x) * 4 + 3] > 20) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) return image; // nothing left, keep as is

    final pad = (w > h ? w : h) ~/ 50 + 2;
    minX = (minX - pad).clamp(0, w - 1);
    minY = (minY - pad).clamp(0, h - 1);
    maxX = (maxX + pad).clamp(0, w - 1);
    maxY = (maxY + pad).clamp(0, h - 1);

    final nw = maxX - minX + 1;
    final nh = maxY - minY + 1;
    final out = Uint8List(nw * nh * 4);
    for (var y = 0; y < nh; y++) {
      final srcStart = ((minY + y) * w + minX) * 4;
      out.setRange(y * nw * 4, (y + 1) * nw * 4, d, srcStart);
    }
    return RgbaImage(nw, nh, out);
  }
}
