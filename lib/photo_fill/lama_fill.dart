import 'dart:math' as math;
import 'dart:typed_data';

/// LaMa (big-lama, Apache-2.0) works on 512 x 512 pictures only.
const lamaSize = 512;

/// What the background job needs: the model, the card with the photo placed on it at a
/// small size (long side [lamaSize]) and at the card's own size. Straight RGBA, an alpha
/// below 250 means "no photo here" (the same convention as the PatchMatch fill).
class LamaJob {
  const LamaJob({
    required this.modelPath,
    required this.workWidth,
    required this.workHeight,
    required this.workRgba,
    required this.fullWidth,
    required this.fullHeight,
    required this.fullRgba,
  });

  final String modelPath;
  final int workWidth, workHeight;
  final Uint8List workRgba;
  final int fullWidth, fullHeight;
  final Uint8List fullRgba;
}

/// The two tensors of the model: image (CHW, 0..1, the empty areas are black) and
/// mask (1 = fill this, 0 = keep). [offsetX] / [offsetY] tell where the card sits in the square.
class LamaInputs {
  const LamaInputs({
    required this.image,
    required this.mask,
    required this.offsetX,
    required this.offsetY,
  });

  final Float32List image;
  final Float32List mask;
  final int offsetX, offsetY;
}

int _clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

int _toByte(double v) => _clampInt(v.round(), 0, 255);

/// Mirror-like index: 0 1 2 .. n-1 n-1 .. 1 0 0 1 ... (also for negative [i]).
int reflectIndex(int i, int n) {
  final period = 2 * n;
  var m = i % period;
  if (m < 0) m += period;
  return m >= n ? period - 1 - m : m;
}

/// Grows the 1s of [m] by [r] pixels in every direction (a square window).
Uint8List _dilate(Uint8List m, int w, int h, int r) {
  final horizontal = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (m[y * w + x] == 0) continue;
      final from = math.max(0, x - r), to = math.min(w - 1, x + r);
      for (var i = from; i <= to; i++) {
        horizontal[y * w + i] = 1;
      }
    }
  }
  final out = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (horizontal[y * w + x] == 0) continue;
      final from = math.max(0, y - r), to = math.min(h - 1, y + r);
      for (var j = from; j <= to; j++) {
        out[j * w + x] = 1;
      }
    }
  }
  return out;
}

/// Puts the card in the middle of a 512 x 512 square and fills the rest of the square by
/// mirroring the card, so the model never sees a flat grey border. The empty areas are
/// grown by 2 pixels so the soft edge of the photo is built again too.
LamaInputs lamaPrepareInputs(Uint8List rgba, int w, int h) {
  const s = lamaSize;
  if (w < 1 || h < 1 || w > s || h > s) {
    throw ArgumentError('the card must fit into $s x $s (got $w x $h)');
  }
  final ox = (s - w) ~/ 2, oy = (s - h) ~/ 2;
  final xs = List<int>.generate(s, (x) => reflectIndex(x - ox, w));
  final ys = List<int>.generate(s, (y) => reflectIndex(y - oy, h));

  var hole = Uint8List(s * s);
  for (var y = 0; y < s; y++) {
    for (var x = 0; x < s; x++) {
      final src = ys[y] * w + xs[x];
      if (rgba[4 * src + 3] < 250) hole[y * s + x] = 1;
    }
  }
  hole = _dilate(hole, s, s, 2);

  final image = Float32List(3 * s * s);
  final mask = Float32List(s * s);
  for (var y = 0; y < s; y++) {
    for (var x = 0; x < s; x++) {
      final p = y * s + x;
      if (hole[p] == 1) {
        mask[p] = 1;
        continue;
      }
      final src = 4 * (ys[y] * w + xs[x]);
      image[p] = rgba[src] / 255;
      image[s * s + p] = rgba[src + 1] / 255;
      image[2 * s * s + p] = rgba[src + 2] / 255;
    }
  }
  return LamaInputs(image: image, mask: mask, offsetX: ox, offsetY: oy);
}

/// The card's part of the model's output (CHW, 0..255) as RGB bytes, [w] x [h].
Uint8List lamaCropOutput(Float32List out, int w, int h) {
  const s = lamaSize;
  final ox = (s - w) ~/ 2, oy = (s - h) ~/ 2;
  final rgb = Uint8List(w * h * 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = (y + oy) * s + (x + ox);
      final o = 3 * (y * w + x);
      for (var c = 0; c < 3; c++) {
        final v = out[c * s * s + p];
        rgb[o + c] = v.isNaN ? 0 : _toByte(v);
      }
    }
  }
  return rgb;
}

/// Bilinear resize of RGB bytes.
Uint8List _resizeRgb(Uint8List src, int sw, int sh, int dw, int dh) {
  final dst = Uint8List(dw * dh * 3);
  final xScale = sw / dw, yScale = sh / dh;
  for (var y = 0; y < dh; y++) {
    final fy = math.max(0.0, math.min(sh - 1.0, (y + 0.5) * yScale - 0.5));
    final y0 = fy.floor(), y1 = math.min(sh - 1, y0 + 1);
    final wy = fy - y0;
    for (var x = 0; x < dw; x++) {
      final fx = math.max(0.0, math.min(sw - 1.0, (x + 0.5) * xScale - 0.5));
      final x0 = fx.floor(), x1 = math.min(sw - 1, x0 + 1);
      final wx = fx - x0;
      final o = 3 * (y * dw + x);
      for (var c = 0; c < 3; c++) {
        final a = src[3 * (y0 * sw + x0) + c] * (1 - wx) + src[3 * (y0 * sw + x1) + c] * wx;
        final b = src[3 * (y1 * sw + x0) + c] * (1 - wx) + src[3 * (y1 * sw + x1) + c] * wx;
        dst[o + c] = _clampInt((a * (1 - wy) + b * wy + 0.5).floor(), 0, 255);
      }
    }
  }
  return dst;
}

/// Average of the 1s in a (2r+1) x (2r+1) window (the picture edge counts as more of the same).
Float32List _boxBlur(Float32List src, int w, int h, int r) {
  final k = 2 * r + 1;
  final tmp = Float32List(w * h);
  for (var y = 0; y < h; y++) {
    final row = y * w;
    var sum = 0.0;
    for (var d = -r; d <= r; d++) {
      sum += src[row + _clampInt(d, 0, w - 1)];
    }
    for (var x = 0; x < w; x++) {
      tmp[row + x] = sum / k;
      sum += src[row + math.min(x + r + 1, w - 1)] - src[row + math.max(x - r, 0)];
    }
  }
  final out = Float32List(w * h);
  for (var x = 0; x < w; x++) {
    var sum = 0.0;
    for (var d = -r; d <= r; d++) {
      sum += tmp[_clampInt(d, 0, h - 1) * w + x];
    }
    for (var y = 0; y < h; y++) {
      out[y * w + x] = sum / k;
      sum += tmp[math.min(y + r + 1, h - 1) * w + x] - tmp[math.max(y - r, 0) * w + x];
    }
  }
  return out;
}

/// The card at its own resolution: the photo exactly as it is, the empty areas from the
/// model (brought up from 512 px). Over the first few pixels of the photo next to the
/// seam the two are mixed, so the seam does not show. Returns opaque straight RGBA.
Uint8List lamaCompose({
  required Uint8List lamaRgb,
  required int workWidth,
  required int workHeight,
  required Uint8List fullRgba,
  required int fullWidth,
  required int fullHeight,
}) {
  final up = _resizeRgb(lamaRgb, workWidth, workHeight, fullWidth, fullHeight);
  final n = fullWidth * fullHeight;
  final hole = Float32List(n);
  for (var p = 0; p < n; p++) {
    if (fullRgba[4 * p + 3] < 250) hole[p] = 1;
  }
  final blurred = _boxBlur(hole, fullWidth, fullHeight, 4);
  final out = Uint8List(n * 4);
  for (var p = 0; p < n; p++) {
    var w = 0.0; // how much of the real photo: 0 in the empty area, 1 away from the seam
    if (hole[p] == 0) w = math.max(0.0, math.min(1.0, 1 - 2 * blurred[p]));
    for (var c = 0; c < 3; c++) {
      final v = up[3 * p + c] * (1 - w) + fullRgba[4 * p + c] * w;
      out[4 * p + c] = _clampInt((v + 0.5).floor(), 0, 255);
    }
    out[4 * p + 3] = 255;
  }
  return out;
}
