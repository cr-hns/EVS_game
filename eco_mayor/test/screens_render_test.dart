// Renders the gameplay screen at real phone/desktop sizes with the real font
// and sprites. Fails on layout overflow. Set SCREENSHOT_DIR to also save PNGs:
//   SCREENSHOT_DIR=/tmp/shots flutter test test/screens_render_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:eco_mayor/controllers/game_controller.dart';
import 'package:eco_mayor/data/buildings_data.dart';
import 'package:eco_mayor/main.dart';
import 'package:eco_mayor/screens/gameplay_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFont() async {
  final loader = FontLoader('PixelifySans')
    ..addFont(rootBundle.load('assets/fonts/PixelifySans.ttf'));
  await loader.load();
  final numbers = FontLoader('Silkscreen')
    ..addFont(rootBundle.load('assets/fonts/Silkscreen-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Silkscreen-Bold.ttf'));
  await numbers.load();
}

Future<void> _settle(WidgetTester tester) async {
  // Let Flame load sprites and Image.asset decode (real async work).
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  final ctx = tester.element(find.byType(Scaffold).first);
  await tester.runAsync(() async {
    for (final b in BuildingsData.all.values) {
      await precacheImage(AssetImage('assets/images/${b.spritePath}'), ctx);
    }
    for (final f in Directory('assets/images/ui').listSync()) {
      await precacheImage(AssetImage(f.path), ctx);
    }
    for (final f in Directory('assets/images/advisors').listSync()) {
      await precacheImage(AssetImage(f.path), ctx);
    }
    await precacheImage(const AssetImage('assets/images/misc/logo.png'), ctx);
    await precacheImage(const AssetImage('assets/images/misc/splash_bg.png'), ctx);
  });
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _snap(WidgetTester tester, GlobalKey key, String name) async {
  final dir = Platform.environment['SCREENSHOT_DIR'];
  if (dir == null) return;
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.8);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFont);

  const sizes = {
    'phone': Size(384, 832), // Samsung M17 logical size
    'desktop': Size(1280, 720), // default Windows window
  };

  for (final entry in sizes.entries) {
    testWidgets('gameplay renders without overflow on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      final controller = GameController()..startNewGame('Eco City', 'medium');
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(brightness: Brightness.dark, fontFamily: 'PixelifySans'),
          home: GameplayScreen(controller: controller),
        ),
      ));
      await _settle(tester);
      await _snap(tester, key, '${entry.key}_idle');

      // Select a building, show an advisor, and check again.
      controller.selectBuilding(BuildingsData.all['solar_farm']);
      controller.endDay();
      await tester.pump(const Duration(milliseconds: 300));
      await _settle(tester);
      await _snap(tester, key, '${entry.key}_selected');
      expect(tester.takeException(), isNull);
    });
  }

  for (final entry in sizes.entries) {
    testWidgets('main menu pages render on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: const EcoMayorApp()));
      await _settle(tester);
      await _snap(tester, key, '${entry.key}_menu');

      Future<void> open(String button, String shot) async {
        await tester.tap(find.text(button));
        await tester.pump(const Duration(milliseconds: 400));
        await _settle(tester);
        await _snap(tester, key, '${entry.key}_$shot');
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('BACK'));
        await tester.pump(const Duration(milliseconds: 400));
      }

      await open('PLAY', 'menu_play');
      await open('HOW TO PLAY', 'menu_help');
      await open('ABOUT & SDGs', 'menu_about');
      expect(tester.takeException(), isNull);
    });
  }
}
