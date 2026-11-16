import 'package:flutter/material.dart';

import 'screens/main_menu_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EcoMayorApp());
}

class EcoMayorApp extends StatelessWidget {
  const EcoMayorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoMayor: Clean City Simulation',
      debugShowCheckedModeBanner: false,
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
