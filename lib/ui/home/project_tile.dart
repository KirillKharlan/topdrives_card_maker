import 'package:flutter/material.dart';

import '../../data/models/card_project.dart';
import '../../data/repositories/app_store.dart';
import '../../editor/canvas/card_view.dart';
import '../../editor/editor_screen.dart';
import '../common/dialogs.dart';

class ProjectTile extends StatelessWidget {
  const ProjectTile({super.key, required this.store, required this.project});

  final AppStore store;
  final CardProject project;

  void _open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(store: store, project: project)),
    );
  }

  Future<void> _menu(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Duplicate'),
              onTap: () {
                Navigator.pop(sheetContext);
                store.projects.duplicate(project);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete card'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final ok = await confirmDialog(
                  context,
                  title: 'Delete card?',
                  message: '"${project.name}" will be removed. Library images are kept.',
                );
                if (ok) await store.projects.delete(project.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final template = store.templateFor(project);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        onLongPress: () => _menu(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: FittedBox(
                  child: IgnorePointer(
                    child: CardView(
                      project: project,
                      template: template,
                      photoFile: store.photos.fileOf(project.photoId),
                      logoFile: store.logos.fileOf(project.logoId),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
