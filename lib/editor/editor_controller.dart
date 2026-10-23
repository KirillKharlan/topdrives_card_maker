import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../data/models/card_project.dart';
import '../data/models/photo_transform.dart';
import '../data/repositories/app_store.dart';
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

  File? get photoFile => store.photos.fileOf(project.photoId);
  File? get logoFile => store.logos.fileOf(project.logoId);

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
  /// Replace or remove (null) the photo; the crop is reset because a new
  /// photo has different proportions.
  void setPhoto(String? id) => update((p) {
        p.photoId = id;
        p.photoTransform = PhotoTransform.identity;
      });

  /// A different logo has different proportions, so its size is reset.
  void setLogo(String? id) => update((p) {
        p.logoId = id;
        p.logoScale = 1.0;
      });

  void setLogoScale(double scale) => update((p) => p.logoScale = scale);

  void setPhotoScale(double scale) => update((p) {
        final t = p.photoTransform;
        p.photoTransform = PhotoTransform(scale: scale, dx: t.dx, dy: t.dy).clamped();
      });

  void resetPhotoTransform() => update((p) => p.photoTransform = PhotoTransform.identity);

  void gestureStart() => _gestureStartScale = project.photoTransform.scale;

  void gestureUpdate(double scaleFactor, Offset delta, double displayScale) {
    if (project.photoId == null) return;
    update((p) {
      final t = p.photoTransform;
      p.photoTransform = PhotoTransform(
        scale: _gestureStartScale * scaleFactor,
        dx: t.dx + delta.dx / displayScale / template.width,
        dy: t.dy + delta.dy / displayScale / template.height,
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
