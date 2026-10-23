import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../templates/template_registry.dart';
import '../../templates/template_spec.dart';
import '../models/card_project.dart';
import 'media_library.dart';
import 'project_repository.dart';
import 'settings_repository.dart';

/// Single entry point to everything stored on the device.
class AppStore {
  AppStore._();

  final photos = MediaLibrary('photos');
  final logos = MediaLibrary('logos');
  final projects = ProjectRepository();
  final settings = SettingsRepository();
  final Map<String, TemplateSpec> templates = {};

  /// [onStep] reports what is being loaded, so a stuck start-up can be located.
  static Future<AppStore> open({void Function(String step)? onStep}) async {
    void step(String text) => onStep?.call(text);

    final store = AppStore._();
    step('Opening app storage…');
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory('${docs.path}/card_maker');
    await root.create(recursive: true);
    step('Loading car photos…');
    await store.photos.init(root);
    step('Loading logos…');
    await store.logos.init(root);
    step('Loading cards…');
    await store.projects.init(root);
    step('Loading settings…');
    await store.settings.init(root);
    step('Loading templates…');
    store.templates.addAll(await TemplateRegistry.loadAll());
    return store;
  }

  TemplateSpec templateFor(CardProject project) =>
      templates[project.templateId] ?? templates.values.first;

  Future<void> deletePhoto(String id) async {
    await projects.detachPhoto(id);
    await photos.delete(id);
  }

  Future<void> deleteLogo(String id) async {
    await projects.detachLogo(id);
    await logos.delete(id);
  }
}
