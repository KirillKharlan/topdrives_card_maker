import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_theme.dart';
import 'data/repositories/app_store.dart';

/// Shows something on screen immediately (instead of a black screen) while the
/// local storage is opened, and prints the error text if start-up fails.
class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  AppStore? _store;
  Object? _error;
  StackTrace? _stack;
  String _step = 'Starting…';
  bool _slow = false;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _error = null;
      _stack = null;
      _slow = false;
      _step = 'Starting…';
    });
    _start();
  }

  Future<void> _start() async {
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && _store == null && _error == null) setState(() => _slow = true);
    });
    try {
      final store = await AppStore.open(onStep: (text) {
        if (mounted) setState(() => _step = text);
      });
      if (!mounted) return;
      setState(() => _store = store);
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _stack = st;
      });
    } finally {
      _slowTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    if (store != null) return CardMakerApp(store: store);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _error != null ? _errorView(context) : _loadingView(context),
          ),
        ),
      ),
    );
  }

  Widget _loadingView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(_step),
          if (_slow) ...[
            const SizedBox(height: 12),
            Text(
              'This takes longer than usual. If it never finishes, '
              'tell the developer which step is shown above.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Start-up failed', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('Step: $_step'),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(child: SelectableText('$_error\n\n$_stack')),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _retry, child: const Text('Retry')),
      ],
    );
  }
}
