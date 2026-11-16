import 'dart:io' show Platform, exit;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../ui/game_theme.dart';
import 'gameplay_screen.dart';

enum _Page { home, difficulty, howTo, about }

/// Title screen: animated backdrop, bobbing logo and a wooden menu board
/// that switches between the main menu, difficulty select, help and about.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> with TickerProviderStateMixin {
  late final AnimationController _bg = AnimationController(vsync: this, duration: const Duration(seconds: 28))
    ..repeat(reverse: true);
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(seconds: 12))
    ..repeat();
  _Page _page = _Page.home;

  bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  void dispose() {
    _bg.dispose();
    _loop.dispose();
    super.dispose();
  }

  void _go(_Page p) => setState(() => _page = p);

  void _start(String difficulty) {
    final controller = GameController()..startNewGame('Eco City', difficulty);
    Navigator.of(context)
        .push(PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, _, _) => GameplayScreen(controller: controller),
          transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        ))
        .then((_) => _go(_Page.home));
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Slowly drifting poster
          AnimatedBuilder(
            animation: _bg,
            builder: (_, child) {
              final t = Curves.easeInOut.transform(_bg.value);
              return Transform.scale(
                scale: 1.08 + 0.08 * t,
                child: Transform.translate(offset: Offset(-18 + 36 * t, -10 + 20 * t), child: child),
              );
            },
            child: Image.asset('assets/images/misc/splash_bg.png', fit: BoxFit.cover),
          ),
          // Vignette: dark top and bottom, lighter middle
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCC0B120C), Color(0x660B120C), Color(0x880B120C), Color(0xEE0B120C)],
                stops: [0, 0.35, 0.65, 1],
              ),
            ),
          ),
          // Falling leaves
          IgnorePointer(child: CustomPaint(painter: _LeavesPainter(_loop))),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Bobbing logo
                    AnimatedBuilder(
                      animation: _loop,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, math.sin(_loop.value * math.pi * 6) * 5),
                        child: child,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 440, maxHeight: h * 0.2),
                        child: Image.asset('assets/images/misc/logo.png', fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const _Ribbon(text: 'Clean the city. Heal the planet.'),
                    SizedBox(height: h < 700 ? 12 : 22),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: GamePanel(
                        padding: const EdgeInsets.all(12),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, a) => FadeTransition(
                              opacity: a,
                              child: SlideTransition(
                                position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(a),
                                child: child,
                              ),
                            ),
                            child: KeyedSubtree(key: ValueKey(_page), child: _pageBody(h)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const GameText('EVS Mini Project  •  v1.0', size: 11, color: Color(0xFFB9A57A)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageBody(double h) => switch (_page) {
        _Page.home => _home(),
        _Page.difficulty => _difficulty(),
        _Page.howTo => _scrollPage('HOW TO PLAY', _howTo(), h),
        _Page.about => _scrollPage('ABOUT & SDGs', _about(), h),
      };

  // ------------------------------------------------------------------ home

  Widget _home() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PulsingButton(
          onPressed: () => _go(_Page.difficulty),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow_rounded, size: 34, color: Colors.white, shadows: [Shadow(color: GameColors.ink, offset: Offset(2, 2))]),
              SizedBox(width: 6),
              GameText('PLAY', size: 28),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _menuButton('HOW TO PLAY', 'assets/images/ui/icon_happiness.png', () => _go(_Page.howTo)),
        const SizedBox(height: 8),
        _menuButton('ABOUT & SDGs', 'assets/images/ui/icon_soil.png', () => _go(_Page.about)),
        if (_isDesktop) ...[
          const SizedBox(height: 8),
          _menuButton('QUIT', null, () => exit(0), color: GameColors.dangerDark),
        ],
      ],
    );
  }

  Widget _menuButton(String label, String? icon, VoidCallback onTap, {Color color = GameColors.woodLight}) {
    return GameButton(
      onPressed: onTap,
      color: color,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Image.asset(icon, width: 24, height: 24), const SizedBox(width: 8)],
          GameText(label, size: 17),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ difficulty

  Widget _difficulty() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header('CHOOSE YOUR CITY'),
        const SizedBox(height: 8),
        _DifficultyCard(
          title: 'EASY',
          blurb: 'A green riverside town with one coal plant.',
          funds: 8000,
          pips: 1,
          color: GameColors.leafDark,
          icon: 'assets/images/ui/icon_soil.png',
          onTap: () => _start('easy'),
        ),
        const SizedBox(height: 8),
        _DifficultyCard(
          title: 'MEDIUM',
          blurb: 'A growing town. Factory, landfill and smoggy skies.',
          funds: 5000,
          pips: 2,
          color: const Color(0xFFB7791F),
          icon: 'assets/images/ui/icon_aqi.png',
          onTap: () => _start('medium'),
        ),
        const SizedBox(height: 8),
        _DifficultyCard(
          title: 'HARD',
          blurb: 'Industrial wasteland. Toxic river, dying forests.',
          funds: 3000,
          pips: 3,
          color: GameColors.dangerDark,
          icon: 'assets/images/ui/streak_flame.png',
          onTap: () => _start('hard'),
        ),
        const SizedBox(height: 10),
        _backButton(),
      ],
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Center(child: GameText(text, size: 18, color: GameColors.gold)),
      );

  Widget _backButton() => GameButton(
        onPressed: () => _go(_Page.home),
        color: GameColors.woodLight,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back_rounded, color: GameColors.parchment, size: 20),
            SizedBox(width: 6),
            GameText('BACK', size: 15),
          ],
        ),
      );

  // ------------------------------------------------------------ help/about

  Widget _scrollPage(String title, List<Widget> body, double h) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(title),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: h * 0.48),
          child: GameSlot(
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _backButton(),
      ],
    );
  }

  static const _body = TextStyle(fontFamily: kGameFont, color: GameColors.parchment, fontSize: 13, height: 1.3);

  Widget _tip(String icon, String title, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset('assets/images/ui/$icon', width: 30, height: 30),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GameText(title, size: 13.5, color: GameColors.gold),
                  const SizedBox(height: 2),
                  Text(text, style: _body),
                ],
              ),
            ),
          ],
        ),
      );

  List<Widget> _howTo() => [
        _tip('icon_aqi.png', 'WATCH THE FOUR METERS',
            'Air quality (AQI), water purity, soil health and waste. Green is healthy, red is dangerous.'),
        _tip('icon_funds.png', 'BUILD TO CHANGE THE CITY',
            'Pick a building from the menu, then tap the map. Each one shows exactly how it changes pollution and money.'),
        _tip('icon_soil.png', 'PROTECT THE FORESTS',
            'Forests clean the air and hold the soil every day. Building on them cuts them down.'),
        _tip('icon_noise.png', 'BALANCE THE BUDGET',
            'Taxes and industry earn money. Polluters pay well but poison the city. Demolish them when you can afford green power.'),
        _tip('icon_trophy.png', 'REACH THE GREEN ZONE',
            'Win with AQI 50 or lower, water 80+, soil 75+ and waste 30 or lower, while keeping \$1000 and 100 citizens. Then keep building in Infinite Mode.'),
        _tip('streak_flame.png', "DON'T LET IT COLLAPSE",
            'If pollution stays critical for 8 days in a row, the city is evacuated.'),
      ];

  Widget _sdg(int n, Color c, String name, String link) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: GameColors.ink, width: 1.5),
              ),
              child: GameText('$n', size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GameText(name, size: 13, color: GameColors.gold),
                  Text(link, style: _body.copyWith(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );

  List<Widget> _about() => [
        const Text(
          'EcoMayor teaches environmental science through cause and effect: every building you place changes the '
          "city's air, water, soil and waste, and your advisors explain why.",
          style: _body,
        ),
        const SizedBox(height: 10),
        const GameText('UN SUSTAINABLE DEVELOPMENT GOALS', size: 12.5, color: GameColors.leaf),
        const SizedBox(height: 6),
        _sdg(6, const Color(0xFF26BDE2), 'Clean Water and Sanitation', 'Water and sewage treatment restore the river.'),
        _sdg(7, const Color(0xFFFCC30B), 'Affordable and Clean Energy', 'Replace coal with solar farms and wind turbines.'),
        _sdg(11, const Color(0xFFFD9D24), 'Sustainable Cities', 'Plan homes, schools, hospitals and green space.'),
        _sdg(12, const Color(0xFFBF8B2E), 'Responsible Consumption', 'Recycling and composting cut waste.'),
        _sdg(13, const Color(0xFF3F7E44), 'Climate Action', 'Lower emissions to bring AQI down.'),
        _sdg(15, const Color(0xFF56C02B), 'Life on Land', 'Protect forests and heal the soil.'),
        const SizedBox(height: 6),
        const GameText('TEAM', size: 12.5, color: GameColors.leaf),
        const SizedBox(height: 2),
        const Text('Gautam, Hari, Albie, Vignesh, Arush', style: _body),
      ];
}

// ---------------------------------------------------------------- widgets

class _Ribbon extends StatelessWidget {
  final String text;

  const _Ribbon({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF2F5E23),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: GameColors.ink, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x88000000), offset: Offset(0, 3))],
      ),
      child: GameText(text, size: 14, color: GameColors.parchment),
    );
  }
}

class _PulsingButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;

  const _PulsingButton({required this.onPressed, required this.child});

  @override
  State<_PulsingButton> createState() => _PulsingButtonState();
}

class _PulsingButtonState extends State<_PulsingButton> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) => Transform.scale(scale: 1 + 0.03 * Curves.easeInOut.transform(_a.value), child: child),
      child: GameButton(
        onPressed: widget.onPressed,
        color: const Color(0xFF3E9B2F),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: widget.child,
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final String title;
  final String blurb;
  final int funds;
  final int pips;
  final Color color;
  final String icon;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.title,
    required this.blurb,
    required this.funds,
    required this.pips,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GameButton(
      onPressed: onTap,
      color: color,
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0x55000000),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: GameColors.ink, width: 1.5),
            ),
            child: Image.asset(icon),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GameText(title, size: 18),
                    const Spacer(),
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Opacity(
                          opacity: i < pips ? 1 : 0.25,
                          child: Image.asset('assets/images/ui/streak_flame.png', width: 15, height: 15),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  blurb,
                  style: const TextStyle(fontFamily: kGameFont, color: Colors.white, fontSize: 12, height: 1.2, shadows: [
                    Shadow(color: GameColors.ink, offset: Offset(1, 1)),
                  ]),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Image.asset('assets/images/ui/icon_funds.png', width: 14, height: 14),
                    const SizedBox(width: 3),
                    GameText('$funds', size: 12, color: GameColors.gold),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Leaves drifting down the title screen.
class _LeavesPainter extends CustomPainter {
  final Animation<double> t;

  _LeavesPainter(this.t) : super(repaint: t);

  static final _seeds = List.generate(16, (i) {
    final r = math.Random(i * 977);
    return (r.nextDouble(), r.nextDouble(), 0.6 + r.nextDouble() * 0.8, r.nextDouble());
  });

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [Color(0xFF7CD34B), Color(0xFF4FA83A), Color(0xFFB7D84B)];
    for (var i = 0; i < _seeds.length; i++) {
      final (x0, phase, speed, sway) = _seeds[i];
      final p = (t.value * speed + phase) % 1.0;
      final x = (x0 + math.sin((p * 4 + sway) * math.pi) * 0.04) * size.width;
      final y = -20 + p * (size.height + 40);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((p * 6 + sway) * math.pi);
      final leaf = Rect.fromCenter(center: Offset.zero, width: 14, height: 7);
      canvas.drawOval(leaf.inflate(1.2), Paint()..color = const Color(0xAA173D17));
      canvas.drawOval(leaf, Paint()..color = colors[i % 3].withValues(alpha: 0.9));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LeavesPainter old) => false;
}
