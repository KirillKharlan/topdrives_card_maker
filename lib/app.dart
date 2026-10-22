import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'data/repositories/app_store.dart';
import 'ui/home/home_screen.dart';

class CardMakerApp extends StatelessWidget {
  const CardMakerApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Card Maker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: HomeScreen(store: store),
    );
  }
}
