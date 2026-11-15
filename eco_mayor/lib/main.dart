import 'package:flutter/material.dart';
import 'screens/gameplay_screen.dart';
import 'controllers/game_controller.dart';

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
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF1E242B),
      ),
      home: const MainMenuScreen(),
    );
  }
}

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/misc/splash_bg.png',
            fit: BoxFit.cover,
          ),
          Container(
            color: Colors.black.withOpacity(0.65),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/misc/logo.png',
                      width: 140,
                      height: 140,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'ECO MAYOR',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: Colors.greenAccent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Environmental City Simulation',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 36),
                    _difficultyButton(context, '🌿 Easy Mode', 'easy', Colors.green),
                    const SizedBox(height: 12),
                    _difficultyButton(context, '⚖️ Medium Mode', 'medium', Colors.amber),
                    const SizedBox(height: 12),
                    _difficultyButton(context, '🔥 Hard Mode', 'hard', Colors.redAccent),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _difficultyButton(BuildContext context, String label, String diff, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.2),
          foregroundColor: color,
          side: BorderSide(color: color, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () {
          final controller = GameController();
          controller.startNewGame('Eco City', diff);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GameplayScreen(controller: controller),
            ),
          );
        },
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
