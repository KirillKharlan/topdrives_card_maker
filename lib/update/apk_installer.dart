import 'dart:io';

import 'package:flutter/services.dart';

/// What happened when the installer was asked to open the downloaded APK.
enum InstallOutcome {
  /// The system installer screen was opened.
  started,

  /// Android first needs the "install unknown apps" permission for this app;
  /// its settings page was opened. Ask again after the person allowed it.
  needsPermission,
}

/// Opens the system package installer for a downloaded APK. The Kotlin side
/// (channel "card_maker/update") is written by tool/patch_android.py.
class ApkInstaller {
  ApkInstaller._();

  static const _channel = MethodChannel('card_maker/update');

  static Future<InstallOutcome> install(File apk) async {
    final answer = await _channel.invokeMethod<String>('install', {'path': apk.path});
    return answer == 'permission' ? InstallOutcome.needsPermission : InstallOutcome.started;
  }
}
