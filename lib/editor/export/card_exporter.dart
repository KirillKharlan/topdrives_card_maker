import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Turns the on-screen composition into a PNG at the template's native size.
class CardExporter {
  CardExporter._();

  static Future<Uint8List> capture(GlobalKey key, {double pixelRatio = 1.0}) async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  static Future<void> saveToGallery(Uint8List png) async {
    if (!await Gal.hasAccess()) await Gal.requestAccess();
    await Gal.putImageBytes(png);
  }

  static Future<void> share(Uint8List png, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName.png');
    await file.writeAsBytes(png, flush: true);
    await Share.shareXFiles([XFile(file.path)]);
  }
}
