import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../data/models/card_project.dart';
import '../data/models/card_style.dart';
import '../data/models/photo_fill.dart';
import '../data/models/photo_transform.dart';
import '../data/repositories/app_store.dart';
import '../photo_fill/fill_service.dart';
import '../templates/template_spec.dart';
import '../video/video_frames.dart';
import 'photo_move_mode.dart';

/// State of the card being edited. All changes go through [update], which
/// repaints the preview and schedules an autosave.
/// Tells only the card preview that something changed (used while a finger moves
/// the photo: rebuilding the whole form under the card on every frame is wasted work).
class PreviewTick extends ChangeNotifier {
  void ping() => notifyListeners();
}

class EditorController extends ChangeNotifier {
  EditorController({required this.store, required this.project});

  final AppStore store;
  final CardProject project;

  /// The template of the card; it changes when the person picks another one.
  TemplateSpec get template => store.templateFor(project);

  final cardKey = GlobalKey();
  final fullKey = GlobalKey();

  Timer? _saveTimer;
  double _gestureStartScale = 1;
  double _gestureStartRotation = 0;

  /// How a drag moves the photo (not saved with the card: a working tool).
  PhotoMoveMode moveMode = PhotoMoveMode.free;

  /// Finger travel (screen pixels) after which [PhotoMoveMode.auto] picks an axis.
  static const double axisLockDistance = 12;

  /// Movement collected before the axis was chosen, and the chosen axis.
  Offset _dragTotal = Offset.zero;
  Axis? _lockedAxis;

  void setMoveMode(PhotoMoveMode mode) {
    moveMode = mode;
    notifyListeners();
  }

  /// The photo, or for a video card the still frame of the video.
  File? get photoFile => exportFrame ?? store.photoFileFor(project);
  File? get videoFile => store.videos.fileOf(project.videoId);

  /// True while the card is captured as a picture: the live video is left out.
  bool videoHidden = false;

  /// Width the photo is decoded at. It never changes while the app runs: switching it right
  /// before a capture (v13 tried 4096) made the exported picture come out with a corrupted
  /// block in the top-left corner (garbage pixels, black rectangle).
  final int photoDecodeWidth = 2600;

  /// Runs [action] (a capture of the card) once the card has been drawn in a settled frame.
  /// The photo keeps the decode that the editor already shows.
  Future<T> withSharpPhoto<T>(BuildContext context, Future<T> Function() action) async {
    await WidgetsBinding.instance.endOfFrame;
    return action();
  }

  /// While a video is exported: the frame of the video shown in place of the photo.
  File? exportFrame;

  void setExportFrame(File? frame) {
    exportFrame = frame;
    notifyListeners();
  }
  File? get logoFile => store.logos.fileOf(project.logoId);

  /// The content-aware fill picture, if it exists and matches the framing.
  File? get smartFillFile => store.smartFillFor(project);

  bool generatingFill = false;

  bool get hasGeneratedFill => project.fillFileName != null;

  bool get fillIsCurrent => smartFillFile != null;

  /// Notifies everything that listens (the form too), or with [form] false only the card preview.
  final PreviewTick previewTick = PreviewTick();

  void update(void Function(CardProject p) change, {bool form = true}) {
    change(project);
    project.updatedAt = DateTime.now();
    if (form) {
      notifyListeners();
    } else {
      previewTick.ping();
    }
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 600),
      () => store.projects.save(project, notify: false),
    );
  }

  // ---- photo ----
  /// Replace or remove (null) the photo; the framing is reset because a new
  /// photo has different proportions.
  void setPhoto(String? id) {
    final oldFill = project.fillFileName;
    final oldVideo = project.videoId;
    update((p) {
      p.photoId = id;
      p.videoId = null;
      p.photoTransform = PhotoTransform.identity;
      p.fillFileName = null;
      p.fillSignature = null;
    });
    store.fills.delete(oldFill); // belonged to the previous photo
    store.releaseVideo(oldVideo);
  }

  /// Puts a video (already in the library, with its still frame at 0 ms) in
  /// place of the photo. A moving picture cannot use the content-aware fill.
  void setVideo(String id, {required int durationMs}) {
    final oldFill = project.fillFileName;
    final oldVideo = project.videoId;
    update((p) {
      p.videoId = id;
      p.photoId = null;
      p.photoTransform = PhotoTransform.identity;
      p.fillFileName = null;
      p.fillSignature = null;
      if (p.photoFill == PhotoFill.smart) p.photoFill = PhotoFill.mirror;
      p.videoDurationMs = durationMs;
      p.videoStartMs = 0;
      p.videoPosterMs = 0;
      p.videoLengthMs = math.min(CardProject.defaultVideoLengthMs, durationMs);
    });
    store.fills.delete(oldFill);
    if (oldVideo != id) store.releaseVideo(oldVideo);
  }

  /// Chooses the part of the video that plays (at most 10 s).
  void setVideoClip({int? startMs, int? lengthMs}) => update((p) {
        final duration = p.videoDurationMs;
        final shortest = math.min(CardProject.minVideoLengthMs, duration);
        final longest = math.min(CardProject.maxVideoLengthMs, duration);
        final length = (lengthMs ?? p.videoLengthMs).clamp(shortest, longest).toInt();
        final latestStart = math.max(0, duration - length);
        p.videoLengthMs = length;
        p.videoStartMs = (startMs ?? p.videoStartMs).clamp(0, latestStart).toInt();
      });

  /// Makes the still frame match the clip's start (call when the start stops
  /// changing). The new frame is a new file, so the picture cache never shows
  /// the old one.
  Future<void> refreshVideoPoster() async {
    final id = project.videoId;
    final video = videoFile;
    if (id == null || video == null) return;
    final start = project.videoStartMs;
    final previous = project.videoPosterMs;
    if (start == previous) return;
    final out = store.videos.sideFile(id, '.poster-$start.jpg')!;
    try {
      await VideoFrames.extract(video: video, timeMs: start, out: out);
    } catch (_) {
      return;
    }
    if (project.videoId != id) {
      if (await out.exists()) await out.delete();
      return;
    }
    update((p) => p.videoPosterMs = start);
    final old = store.videos.sideFile(id, '.poster-$previous.jpg');
    if (old != null && old.path != out.path && await old.exists()) await old.delete();
  }

  /// Runs [action] (a capture of the card) without the live video on screen.
  Future<T> withoutVideo<T>(Future<T> Function() action) async {
    if (!project.hasVideo) return action();
    videoHidden = true;
    notifyListeners();
    await WidgetsBinding.instance.endOfFrame;
    try {
      return await action();
    } finally {
      videoHidden = false;
      notifyListeners();
    }
  }

  /// A different logo has different proportions, so its size is reset.
  void setLogo(String? id) => update((p) {
        p.logoId = id;
        p.logoScale = 1.0;
        p.logoDx = 0.0;
        p.logoDy = 0.0;
      });

  void setLogoScale(double scale) => update((p) => p.logoScale = scale);

  /// Shifts the logo inside its slot by fractions of the slot size.
  void moveLogoBy(double dx, double dy) => update((p) {
        p.logoDx = (p.logoDx + dx).clamp(-0.6, 0.6).toDouble();
        p.logoDy = (p.logoDy + dy).clamp(-0.6, 0.6).toDouble();
      });

  void resetLogoFraming() => update((p) {
        p.logoScale = 1.0;
        p.logoDx = 0.0;
        p.logoDy = 0.0;
      });

  void setBrandScale(double v) => update((p) => p.brandScale = v);
  void setModelScale(double v) => update((p) => p.modelScale = v);
  void setCardStyle(CardStyle style) => update((p) => p.cardStyle = style);
  void setTemplate(String id) => update((p) => p.templateId = id);
  void setYearScale(double v) => update((p) => p.yearScale = v);
  void setTagScale(double v) => update((p) => p.tagScale = v);

  void setPhotoScale(double scale) =>
      update((p) => p.photoTransform = p.photoTransform.copyWith(scale: scale).clamped());

  void setPhotoRotation(double radians) =>
      update((p) => p.photoTransform = p.photoTransform.copyWith(rotation: radians).clamped());

  void rotatePhotoBy(double radians) => update((p) {
        p.photoTransform =
            p.photoTransform.copyWith(rotation: p.photoTransform.rotation + radians).clamped();
      });

  void setPhotoFill(PhotoFill fill) => update((p) => p.photoFill = fill);

  void resetPhotoTransform() => update((p) => p.photoTransform = PhotoTransform.identity);

  /// Puts the photo back at the centre of the card; zoom and rotation stay as they are.
  void resetPhotoPosition() =>
      update((p) => p.photoTransform = p.photoTransform.copyWith(dx: 0, dy: 0));

  /// Sets the photo position exactly (fractions of the card width / height).
  /// A value very close to the centre snaps to 0, so the centre is easy to hit.
  void setPhotoShift({double? dx, double? dy}) => update((p) {
        double snap(double v) => v.abs() < 0.01 ? 0.0 : v;
        p.photoTransform = p.photoTransform
            .copyWith(dx: dx == null ? null : snap(dx), dy: dy == null ? null : snap(dy))
            .clamped();
      });

  /// Moves the photo by a small step along one axis (the arrow buttons).
  void nudgePhoto({double dx = 0, double dy = 0}) => update((p) {
        double round4(double v) => (v * 10000).round() / 10000;
        final t = p.photoTransform;
        p.photoTransform =
            t.copyWith(dx: round4(t.dx + dx), dy: round4(t.dy + dy)).clamped();
      });

  /// Builds the content-aware fill for the current framing (takes a few seconds).
  /// Returns a message for the user.
  Future<String> generateSmartFill() async {
    if (project.hasVideo) return 'Content-aware fill is not available for video.';
    final file = photoFile;
    if (file == null) return 'Choose a photo first.';
    generatingFill = true;
    notifyListeners();
    try {
      final signature = project.fillSignatureNow;
      final outcome = await FillService.generate(
        photo: file,
        transform: project.photoTransform,
        cardWidth: template.width,
        cardHeight: template.height,
      );
      final png = outcome.png;
      if (png == null) return outcome.message ?? 'Nothing was generated.';
      final name = await store.fills.save(project.id, png, replacing: project.fillFileName);
      update((p) {
        p.photoFill = PhotoFill.smart;
        p.fillFileName = name;
        p.fillSignature = signature;
      });
      return 'Fill generated.';
    } catch (e) {
      return 'Fill failed: $e';
    } finally {
      generatingFill = false;
      notifyListeners();
    }
  }

  void gestureStart() {
    _gestureStartScale = project.photoTransform.scale;
    _gestureStartRotation = project.photoTransform.rotation;
    _dragTotal = Offset.zero;
    _lockedAxis = null;
  }

  /// The part of the finger movement [delta] that is allowed by [moveMode].
  Offset _allowedMovement(Offset delta) {
    switch (moveMode) {
      case PhotoMoveMode.free:
        return delta;
      case PhotoMoveMode.horizontal:
        return Offset(delta.dx, 0);
      case PhotoMoveMode.vertical:
        return Offset(0, delta.dy);
      case PhotoMoveMode.auto:
        if (_lockedAxis == null) {
          _dragTotal += delta;
          if (_dragTotal.distance < axisLockDistance) return Offset.zero;
          _lockedAxis =
              _dragTotal.dx.abs() >= _dragTotal.dy.abs() ? Axis.horizontal : Axis.vertical;
          delta = _dragTotal; // catch up with what was held back
        }
        return _lockedAxis == Axis.horizontal ? Offset(delta.dx, 0) : Offset(0, delta.dy);
    }
  }

  /// [scaleFactor] and [rotation] are relative to the start of the gesture,
  /// [delta] is the finger movement since the last update (screen pixels).
  void gestureUpdate(double scaleFactor, double rotation, Offset delta, double displayScale) {
    if (!project.hasMedia) return;
    final move = _allowedMovement(delta);
    update((p) {
      final t = p.photoTransform;
      p.photoTransform = PhotoTransform(
        scale: _gestureStartScale * scaleFactor,
        dx: t.dx + move.dx / displayScale / template.width,
        dy: t.dy + move.dy / displayScale / template.height,
        rotation: _gestureStartRotation + rotation,
      ).clamped();
    }, form: false);
  }

  /// The finger is lifted: now the sliders of the form catch up with the framing.
  void gestureEnd() => notifyListeners();

  Future<void> flush() async {
    _saveTimer?.cancel();
    await store.projects.save(project);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    previewTick.dispose();
    super.dispose();
  }
}

/// Degrees <-> radians helpers for the rotation slider.
double radiansToDegrees(double radians) => radians * 180 / math.pi;
double degreesToRadians(double degrees) => degrees * math.pi / 180;
