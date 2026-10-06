import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const captureUiEnabled = bool.fromEnvironment('CAPTURE_UI');
Future<void> captureUi(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) async {
  if (!captureUiEnabled) return;
  final originalShadows = debugDisableShadows;
  debugDisableShadows = false;
  final reassemble = tester.binding.reassembleApplication();
  await tester.pump();
  await reassemble;
  await tester.pumpAndSettle();
  try {
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/ui-preview/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  } finally {
    debugDisableShadows = originalShadows;
  }
}

Future<void> loadEnvelopeFonts() async {
  final font = FontLoader('BeVietnamPro');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    font.addFont(rootBundle.load('assets/fonts/BeVietnamPro-$weight.ttf'));
  }
  await font.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}
