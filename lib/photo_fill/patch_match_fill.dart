import 'dart:math' as math;
import 'dart:typed_data';

/// One fill job. The "work" image is the photo placed on a small card-shaped
/// canvas (where the search runs); the "full" image is the same at the card's
/// own resolution (where the sharp texture is taken from). Straight RGBA,
/// alpha below 250 means "no photo here".
class FillJob {
  const FillJob({
    required this.workWidth,
    required this.workHeight,
    required this.workRgba,
    required this.fullWidth,
    required this.fullHeight,
    required this.fullRgba,
  });

  final int workWidth, workHeight;
  final Uint8List workRgba;
  final int fullWidth, fullHeight;
  final Uint8List fullRgba;
}

/// Entry point for a background isolate. Returns the full-resolution RGBA
/// image (card sized, fully opaque) with the empty areas synthesised, or null
/// when the photo is too small to take texture from.
///
/// This is content-aware fill (the same idea as Snapseed's "Expand" or
/// Photoshop's Content-Aware Fill): the missing area is built from small
/// patches copied from the photo itself, found with multi-scale PatchMatch.
/// It is not a generative AI model.
Uint8List? runFillJob(FillJob job) {
  final low = _PatchMatchSolver(job.workWidth, job.workHeight, job.workRgba).solve();
  if (low == null) return null;
  return _composeFullResolution(job, low);
}

class _Level {
  _Level(this.w, this.h)
      : rgb = Float32List(3 * w * h),
        hole = Uint8List(w * h);

  final int w, h;
  final Float32List rgb;

  /// 1 = no photo here (to be synthesised).
  final Uint8List hole;
}

class _LowResult {
  _LowResult(this.width, this.height, this.rgb, this.nnf);

  final int width, height;
  final Float32List rgb;

  /// For every pixel the position of the source patch centre (or -1).
  final Int32List nnf;
}

class _PatchMatchSolver {
  _PatchMatchSolver(int width, int height, Uint8List rgba) {
    final n = width * height;
    final hole0 = Uint8List(n);
    for (var p = 0; p < n; p++) {
      hole0[p] = rgba[4 * p + 3] < 250 ? 1 : 0;
    }
    // Grow the empty area by one pixel so the soft, anti-aliased rim of the
    // photo is never used as a source.
    final grown = Uint8List.fromList(hole0);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = y * width + x;
        if (hole0[p] == 1) continue;
        if ((x > 0 && hole0[p - 1] == 1) ||
            (x < width - 1 && hole0[p + 1] == 1) ||
            (y > 0 && hole0[p - width] == 1) ||
            (y < height - 1 && hole0[p + width] == 1)) {
          grown[p] = 1;
        }
      }
    }
    final base = _Level(width, height);
    for (var p = 0; p < n; p++) {
      base.hole[p] = grown[p];
      if (grown[p] == 0) {
        base.rgb[3 * p] = rgba[4 * p].toDouble();
        base.rgb[3 * p + 1] = rgba[4 * p + 1].toDouble();
        base.rgb[3 * p + 2] = rgba[4 * p + 2].toDouble();
      }
    }
    _levels.add(base);
    var a = width, b = height;
    while (a ~/ 2 >= _minSide && b ~/ 2 >= _minSide) {
      final parent = _levels.last;
      final child = _Level((parent.w + 1) ~/ 2, (parent.h + 1) ~/ 2);
      for (var y = 0; y < child.h; y++) {
        for (var x = 0; x < child.w; x++) {
          var r = 0.0, g = 0.0, bl = 0.0;
          var count = 0;
          var anyHole = false;
          for (var dy = 0; dy < 2; dy++) {
            for (var dx = 0; dx < 2; dx++) {
              final px = 2 * x + dx, py = 2 * y + dy;
              if (px >= parent.w || py >= parent.h) continue;
              final q = py * parent.w + px;
              if (parent.hole[q] != 0) {
                anyHole = true;
                continue;
              }
              r += parent.rgb[3 * q];
              g += parent.rgb[3 * q + 1];
              bl += parent.rgb[3 * q + 2];
              count++;
            }
          }
          final p = y * child.w + x;
          if (anyHole || count == 0) {
            child.hole[p] = 1;
          } else {
            child.rgb[3 * p] = r / count;
            child.rgb[3 * p + 1] = g / count;
            child.rgb[3 * p + 2] = bl / count;
          }
        }
      }
      _levels.add(child);
      a = (a + 1) ~/ 2;
      b = (b + 1) ~/ 2;
    }
  }

  static const _radius = 2; // patch is 5 x 5
  static const _holeWeight = 0.1; // weight of empty pixels inside a target patch
  static const _distancePrior = 0.05; // prefers sources close to the target
  static const _anchorWeight = 0.3; // keeps colours close to a smooth estimate
  static const _minSide = 48;
  static const _iterations = [5, 8, 12]; // finest, middle, coarsest

  final List<_Level> _levels = [];
  int _seed = 2463534242;

  // Context of the level being processed (read by _distance).
  int _w = 0, _h = 0;
  Uint8List _hole = Uint8List(0);
  Float32List _cur = Float32List(0);
  Float32List _anchor = Float32List(0);

  int _rnd() {
    _seed = (_seed ^ (_seed << 13)) & 0xFFFFFFFF;
    _seed = _seed ^ (_seed >> 17);
    _seed = (_seed ^ (_seed << 5)) & 0xFFFFFFFF;
    return _seed;
  }

  _LowResult? solve() {
    Float32List? prevCur;
    Int32List? prevNnf;
    for (var l = _levels.length - 1; l >= 0; l--) {
      final level = _levels[l];
      final w = level.w, h = level.h, n = w * h;
      final valid = Uint8List(n), target = Uint8List(n);
      _validAndTarget(level, valid, target);
      final sources = <int>[];
      for (var i = 0; i < n; i++) {
        if (valid[i] != 0) sources.add(i);
      }
      if (sources.isEmpty) return null;

      // Smooth estimate of the empty area (also the starting point of the coarsest level).
      final anchor = Float32List.fromList(level.rgb);
      _diffuse(anchor, level.hole, w, h);
      final cur = Float32List.fromList(level.rgb);
      final nnf = Int32List(2 * n);
      final cost = Float32List(n);

      if (prevCur == null) {
        for (var i = 0; i < n; i++) {
          if (level.hole[i] != 0) {
            cur[3 * i] = anchor[3 * i];
            cur[3 * i + 1] = anchor[3 * i + 1];
            cur[3 * i + 2] = anchor[3 * i + 2];
          }
        }
        for (var i = 0; i < n; i++) {
          final s = sources[_rnd() % sources.length];
          nnf[2 * i] = s % w;
          nnf[2 * i + 1] = s ~/ w;
        }
      } else {
        final coarse = _levels[l + 1];
        final cw = coarse.w, ch = coarse.h;
        final pc = prevCur;
        final pnf = prevNnf!;
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final p = y * w + x;
            if (level.hole[p] == 0) continue;
            final fx = (x + 0.5) / 2 - 0.5, fy = (y + 0.5) / 2 - 0.5;
            final x0 = fx.floor(), y0 = fy.floor();
            final ax = fx - x0, ay = fy - y0;
            final xa = x0.clamp(0, cw - 1).toInt(), xb = (x0 + 1).clamp(0, cw - 1).toInt();
            final ya = y0.clamp(0, ch - 1).toInt(), yb = (y0 + 1).clamp(0, ch - 1).toInt();
            for (var c = 0; c < 3; c++) {
              cur[3 * p + c] = (1 - ax) * (1 - ay) * pc[3 * (ya * cw + xa) + c] +
                  ax * (1 - ay) * pc[3 * (ya * cw + xb) + c] +
                  (1 - ax) * ay * pc[3 * (yb * cw + xa) + c] +
                  ax * ay * pc[3 * (yb * cw + xb) + c];
            }
          }
        }
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final p = y * w + x;
            final cx = (x ~/ 2).clamp(0, cw - 1).toInt(), cy = (y ~/ 2).clamp(0, ch - 1).toInt();
            final q = cy * cw + cx;
            var sx = pnf[2 * q] * 2 + (x & 1);
            var sy = pnf[2 * q + 1] * 2 + (y & 1);
            if (pnf[2 * q] < 0 || sx < 0 || sy < 0 || sx >= w || sy >= h || valid[sy * w + sx] == 0) {
              final s = sources[_rnd() % sources.length];
              sx = s % w;
              sy = s ~/ w;
            }
            nnf[2 * p] = sx;
            nnf[2 * p + 1] = sy;
          }
        }
      }

      _w = w;
      _h = h;
      _hole = level.hole;
      _cur = cur;
      _anchor = anchor;

      for (var i = 0; i < n; i++) {
        if (target[i] != 0) {
          cost[i] = _distance(i % w, i ~/ w, nnf[2 * i], nnf[2 * i + 1], double.infinity);
        } else {
          nnf[2 * i] = -1;
          nnf[2 * i + 1] = -1;
        }
      }
      final iterations = _iterations[math.min(l, 2)];
      for (var it = 0; it < iterations; it++) {
        for (var pass = 0; pass < 2; pass++) {
          _patchMatchPass(valid, target, nnf, cost, pass + it);
        }
        _vote(target, nnf);
        for (var i = 0; i < n; i++) {
          if (target[i] != 0) {
            cost[i] = _distance(i % w, i ~/ w, nnf[2 * i], nnf[2 * i + 1], double.infinity);
          }
        }
      }
      prevCur = cur;
      prevNnf = nnf;
    }
    final finest = _levels.first;
    return _LowResult(finest.w, finest.h, prevCur!, prevNnf!);
  }

  /// valid  = centres whose whole patch lies on the photo (usable as sources);
  /// target = centres whose patch touches the empty area (they get matched).
  void _validAndTarget(_Level level, Uint8List valid, Uint8List target) {
    final w = level.w, h = level.h;
    final integral = Int32List((w + 1) * (h + 1));
    for (var y = 0; y < h; y++) {
      var row = 0;
      for (var x = 0; x < w; x++) {
        row += level.hole[y * w + x];
        integral[(y + 1) * (w + 1) + x + 1] = integral[y * (w + 1) + x + 1] + row;
      }
    }
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final x0 = math.max(x - _radius, 0), x1 = math.min(x + _radius, w - 1);
        final y0 = math.max(y - _radius, 0), y1 = math.min(y + _radius, h - 1);
        final count = integral[(y1 + 1) * (w + 1) + x1 + 1] -
            integral[y0 * (w + 1) + x1 + 1] -
            integral[(y1 + 1) * (w + 1) + x0] +
            integral[y0 * (w + 1) + x0];
        final inside = x - _radius >= 0 && y - _radius >= 0 && x + _radius < w && y + _radius < h;
        valid[y * w + x] = (inside && count == 0) ? 1 : 0;
        target[y * w + x] = count > 0 ? 1 : 0;
      }
    }
  }

  /// Fills the empty area with a smooth average of its surroundings, from the
  /// outside in.
  static void _diffuse(Float32List rgb, Uint8List hole0, int w, int h) {
    final hole = Uint8List.fromList(hole0);
    final next = Uint8List(w * h);
    while (true) {
      next.setAll(0, hole);
      var changed = false;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final p = y * w + x;
          if (hole[p] == 0) continue;
          var r = 0.0, g = 0.0, b = 0.0;
          var count = 0;
          if (x > 0 && hole[p - 1] == 0) {
            r += rgb[3 * (p - 1)];
            g += rgb[3 * (p - 1) + 1];
            b += rgb[3 * (p - 1) + 2];
            count++;
          }
          if (x < w - 1 && hole[p + 1] == 0) {
            r += rgb[3 * (p + 1)];
            g += rgb[3 * (p + 1) + 1];
            b += rgb[3 * (p + 1) + 2];
            count++;
          }
          if (y > 0 && hole[p - w] == 0) {
            r += rgb[3 * (p - w)];
            g += rgb[3 * (p - w) + 1];
            b += rgb[3 * (p - w) + 2];
            count++;
          }
          if (y < h - 1 && hole[p + w] == 0) {
            r += rgb[3 * (p + w)];
            g += rgb[3 * (p + w) + 1];
            b += rgb[3 * (p + w) + 2];
            count++;
          }
          if (count > 0) {
            rgb[3 * p] = r / count;
            rgb[3 * p + 1] = g / count;
            rgb[3 * p + 2] = b / count;
            next[p] = 0;
            changed = true;
          }
        }
      }
      hole.setAll(0, next);
      if (!changed) break;
    }
  }

  double _distance(int tx, int ty, int sx, int sy, double best) {
    final w = _w, h = _h, r = _radius;
    final cur = _cur, hole = _hole, anchor = _anchor;
    var d = _distancePrior * ((sx - tx) * (sx - tx) + (sy - ty) * (sy - ty));
    for (var dy = -r; dy <= r; dy++) {
      var ty2 = ty + dy;
      if (ty2 < 0) ty2 = 0;
      if (ty2 >= h) ty2 = h - 1;
      final sy2 = sy + dy;
      for (var dx = -r; dx <= r; dx++) {
        var tx2 = tx + dx;
        if (tx2 < 0) tx2 = 0;
        if (tx2 >= w) tx2 = w - 1;
        final sx2 = sx + dx;
        final tp = ty2 * w + tx2, sp = sy2 * w + sx2;
        final isHole = hole[tp] != 0;
        final a = cur[3 * tp] - cur[3 * sp];
        final b = cur[3 * tp + 1] - cur[3 * sp + 1];
        final c = cur[3 * tp + 2] - cur[3 * sp + 2];
        d += (isHole ? _holeWeight : 1.0) * (a * a + b * b + c * c);
        if (isHole) {
          final a2 = anchor[3 * tp] - cur[3 * sp];
          final b2 = anchor[3 * tp + 1] - cur[3 * sp + 1];
          final c2 = anchor[3 * tp + 2] - cur[3 * sp + 2];
          d += _anchorWeight * (a2 * a2 + b2 * b2 + c2 * c2);
        }
      }
      if (d >= best) return d;
    }
    return d;
  }

  void _patchMatchPass(Uint8List valid, Uint8List target, Int32List nnf, Float32List cost, int pass) {
    final w = _w, h = _h;
    final forward = pass % 2 == 0;
    final yStart = forward ? 0 : h - 1, yEnd = forward ? h : -1, yStep = forward ? 1 : -1;
    final xStart = forward ? 0 : w - 1, xEnd = forward ? w : -1, xStep = forward ? 1 : -1;
    for (var y = yStart; y != yEnd; y += yStep) {
      for (var x = xStart; x != xEnd; x += xStep) {
        final p = y * w + x;
        if (target[p] == 0) continue;
        var bx = nnf[2 * p], by = nnf[2 * p + 1];
        var bd = cost[p].toDouble();
        // propagation from the two neighbours already visited
        for (var k = 0; k < 2; k++) {
          final qx = k == 0 ? x - xStep : x;
          final qy = k == 0 ? y : y - yStep;
          if (qx < 0 || qy < 0 || qx >= w || qy >= h) continue;
          final q = qy * w + qx;
          if (target[q] == 0) continue;
          final sx = nnf[2 * q] + (x - qx), sy = nnf[2 * q + 1] + (y - qy);
          if (sx < 0 || sy < 0 || sx >= w || sy >= h || valid[sy * w + sx] == 0) continue;
          final d = _distance(x, y, sx, sy, bd);
          if (d < bd) {
            bd = d;
            bx = sx;
            by = sy;
          }
        }
        // random search around the current best, with a shrinking radius
        var radius = math.max(w, h);
        while (radius >= 1) {
          final sx = bx + (_rnd() % (2 * radius + 1)) - radius;
          final sy = by + (_rnd() % (2 * radius + 1)) - radius;
          if (sx >= 0 && sy >= 0 && sx < w && sy < h && valid[sy * w + sx] != 0) {
            final d = _distance(x, y, sx, sy, bd);
            if (d < bd) {
              bd = d;
              bx = sx;
              by = sy;
            }
          }
          radius ~/= 2;
        }
        nnf[2 * p] = bx;
        nnf[2 * p + 1] = by;
        cost[p] = bd;
      }
    }
  }

  /// Every empty pixel becomes the weighted average of what all the patches
  /// that overlap it say.
  void _vote(Uint8List target, Int32List nnf) {
    final w = _w, h = _h, r = _radius;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = y * w + x;
        if (_hole[p] == 0) continue;
        var sr = 0.0, sg = 0.0, sb = 0.0, sw = 0.0;
        for (var dy = -r; dy <= r; dy++) {
          for (var dx = -r; dx <= r; dx++) {
            final qx = x + dx, qy = y + dy;
            if (qx < 0 || qy < 0 || qx >= w || qy >= h) continue;
            final q = qy * w + qx;
            if (target[q] == 0) continue;
            final sx = nnf[2 * q] + (x - qx), sy = nnf[2 * q + 1] + (y - qy);
            if (sx < 0 || sy < 0 || sx >= w || sy >= h) continue;
            final weight = 1.0 / (1.0 + 0.5 * (dx * dx + dy * dy));
            final sp = sy * w + sx;
            sr += weight * _cur[3 * sp];
            sg += weight * _cur[3 * sp + 1];
            sb += weight * _cur[3 * sp + 2];
            sw += weight;
          }
        }
        if (sw > 0) {
          _cur[3 * p] = sr / sw;
          _cur[3 * p + 1] = sg / sw;
          _cur[3 * p + 2] = sb / sw;
        }
      }
    }
  }
}

/// Upscales the low-resolution result to the card size and brings back real
/// texture: every empty pixel also receives the fine detail (original minus a
/// blurred copy) of the photo pixel that its patch was matched to.
Uint8List _composeFullResolution(FillJob job, _LowResult low) {
  final fw = job.fullWidth, fh = job.fullHeight;
  final lw = low.width, lh = low.height;
  final scx = fw / lw, scy = fh / lh;
  final src = job.fullRgba;
  final count = fw * fh;

  final rgb = Float32List(3 * count);
  for (var i = 0; i < count; i++) {
    rgb[3 * i] = src[4 * i].toDouble();
    rgb[3 * i + 1] = src[4 * i + 1].toDouble();
    rgb[3 * i + 2] = src[4 * i + 2].toDouble();
  }
  final blurRadius = math.max(1, (math.max(scx, scy) * 0.75).round());
  final blurred = _boxBlur3(rgb, fw, fh, blurRadius);

  final out = Uint8List(4 * count);
  int clampByte(double v) => v < 0 ? 0 : (v > 255 ? 255 : (v + 0.5).toInt());

  for (var y = 0; y < fh; y++) {
    for (var x = 0; x < fw; x++) {
      final p = y * fw + x;
      if (src[4 * p + 3] >= 253) {
        out[4 * p] = src[4 * p];
        out[4 * p + 1] = src[4 * p + 1];
        out[4 * p + 2] = src[4 * p + 2];
        out[4 * p + 3] = 255;
        continue;
      }
      // bilinear sample of the low-resolution fill
      final fx = (x + 0.5) / scx - 0.5, fy = (y + 0.5) / scy - 0.5;
      final x0 = fx.floor(), y0 = fy.floor();
      final ax = fx - x0, ay = fy - y0;
      final xa = x0.clamp(0, lw - 1).toInt(), xb = (x0 + 1).clamp(0, lw - 1).toInt();
      final ya = y0.clamp(0, lh - 1).toInt(), yb = (y0 + 1).clamp(0, lh - 1).toInt();
      double sample(int c) =>
          (1 - ax) * (1 - ay) * low.rgb[3 * (ya * lw + xa) + c] +
          ax * (1 - ay) * low.rgb[3 * (ya * lw + xb) + c] +
          (1 - ax) * ay * low.rgb[3 * (yb * lw + xa) + c] +
          ax * ay * low.rgb[3 * (yb * lw + xb) + c];
      var r = sample(0), g = sample(1), b = sample(2);
      // detail of the matched source pixel
      final pwx = fx.round().clamp(0, lw - 1).toInt();
      final pwy = fy.round().clamp(0, lh - 1).toInt();
      final q = pwy * lw + pwx;
      final nx = low.nnf[2 * q];
      if (nx >= 0) {
        final sx = (nx * scx + (x - pwx * scx)).round().clamp(0, fw - 1).toInt();
        final sy = (low.nnf[2 * q + 1] * scy + (y - pwy * scy)).round().clamp(0, fh - 1).toInt();
        final sp = sy * fw + sx;
        r += rgb[3 * sp] - blurred[3 * sp];
        g += rgb[3 * sp + 1] - blurred[3 * sp + 1];
        b += rgb[3 * sp + 2] - blurred[3 * sp + 2];
      }
      out[4 * p] = clampByte(r);
      out[4 * p + 1] = clampByte(g);
      out[4 * p + 2] = clampByte(b);
      out[4 * p + 3] = 255;
    }
  }
  return out;
}

/// Three box-blur passes (about a Gaussian) on interleaved RGB.
Float32List _boxBlur3(Float32List source, int w, int h, int radius) {
  var a = Float32List.fromList(source);
  var b = Float32List(source.length);
  final line = Float64List(math.max(w, h) + 1);
  for (var pass = 0; pass < 3; pass++) {
    // horizontal: a -> b
    for (var y = 0; y < h; y++) {
      for (var c = 0; c < 3; c++) {
        line[0] = 0;
        for (var x = 0; x < w; x++) {
          line[x + 1] = line[x] + a[3 * (y * w + x) + c];
        }
        for (var x = 0; x < w; x++) {
          final x0 = math.max(0, x - radius), x1 = math.min(w - 1, x + radius);
          b[3 * (y * w + x) + c] = (line[x1 + 1] - line[x0]) / (x1 - x0 + 1);
        }
      }
    }
    // vertical: b -> a
    for (var x = 0; x < w; x++) {
      for (var c = 0; c < 3; c++) {
        line[0] = 0;
        for (var y = 0; y < h; y++) {
          line[y + 1] = line[y] + b[3 * (y * w + x) + c];
        }
        for (var y = 0; y < h; y++) {
          final y0 = math.max(0, y - radius), y1 = math.min(h - 1, y + radius);
          a[3 * (y * w + x) + c] = (line[y1 + 1] - line[y0]) / (y1 - y0 + 1);
        }
      }
    }
  }
  return a;
}
