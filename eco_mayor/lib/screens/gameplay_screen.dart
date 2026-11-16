import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../data/buildings_data.dart';
import '../game/eco_mayor_game.dart';
import '../models/building.dart';
import '../models/city_state.dart';
import '../ui/game_theme.dart';
import '../utils/constants.dart';

class GameplayScreen extends StatefulWidget {
  final GameController controller;

  const GameplayScreen({super.key, required this.controller});

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen> {
  late final EcoMayorFlameGame _game;
  final _topKey = GlobalKey();
  final _bottomKey = GlobalKey();
  BuildingCategory _tab = BuildingCategory.green;
  double _topH = 110;
  double _bottomH = 200;

  GameController get c => widget.controller;

  static const _tabs = [
    (BuildingCategory.green, 'Green', 'ui/icon_soil.png'),
    (BuildingCategory.residential, 'Homes', 'ui/icon_population.png'),
    (BuildingCategory.infrastructure, 'Services', 'ui/icon_happiness.png'),
    (BuildingCategory.industry, 'Industry', 'ui/icon_noise.png'),
  ];

  @override
  void initState() {
    super.initState();
    _game = EcoMayorFlameGame(controller: c);
    c.addListener(_onChange);
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  void _syncInsets() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final top = _topKey.currentContext?.size?.height ?? 0;
      final bottom = _bottomKey.currentContext?.size?.height ?? 0;
      final pad = MediaQuery.of(context).padding;
      _game.setInsets(top: top + pad.top, bottom: bottom + pad.bottom + 8);
      if ((top + pad.top - _topH).abs() > 1 ||
          (bottom + pad.bottom + 8 - _bottomH).abs() > 1) {
        setState(() {
          _topH = top + pad.top;
          _bottomH = bottom + pad.bottom + 8;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _syncInsets();
    final s = c.state;
    return Scaffold(
      backgroundColor: GameColors.mapBackdrop,
      body: Stack(
        children: [
          Positioned.fill(child: GameWidget(game: _game)),

          // Top HUD
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                key: _topKey,
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: _topHud(s),
                  ),
                ),
              ),
            ),
          ),

          // Toast
          if (c.toast != null)
            Positioned(
              top: _topH + 8,
              left: 0,
              right: 0,
              child: Center(
                child: _Toast(
                  key: ValueKey(c.toastId),
                  text: c.toast!,
                  error: c.toastIsError,
                ),
              ),
            ),

          // Advisor
          if (c.activeAdvisorDialog != null)
            Positioned(
              top: _topH + 8,
              left: 8,
              right: 8,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(c.activeAdvisorDialog),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutBack,
                    builder: (_, t, child) => Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, -30 * (1 - t)),
                        child: child,
                      ),
                    ),
                    child: _advisorBox(),
                  ),
                ),
              ),
            ),

          // Bottom: info + build menu + actions
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (s.criticalDays > 0 && !c.isGameOver) ...[
                          _collapseBanner(s.criticalDays),
                          const SizedBox(height: 6),
                        ],
                        if (c.selectedBuilding != null) ...[
                          _buildingInfo(c.selectedBuilding!),
                          const SizedBox(height: 6),
                        ],
                        KeyedSubtree(key: _bottomKey, child: _buildMenu()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // "DAY N" banner after each End Day
          if (s.turn > 1 && c.lastResult != null && !c.isGameOver)
            Positioned(
              // Middle of the map area, below where advisors appear.
              top: (_topH + MediaQuery.of(context).size.height - _bottomH) / 2 + 10,
              left: 0,
              right: 0,
              child: Center(
                child: _DayBanner(
                  key: ValueKey('day${s.turn}_${c.gameId}'),
                  day: s.turn,
                  funds: c.lastResult!.deltaFunds,
                  aqi: c.lastResult!.deltaMetrics.aqi,
                  water: c.lastResult!.deltaMetrics.waterPurity,
                ),
              ),
            ),

          if (c.gameOutcome != null)
            Positioned.fill(child: _outcomeOverlay(context)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ top HUD

  Widget _topHud(CityState s) {
    final m = s.metrics;
    return GamePanel(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _imageButton(
                'assets/images/ui/menu_back.png',
                () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 6),
              GameSlot(
                glow: s.infiniteMode ? GameColors.sky : null,
                child: GameText(
                  s.infiniteMode ? 'DAY ${s.turn}  ∞' : 'DAY ${s.turn}',
                  size: 15,
                  color: GameColors.gold,
                ),
              ),
              const SizedBox(width: 6),
              _counter('ui/icon_funds.png', s.funds, GameColors.gold, flex: 5),
              const SizedBox(width: 4),
              _counter('ui/icon_gems.png', s.gems, GameColors.leaf, flex: 3),
              const SizedBox(width: 4),
              _counter(
                'ui/icon_population.png',
                s.population,
                GameColors.sky,
                flex: 4,
              ),
              const SizedBox(width: 4),
              _counter(
                'ui/icon_happiness.png',
                s.happiness,
                Colors.white,
                flex: 4,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              _meter('ui/icon_aqi.png', 'AIR', m.aqi, 1 - m.aqi / 300),
              const SizedBox(width: 6),
              _meter(
                'ui/icon_water.png',
                'WATER',
                m.waterPurity,
                m.waterPurity / 100,
              ),
              const SizedBox(width: 6),
              _meter(
                'ui/icon_soil.png',
                'SOIL',
                m.soilHealth,
                m.soilHealth / 100,
              ),
              const SizedBox(width: 6),
              _meter(
                'ui/icon_noise.png',
                'WASTE',
                m.noiseWaste,
                1 - m.noiseWaste / 100,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imageButton(String asset, VoidCallback onTap) {
    return GameButton(
      onPressed: onTap,
      color: GameColors.woodLight,
      padding: const EdgeInsets.all(3),
      child: Image.asset(asset, width: 20, height: 20),
    );
  }

  Widget _counter(String icon, num value, Color color, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: GameSlot(
        padding: const EdgeInsets.fromLTRB(3, 2, 4, 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/$icon',
              width: 18,
              height: 18,
              filterQuality: FilterQuality.medium,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AnimatedNumber(value: value, size: 14, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meter(String icon, String label, num value, double goodness) {
    final col = healthColor(goodness);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/$icon',
                width: 16,
                height: 16,
                filterQuality: FilterQuality.medium,
              ),
              const SizedBox(width: 3),
              Expanded(
                child: GameText(
                  label,
                  size: 10,
                  color: GameColors.parchment,
                  maxLines: 1,
                ),
              ),
              AnimatedNumber(value: value, size: 11, color: col),
            ],
          ),
          const SizedBox(height: 3),
          GameMeter(fraction: goodness, color: col),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ advisor

  Widget _advisorBox() {
    final a = c.activeAdvisorDialog!;
    return GestureDetector(
      onTap: c.dismissAdvisor,
      child: GamePanel(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: GameColors.ink, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Image.asset(
                  a.portraitAsset,
                  width: 64,
                  height: 64,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GameText(
                          a.advisorName,
                          size: 15,
                          color: GameColors.gold,
                          maxLines: 1,
                        ),
                      ),
                      const GameText(
                        'TAP TO CLOSE',
                        size: 9,
                        color: Color(0xFFB9A57A),
                      ),
                    ],
                  ),
                  GameText(
                    a.title.toUpperCase(),
                    size: 10,
                    color: GameColors.leaf,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    a.message,
                    style: const TextStyle(
                      fontFamily: kGameFont,
                      color: GameColors.parchment,
                      fontSize: 12.5,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: GameColors.woodDark,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: GameColors.leafDark,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      a.evsConcept,
                      style: const TextStyle(
                        fontFamily: kGameFont,
                        color: GameColors.leaf,
                        fontSize: 11.5,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ bottom

  Widget _collapseBanner(int days) {
    final left = GameConstants.collapseDaysToLose - days;
    return GamePanel(
      fill: GameColors.dangerDark,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Image.asset(
            'assets/images/ui/streak_flame.png',
            width: 22,
            height: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GameText(
              'CRITICAL POLLUTION!  City collapses in $left day${left == 1 ? '' : 's'}',
              size: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildingInfo(BuildingType b) {
    final chips = <Widget>[
      if (b.revenuePerTurn != 0)
        _effect(
          'ui/icon_funds.png',
          b.revenuePerTurn.toDouble(),
          true,
          prefix: '\$',
        ),
      if (b.population != 0)
        _effect('ui/icon_population.png', b.population.toDouble(), true),
      if (b.aqiDelta != 0) _effect('ui/icon_aqi.png', b.aqiDelta, false),
      if (b.waterDelta != 0) _effect('ui/icon_water.png', b.waterDelta, true),
      if (b.soilDelta != 0) _effect('ui/icon_soil.png', b.soilDelta, true),
      if (b.noiseWasteDelta != 0)
        _effect('ui/icon_noise.png', b.noiseWasteDelta, false),
    ];
    return GamePanel(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: GameText(
                  b.name,
                  size: 15,
                  color: GameColors.gold,
                  maxLines: 1,
                ),
              ),
              GameText(
                '${b.width}x${b.height}',
                size: 11,
                color: const Color(0xFFB9A57A),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => c.selectBuilding(null),
                child: const Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: GameColors.parchment,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            b.description,
            style: const TextStyle(
              fontFamily: kGameFont,
              color: GameColors.parchment,
              fontSize: 12,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 5, runSpacing: 5, children: chips),
          const SizedBox(height: 4),
          const GameText(
            'Tap the map to build',
            size: 10,
            color: Color(0xFFB9A57A),
          ),
        ],
      ),
    );
  }

  /// One effect chip. [higherIsGood] decides whether a positive number is green.
  Widget _effect(
    String icon,
    double v,
    bool higherIsGood, {
    String prefix = '',
  }) {
    final good = higherIsGood ? v > 0 : v < 0;
    final sign = v > 0 ? '+' : '-';
    final abs = v.abs();
    final txt = abs == abs.roundToDouble()
        ? abs.toStringAsFixed(0)
        : abs.toStringAsFixed(1);
    return GameSlot(
      glow: good ? GameColors.leafDark : GameColors.dangerDark,
      padding: const EdgeInsets.fromLTRB(3, 1, 6, 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/$icon', width: 16, height: 16),
          const SizedBox(width: 3),
          GameText(
            '$sign$prefix$txt',
            size: 12,
            color: good ? GameColors.leaf : const Color(0xFFFF7A6B),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu() {
    final items = BuildingsData.all.values
        .where((b) => b.category == _tab)
        .toList();
    return GamePanel(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Category tabs
          Row(
            children: [
              for (final t in _tabs) ...[
                Expanded(child: _tabButton(t.$1, t.$2, t.$3)),
                if (t != _tabs.last) const SizedBox(width: 4),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // Building cards
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) => _card(items[i]),
            ),
          ),
          const SizedBox(height: 6),
          // Actions
          Row(
            children: [
              GameButton(
                onPressed: c.toggleDemolish,
                color: c.isDemolishMode
                    ? GameColors.danger
                    : GameColors.woodLight,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/ui/btn_demolish.png',
                      width: 26,
                      height: 26,
                    ),
                    const SizedBox(width: 6),
                    GameText(
                      c.isDemolishMode ? 'CANCEL' : 'DEMOLISH',
                      size: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GameButton(
                  onPressed: c.isGameOver ? null : c.endDay,
                  color: const Color(0xFFE29B1E),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GameText('END DAY', size: 19),
                      SizedBox(width: 4),
                      Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                        shadows: [
                          Shadow(
                            color: GameColors.ink,
                            offset: Offset(1.5, 1.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabButton(BuildingCategory cat, String label, String icon) {
    final active = _tab == cat;
    return GestureDetector(
      onTap: () => setState(() => _tab = cat),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: active ? GameColors.woodLight : GameColors.woodDark,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: active ? GameColors.gold : GameColors.ink,
            width: active ? 2 : 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/$icon', width: 16, height: 16),
            const SizedBox(width: 3),
            Flexible(
              child: GameText(
                label,
                size: 11.5,
                color: active ? GameColors.gold : GameColors.parchment,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildingType b) {
    final selected = c.selectedBuilding?.id == b.id;
    final affordable = c.state.canAfford(b);
    return GestureDetector(
      onTap: () => c.selectBuilding(b),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 74,
        transform: Matrix4.translationValues(0, selected ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4E6B2A) : GameColors.woodDark,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: selected ? GameColors.gold : GameColors.ink,
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x88FFC93C), blurRadius: 8)]
              : null,
        ),
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 3),
        child: Opacity(
          opacity: affordable ? 1 : 0.45,
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Image.asset(
                    'assets/images/${b.spritePath}',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: GameText(
                  _short[b.id] ?? b.name,
                  size: 10.5,
                  color: GameColors.parchment,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/ui/icon_funds.png',
                    width: 11,
                    height: 11,
                  ),
                  const SizedBox(width: 2),
                  GameText(
                    '${b.cost}',
                    size: 11,
                    color: affordable
                        ? GameColors.gold
                        : const Color(0xFFFF7A6B),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _short = {
    'coal_plant': 'Coal Plant',
    'factory': 'Factory',
    'oil_refinery': 'Refinery',
    'landfill': 'Landfill',
    'house': 'House',
    'apartment': 'Apartments',
    'park': 'Park',
    'solar_farm': 'Solar Farm',
    'wind_turbine': 'Wind',
    'water_treatment': 'Water Plant',
    'recycling_center': 'Recycling',
    'composting': 'Compost',
    'green_roof': 'Green Roof',
    'sewage_treatment': 'Sewage',
    'road': 'Road',
    'hospital': 'Hospital',
    'school': 'School',
    'ev_station': 'EV Charger',
  };

  // ------------------------------------------------------------------ outcome

  Widget _outcomeOverlay(BuildContext context) {
    final o = c.gameOutcome!;
    final won = o.isVictory;
    final s = o.nextState;
    final accent = won ? GameColors.gold : const Color(0xFFFF7A6B);
    return Container(
      color: const Color(0xCC000000),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: GamePanel(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  won
                      ? 'assets/images/ui/icon_trophy.png'
                      : 'assets/images/ui/streak_flame.png',
                  width: 80,
                  height: 80,
                ),
                const SizedBox(height: 6),
                GameText(
                  won ? 'GREEN CITY ACHIEVED!' : 'CITY COLLAPSED',
                  size: 24,
                  color: accent,
                  align: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  o.endReason ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: kGameFont,
                    color: GameColors.parchment,
                    fontSize: 13.5,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _stat('ui/icon_aqi.png', s.metrics.aqi.toStringAsFixed(0)),
                    _stat(
                      'ui/icon_water.png',
                      '${s.metrics.waterPurity.round()}',
                    ),
                    _stat(
                      'ui/icon_soil.png',
                      '${s.metrics.soilHealth.round()}',
                    ),
                    _stat(
                      'ui/icon_noise.png',
                      s.metrics.noiseWaste.toStringAsFixed(0),
                    ),
                    _stat('ui/icon_population.png', '${s.population}'),
                    _stat('ui/icon_funds.png', '${s.funds}'),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: GameButton(
                    onPressed: won ? c.continueInfiniteMode : c.restart,
                    color: won ? GameColors.leafDark : const Color(0xFFE29B1E),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: GameText(
                      won ? 'KEEP BUILDING  ∞' : 'TRY AGAIN',
                      size: 17,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: GameButton(
                    onPressed: () => Navigator.of(context).pop(),
                    color: GameColors.woodLight,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const GameText('MAIN MENU', size: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String icon, String v) {
    return GameSlot(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/$icon', width: 18, height: 18),
          const SizedBox(width: 4),
          GameText(v, size: 13),
        ],
      ),
    );
  }
}

class _Toast extends StatefulWidget {
  final String text;
  final bool error;

  const _Toast({super.key, required this.text, required this.error});

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _a,
        builder: (_, child) {
          final t = _a.value;
          final opacity = t < 0.1 ? t / 0.1 : (t > 0.75 ? (1 - t) / 0.25 : 1.0);
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.translate(offset: Offset(0, -8 * t), child: child),
          );
        },
        child: GamePanel(
          fill: widget.error ? GameColors.dangerDark : GameColors.leafDark,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: GameText(widget.text, size: 14),
        ),
      ),
    );
  }
}

/// Wooden "DAY N" sign that drops in after End Day with the day's changes,
/// then fades away.
class _DayBanner extends StatefulWidget {
  final int day;
  final int funds;
  final double aqi;
  final double water;

  const _DayBanner({
    super.key,
    required this.day,
    required this.funds,
    required this.aqi,
    required this.water,
  });

  @override
  State<_DayBanner> createState() => _DayBannerState();
}

class _DayBannerState extends State<_DayBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  Widget _chip(String icon, String text, bool good) => GameSlot(
    glow: good ? GameColors.leafDark : GameColors.dangerDark,
    padding: const EdgeInsets.fromLTRB(3, 1, 6, 1),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/images/ui/$icon', width: 16, height: 16),
        const SizedBox(width: 3),
        GameText(
          text,
          size: 12,
          color: good ? GameColors.leaf : const Color(0xFFFF7A6B),
        ),
      ],
    ),
  );

  String _signed(num v) => '${v >= 0 ? '+' : '-'}${v.abs().round()}';

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _a,
        builder: (_, child) {
          final t = _a.value;
          final drop = Curves.elasticOut.transform((t / 0.35).clamp(0.0, 1.0));
          final fade = t < 0.8 ? 1.0 : (1 - t) / 0.2;
          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -40 * (1 - drop)),
              child: Transform.scale(scale: 0.6 + 0.4 * drop, child: child),
            ),
          );
        },
        child: GamePanel(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameText('DAY ${widget.day}', size: 26, color: GameColors.gold),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _chip(
                    'icon_funds.png',
                    '\$${_signed(widget.funds)}',
                    widget.funds >= 0,
                  ),
                  const SizedBox(width: 5),
                  _chip('icon_aqi.png', _signed(widget.aqi), widget.aqi <= 0),
                  const SizedBox(width: 5),
                  _chip(
                    'icon_water.png',
                    _signed(widget.water),
                    widget.water >= 0,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
