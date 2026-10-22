import 'package:flutter/material.dart';

import '../data/models/card_project.dart';
import '../data/repositories/app_store.dart';
import 'canvas/preview_pane.dart';
import 'editor_controller.dart';
import 'export/export_sheet.dart';
import 'panels/fields_panel.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.store, required this.project});

  final AppStore store;
  final CardProject project;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final EditorController _c =
      EditorController(store: widget.store, project: widget.project);

  @override
  void dispose() {
    _c.flush(); // saves and refreshes the home grid
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: _c,
          builder: (_, __) => Text(_c.project.name, overflow: TextOverflow.ellipsis),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export',
            onPressed: () => showExportSheet(context, _c),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: ListenableBuilder(
              listenable: _c,
              builder: (_, __) => PreviewPane(controller: _c),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: FieldsPanel(controller: _c)),
        ],
      ),
    );
  }
}
