import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:onnxruntime_v2/onnxruntime_v2.dart';

import 'lama_fill.dart';

/// Fills the empty areas of the card with LaMa. Heavy: run it in a background isolate,
/// `Isolate.run(() => runLamaFill(job))`. Returns the card (opaque RGBA, [LamaJob.fullWidth]
/// x [LamaJob.fullHeight]). Everything of the model is released before it returns.
Future<Uint8List> runLamaFill(LamaJob job) async {
  final inputs = lamaPrepareInputs(job.workRgba, job.workWidth, job.workHeight);
  final out = await _infer(job.modelPath, inputs);
  final rgb = lamaCropOutput(out, job.workWidth, job.workHeight);
  return lamaCompose(
    lamaRgb: rgb,
    workWidth: job.workWidth,
    workHeight: job.workHeight,
    fullRgba: job.fullRgba,
    fullWidth: job.fullWidth,
    fullHeight: job.fullHeight,
  );
}

/// The model's output as a flat list of 3 * 512 * 512 numbers (0..255).
Future<Float32List> _infer(String modelPath, LamaInputs inputs) async {
  const s = lamaSize;
  OrtEnv.instance.init();
  OrtSessionOptions? options;
  OrtSession? session;
  OrtRunOptions? runOptions;
  OrtValueTensor? image;
  OrtValueTensor? mask;
  List<OrtValue?>? outputs;
  try {
    options = OrtSessionOptions()
      ..setIntraOpNumThreads(math.max(1, math.min(4, Platform.numberOfProcessors)));
    session = OrtSession.fromFile(File(modelPath), options);
    runOptions = OrtRunOptions();
    image = OrtValueTensor.createTensorWithDataList(inputs.image, [1, 3, s, s]);
    mask = OrtValueTensor.createTensorWithDataList(inputs.mask, [1, 1, s, s]);
    final names = session.inputNames;
    final imageName = names.contains('image') ? 'image' : names.first;
    final maskName = names.contains('mask') ? 'mask' : names.last;
    outputs = session.run(runOptions, {imageName: image, maskName: mask});
    final value = outputs.isEmpty ? null : outputs.first?.value;
    final flat = Float32List(3 * s * s);
    final count = _flatten(value, flat, 0);
    if (count != flat.length) {
      throw StateError('the model gave $count numbers, expected ${flat.length}');
    }
    return flat;
  } finally {
    void quietly(void Function() f) {
      try {
        f();
      } catch (_) {}
    }

    quietly(() => image?.release());
    quietly(() => mask?.release());
    quietly(() => runOptions?.release());
    for (final o in outputs ?? const <OrtValue?>[]) {
      quietly(() => o?.release());
    }
    try {
      await session?.release();
    } catch (_) {}
    quietly(() => options?.release());
    quietly(() => OrtEnv.instance.release());
  }
}

/// Copies the nested lists the plugin returns ([1][3][512][512]) into [out]; returns how many numbers it found.
int _flatten(dynamic value, Float32List out, int at) {
  if (value is num) {
    if (at < out.length) out[at] = value.toDouble();
    return at + 1;
  }
  if (value is List) {
    var pos = at;
    for (final item in value) {
      pos = _flatten(item, out, pos);
    }
    return pos;
  }
  return at;
}
