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
      // Phones draw the app edge to edge: keep it above the system buttons (and clear of
      // cut-outs at the sides). The status bar is handled by the app bars.
      builder: (context, child) => ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(top: false, child: child ?? const SizedBox.shrink()),
      ),
      home: HomeScreen(store: store),
    );
  }
}
