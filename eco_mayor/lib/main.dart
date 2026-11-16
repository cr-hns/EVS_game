import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import 'platform/window_control.dart';
import 'screens/main_menu_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WindowControl.installKeyboardShortcuts();
  runApp(const EcoMayorApp());
}

class EcoMayorApp extends StatelessWidget {
  const EcoMayorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoMayor: Clean City Simulation',
      debugShowCheckedModeBanner: false,
      // Let lists be dragged with mouse, pen and touch alike (Windows board).
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: PointerDeviceKind.values.toSet(),
      ),
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'PixelifySans',
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF1E242B),
      ),
      home: const MainMenuScreen(),
    );
  }
}
