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

/// State of the card being edited. All changes go through [update], which
/// repaints the preview and schedules an autosave.
class EditorController extends ChangeNotifier {
  EditorController({required this.store, required this.project})
      : template = store.templateFor(project);

  final AppStore store;
  final CardProject project;
  final TemplateSpec template;

  final cardKey = GlobalKey();
  final fullKey = GlobalKey();

  Timer? _saveTimer;
  double _gestureStartScale = 1;
  double _gestureStartRotation = 0;

  /// The photo, or for a video card the still frame of the video.
  File? get photoFile => store.photoFileFor(project);
  File? get videoFile => store.videos.fileOf(project.videoId);

  /// True while the card is captured as a picture: the live video is left out.
  bool videoHidden = false;
  File? get logoFile => store.logos.fileOf(project.logoId);

  /// The content-aware fill picture, if it exists and matches the framing.
  File? get smartFillFile => store.smartFillFor(project);

  bool generatingFill = false;

  bool get hasGeneratedFill => project.fillFileName != null;

  bool get fillIsCurrent => smartFillFile != null;

  void update(void Function(CardProject p) change) {
    change(project);
    project.updatedAt = DateTime.now();
    notifyListeners();
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
  }

  /// [scaleFactor] and [rotation] are relative to the start of the gesture,
  /// [delta] is the finger movement since the last update (screen pixels).
  void gestureUpdate(double scaleFactor, double rotation, Offset delta, double displayScale) {
    if (!project.hasMedia) return;
    update((p) {
      final t = p.photoTransform;
      p.photoTransform = PhotoTransform(
        scale: _gestureStartScale * scaleFactor,
        dx: t.dx + delta.dx / displayScale / template.width,
        dy: t.dy + delta.dy / displayScale / template.height,
        rotation: _gestureStartRotation + rotation,
      ).clamped();
    });
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    await store.projects.save(project);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}

/// Degrees <-> radians helpers for the rotation slider.
double radiansToDegrees(double radians) => radians * 180 / math.pi;
double degreesToRadians(double degrees) => degrees * math.pi / 180;
