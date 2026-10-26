import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../data/models/card_project.dart';
import '../data/models/photo_fill.dart';
import '../data/models/photo_transform.dart';
import '../data/repositories/app_store.dart';
import '../photo_fill/fill_service.dart';
import '../templates/template_spec.dart';

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

  File? get photoFile => store.photos.fileOf(project.photoId);
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
    update((p) {
      p.photoId = id;
      p.photoTransform = PhotoTransform.identity;
      p.fillFileName = null;
      p.fillSignature = null;
    });
    store.fills.delete(oldFill); // belonged to the previous photo
  }

  /// A different logo has different proportions, so its size is reset.
  void setLogo(String? id) => update((p) {
        p.logoId = id;
        p.logoScale = 1.0;
      });

  void setLogoScale(double scale) => update((p) => p.logoScale = scale);

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
    final file = photoFile;
    if (file == null) return 'Choose a photo first.';
    generatingFill = true;
    notifyListeners();
    try {
      final signature = project.fillSignatureNow;
      final outcome = await FillService.generate(
        file: file,
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
    if (project.photoId == null) return;
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
