import 'package:flutter/material.dart';

import 'app.dart';
import 'data/repositories/app_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.open();
  runApp(CardMakerApp(store: store));
}
