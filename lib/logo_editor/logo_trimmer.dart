import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'rgba_image.dart';

/// Crops the empty margins around a logo so that the logo itself, not its
/// picture, is what gets centred in the logo slot on the card. Margins are
/// either transparent pixels or a plain background colour.
///
/// Returns a PNG, or null if the logo has no margins worth trimming.
Future<Uint8List?> trimLogoMargins(File file) async {
  final image = await RgbaImage.decode(await file.readAsBytes(), maxSide: 800);
  final w = image.width, h = image.height;
  final d = image.data;

  var transparent = 0;
  for (var p = 0; p < w * h; p++) {
    if (d[4 * p + 3] < 250) transparent++;
  }
  final hasAlpha = transparent > w * h * 0.005;

  // Background colour = the most common colour along the border.
  var bgR = 0, bgG = 0, bgB = 0;
  if (!hasAlpha) {
    final counts = <int, int>{};
    int key(int p) => ((d[4 * p] >> 4) << 8) | ((d[4 * p + 1] >> 4) << 4) | (d[4 * p + 2] >> 4);
    void count(int p) => counts[key(p)] = (counts[key(p)] ?? 0) + 1;
    for (var x = 0; x < w; x++) {
      count(x);
      count((h - 1) * w + x);
    }
    for (var y = 1; y < h - 1; y++) {
      count(y * w);
      count(y * w + w - 1);
    }
    var bestKey = 0, best = -1;
    counts.forEach((k, v) {
      if (v > best) {
        best = v;
        bestKey = k;
      }
    });
    var n = 0;
    void add(int p) {
      if (key(p) != bestKey) return;
      bgR += d[4 * p];
      bgG += d[4 * p + 1];
      bgB += d[4 * p + 2];
      n++;
    }
    for (var x = 0; x < w; x++) {
      add(x);
      add((h - 1) * w + x);
    }
    for (var y = 1; y < h - 1; y++) {
      add(y * w);
      add(y * w + w - 1);
    }
    if (n > 0) {
      bgR ~/= n;
      bgG ~/= n;
      bgB ~/= n;
    }
  }

  bool isContent(int p) {
    if (hasAlpha) return d[4 * p + 3] > 24;
    final dr = d[4 * p] - bgR, dg = d[4 * p + 1] - bgG, db = d[4 * p + 2] - bgB;
    return dr * dr + dg * dg + db * db > 45 * 45;
  }

  var minX = w, minY = h, maxX = -1, maxY = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (isContent(y * w + x)) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < 0) return null;

  final pad = math.max(2, (math.max(w, h) * 0.03).round());
  final x0 = math.max(0, minX - pad), y0 = math.max(0, minY - pad);
  final x1 = math.min(w, maxX + 1 + pad), y1 = math.min(h, maxY + 1 + pad);

  // Nothing worth cutting (less than 4% of the area would go).
  if ((x1 - x0) * (y1 - y0) > w * h * 0.96) return null;
  return image.crop(x0, y0, x1, y1).toPng();
}
