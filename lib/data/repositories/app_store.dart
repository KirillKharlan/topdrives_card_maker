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

  static Future<AppStore> open() async {
    final store = AppStore._();
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory('${docs.path}/card_maker');
    await root.create(recursive: true);
    await store.photos.init(root);
    await store.logos.init(root);
    await store.projects.init(root);
    await store.settings.init(root);
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
