import 'package:flutter/material.dart';

import '../../data/models/card_project.dart';
import '../../data/repositories/app_store.dart';
import '../../editor/canvas/card_view.dart';
import '../../editor/editor_screen.dart';
import '../../templates/template_spec.dart';
import '../albums/add_to_album_sheet.dart';
import '../common/dialogs.dart';

class ProjectTile extends StatelessWidget {
  const ProjectTile({
    super.key,
    required this.store,
    required this.project,
    this.onTap,
    this.selected = false,
    this.onRemoveFromAlbum,
  });

  final AppStore store;
  final CardProject project;

  /// Replaces opening the editor (used when picking cards for an album).
  final VoidCallback? onTap;

  /// Shows a check mark and a frame (picking mode).
  final bool selected;

  /// When set (inside a user's album) the menu gets "Remove from album".
  final VoidCallback? onRemoveFromAlbum;

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
              leading: const Icon(Icons.collections_bookmark_outlined),
              title: const Text('Add to album'),
              onTap: () {
                Navigator.pop(sheetContext);
                showAddToAlbumSheet(context, store, project);
              },
            ),
            if (onRemoveFromAlbum != null)
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('Remove from album'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onRemoveFromAlbum!();
                },
              ),
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
                if (ok) await store.deleteProject(project);
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
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: selected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: primary, width: 3),
            )
          : null,
      child: InkWell(
        onTap: onTap ?? () => _open(context),
        onLongPress: onTap != null ? null : () => _menu(context),
        child: Stack(
          children: [
            Positioned.fill(child: _content(template)),
            if (selected)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.check_circle, color: primary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _content(TemplateSpec template) {
    return Column(
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
                      photoFile: store.photoFileFor(project),
                      logoFile: store.logos.fileOf(project.logoId),
                      photoMaxWidth: 700,
                      lite: true,
                      fillFile: store.smartFillFor(project),
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
    );
  }
}
