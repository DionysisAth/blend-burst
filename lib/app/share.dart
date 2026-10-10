import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Shares a screenshot of the widget under [key] (a RepaintBoundary) with
/// the system share sheet. Never throws.
Future<void> shareScreenshot(GlobalKey key, String text) async {
  try {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderRepaintBoundary) return;
    final image = await box.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) return;
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        files: [
          XFile.fromData(
            data.buffer.asUint8List(),
            mimeType: 'image/png',
            name: 'blend-burst.png',
          ),
        ],
        fileNameOverrides: const ['blend-burst.png'],
      ),
    );
  } catch (e) {
    debugPrint('Share failed: $e');
  }
}
