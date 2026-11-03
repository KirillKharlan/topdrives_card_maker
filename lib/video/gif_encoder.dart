import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

/// Work for the GIF encoder isolate: the frames were saved as zlib-compressed
/// RGBA files by [VideoExporter]; this turns them into one GIF file.
class GifJob {
  GifJob({
    required this.port,
    required this.frames,
    required this.out,
    required this.width,
    required this.height,
    required this.delayCs,
  });

  /// Gets `['progress', 0..1]`, then `['done']` or `['error', message]`.
  final SendPort port;
  final List<String> frames;
  final String out;
  final int width, height;

  /// Time of a frame in hundredths of a second (GIF cannot do finer).
  final int delayCs;
}

/// Entry point of the encoder isolate.
///
/// One palette of 256 colours is made for the whole clip (so colours do not
/// flicker between frames) from a sample of its frames; every frame is then
/// dithered (Floyd-Steinberg) to that palette, which keeps gradients and the
/// blurred glass smooth, and written straight to the file.
void gifWorker(GifJob job) {
  RandomAccessFile? file;
  try {
    final w = job.width;
    final h = job.height;
    final total = job.frames.length;

    final histogram = Uint32List(32768);
    final every = math.max(1, total ~/ 10);
    for (var f = 0; f < total; f += every) {
      final rgba = _readFrame(job.frames[f]);
      for (var p = 0; p < w * h; p += 7) {
        histogram[_key(rgba[p * 4], rgba[p * 4 + 1], rgba[p * 4 + 2])]++;
      }
    }
    final palette = Uint8List(768);
    final colors = _medianCut(histogram, palette);
    final lut = _nearestTable(palette, colors);

    file = File(job.out).openSync(mode: FileMode.write);
    file.writeFromSync(_header(w, h, palette));

    final indices = Uint8List(w * h);
    var rowErr = Int32List((w + 2) * 3);
    var nextErr = Int32List((w + 2) * 3);
    final lzw = _Lzw();
    for (var f = 0; f < total; f++) {
      final rgba = _readFrame(job.frames[f]);
      rowErr.fillRange(0, rowErr.length, 0);
      nextErr.fillRange(0, nextErr.length, 0);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          final e = (x + 1) * 3;
          final r = _clamp(rgba[i] + (rowErr[e] >> 4));
          final g = _clamp(rgba[i + 1] + (rowErr[e + 1] >> 4));
          final b = _clamp(rgba[i + 2] + (rowErr[e + 2] >> 4));
          final index = lut[_key(r, g, b)];
          indices[y * w + x] = index;
          final er = r - palette[index * 3];
          final eg = g - palette[index * 3 + 1];
          final eb = b - palette[index * 3 + 2];
          // Right 7/16, below-left 3/16, below 5/16, below-right 1/16.
          rowErr[e + 3] += er * 7;
          rowErr[e + 4] += eg * 7;
          rowErr[e + 5] += eb * 7;
          nextErr[e - 3] += er * 3;
          nextErr[e - 2] += eg * 3;
          nextErr[e - 1] += eb * 3;
          nextErr[e] += er * 5;
          nextErr[e + 1] += eg * 5;
          nextErr[e + 2] += eb * 5;
          nextErr[e + 3] += er;
          nextErr[e + 4] += eg;
          nextErr[e + 5] += eb;
        }
        final done = rowErr;
        rowErr = nextErr;
        nextErr = done;
        nextErr.fillRange(0, nextErr.length, 0);
      }
      file.writeFromSync(_frame(lzw.encode(indices), w, h, job.delayCs));
      job.port.send(['progress', (f + 1) / total]);
    }
    file.writeByteSync(0x3B); // trailer
    file.closeSync();
    file = null;
    job.port.send(['done']);
  } catch (e) {
    try {
      file?.closeSync();
    } catch (_) {}
    job.port.send(['error', e.toString()]);
  }
}

Uint8List _readFrame(String path) {
  final bytes = zlib.decode(File(path).readAsBytesSync());
  return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
}

int _clamp(int v) => v < 0 ? 0 : (v > 255 ? 255 : v);

/// 15-bit colour (5 bits per channel) used for the histogram and the lookup.
int _key(int r, int g, int b) => ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3);

/// Median cut: splits the colours that occur into 256 boxes of similar colours
/// (always the box with most pixels and widest spread) and writes the average of
/// each box into [palette]. Returns how many colours the palette has.
int _medianCut(Uint32List histogram, Uint8List palette) {
  final order = <int>[];
  for (var k = 0; k < 32768; k++) {
    if (histogram[k] > 0) order.add(k);
  }
  if (order.isEmpty) return 1;
  final boxes = <List<int>>[
    [0, order.length],
  ];
  while (boxes.length < 256) {
    var best = -1;
    var bestScore = -1.0;
    var bestShift = 0;
    var bestPopulation = 0;
    for (var n = 0; n < boxes.length; n++) {
      final lo = boxes[n][0];
      final hi = boxes[n][1];
      if (hi - lo < 2) continue;
      var rMin = 31, rMax = 0, gMin = 31, gMax = 0, bMin = 31, bMax = 0;
      var population = 0;
      for (var j = lo; j < hi; j++) {
        final k = order[j];
        final r = (k >> 10) & 31, g = (k >> 5) & 31, b = k & 31;
        if (r < rMin) rMin = r;
        if (r > rMax) rMax = r;
        if (g < gMin) gMin = g;
        if (g > gMax) gMax = g;
        if (b < bMin) bMin = b;
        if (b > bMax) bMax = b;
        population += histogram[k];
      }
      final rRange = rMax - rMin, gRange = gMax - gMin, bRange = bMax - bMin;
      final range = math.max(rRange, math.max(gRange, bRange));
      final score = population * (range + 1.0);
      if (score > bestScore) {
        bestScore = score;
        best = n;
        bestPopulation = population;
        bestShift = (rRange >= gRange && rRange >= bRange)
            ? 10
            : (gRange >= bRange ? 5 : 0);
      }
    }
    if (best < 0) break;
    final lo = boxes[best][0];
    final hi = boxes[best][1];
    final part = order.sublist(lo, hi)
      ..sort((a, b) => ((a >> bestShift) & 31) - ((b >> bestShift) & 31));
    order.setRange(lo, hi, part);
    var seen = 0;
    var mid = lo + 1;
    for (var j = lo; j < hi - 1; j++) {
      seen += histogram[order[j]];
      mid = j + 1;
      if (seen * 2 >= bestPopulation) break;
    }
    boxes[best] = [lo, mid];
    boxes.add([mid, hi]);
  }
  for (var n = 0; n < boxes.length; n++) {
    var sumR = 0, sumG = 0, sumB = 0, population = 0;
    for (var j = boxes[n][0]; j < boxes[n][1]; j++) {
      final k = order[j];
      final c = histogram[k];
      sumR += ((k >> 10) & 31) * c;
      sumG += ((k >> 5) & 31) * c;
      sumB += (k & 31) * c;
      population += c;
    }
    palette[n * 3] = (sumR * 255 / (31 * population)).round();
    palette[n * 3 + 1] = (sumG * 255 / (31 * population)).round();
    palette[n * 3 + 2] = (sumB * 255 / (31 * population)).round();
  }
  return boxes.length;
}

/// For every 15-bit colour, the nearest of the first [colors] palette entries.
Uint8List _nearestTable(Uint8List palette, int colors) {
  final table = Uint8List(32768);
  for (var k = 0; k < 32768; k++) {
    final r = ((k >> 10) & 31) * 255 ~/ 31;
    final g = ((k >> 5) & 31) * 255 ~/ 31;
    final b = (k & 31) * 255 ~/ 31;
    var best = 0;
    var bestDistance = 1 << 30;
    for (var c = 0; c < colors; c++) {
      final dr = r - palette[c * 3];
      final dg = g - palette[c * 3 + 1];
      final db = b - palette[c * 3 + 2];
      // Green counts most, blue least, like the eye does.
      final d = dr * dr * 3 + dg * dg * 4 + db * db * 2;
      if (d < bestDistance) {
        bestDistance = d;
        best = c;
      }
    }
    table[k] = best;
  }
  return table;
}

Uint8List _header(int w, int h, Uint8List palette) {
  final b = BytesBuilder(copy: false);
  b.add('GIF89a'.codeUnits);
  b.add([w & 255, w >> 8, h & 255, h >> 8]);
  b.add([0xF7, 0, 0]); // global palette of 256 colours
  b.add(palette);
  // Loop forever.
  b.add([0x21, 0xFF, 0x0B]);
  b.add('NETSCAPE2.0'.codeUnits);
  b.add([0x03, 0x01, 0x00, 0x00, 0x00]);
  return b.takeBytes();
}

Uint8List _frame(Uint8List lzw, int w, int h, int delayCs) {
  final b = BytesBuilder(copy: false);
  b.add([0x21, 0xF9, 0x04, 0x04, delayCs & 255, delayCs >> 8, 0, 0]);
  b.add([0x2C, 0, 0, 0, 0, w & 255, w >> 8, h & 255, h >> 8, 0]);
  b.addByte(8); // minimum code size
  for (var i = 0; i < lzw.length; i += 255) {
    final n = math.min(255, lzw.length - i);
    b.addByte(n);
    b.add(Uint8List.sublistView(lzw, i, i + n));
  }
  b.addByte(0);
  return b.takeBytes();
}

/// GIF flavour of LZW (variable code size from 9 to 12 bits).
class _Lzw {
  static const _clear = 256;
  static const _end = 257;

  final Int32List _keys = Int32List(8192);
  final Int32List _values = Int32List(8192);
  Uint8List _out = Uint8List(0);
  int _len = 0;
  int _bitBuf = 0;
  int _bitCount = 0;
  int _nBits = 9;
  int _maxCode = 511;
  int _free = 258;
  bool _clearFlag = false;

  Uint8List encode(Uint8List data) {
    if (_out.length < data.length * 2 + 1024) _out = Uint8List(data.length * 2 + 1024);
    _len = 0;
    _bitBuf = 0;
    _bitCount = 0;
    _nBits = 9;
    _maxCode = 511;
    _free = 258;
    _clearFlag = false;
    _keys.fillRange(0, _keys.length, -1);
    _output(_clear);
    var ent = data[0];
    for (var i = 1; i < data.length; i++) {
      final c = data[i];
      final key = (ent << 8) | c;
      var h = ((key * 2654435761) >> 13) & 8191;
      var found = -1;
      while (true) {
        final k = _keys[h];
        if (k == -1) break;
        if (k == key) {
          found = _values[h];
          break;
        }
        h = (h + 1) & 8191;
      }
      if (found >= 0) {
        ent = found;
        continue;
      }
      _output(ent);
      ent = c;
      if (_free < 4096) {
        _keys[h] = key;
        _values[h] = _free++;
      } else {
        _keys.fillRange(0, _keys.length, -1);
        _free = 258;
        _clearFlag = true;
        _output(_clear);
      }
    }
    _output(ent);
    _output(_end);
    if (_bitCount > 0) _out[_len++] = _bitBuf & 255;
    return Uint8List.sublistView(_out, 0, _len);
  }

  void _output(int code) {
    _bitBuf |= code << _bitCount;
    _bitCount += _nBits;
    while (_bitCount >= 8) {
      _out[_len++] = _bitBuf & 255;
      _bitBuf >>= 8;
      _bitCount -= 8;
    }
    if (_free > _maxCode || _clearFlag) {
      if (_clearFlag) {
        _nBits = 9;
        _maxCode = 511;
        _clearFlag = false;
      } else {
        _nBits++;
        _maxCode = _nBits == 12 ? 4096 : (1 << _nBits) - 1;
      }
    }
  }
}
