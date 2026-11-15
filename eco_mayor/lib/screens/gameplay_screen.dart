import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../controllers/game_controller.dart';
import '../game/eco_mayor_game.dart';
import '../data/buildings_data.dart';
import '../models/building.dart';

class GameplayScreen extends StatefulWidget {
  final GameController controller;

  const GameplayScreen({super.key, required this.controller});

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen> {
  late EcoMayorFlameGame _game;

  @override
  void initState() {
    super.initState();
    _game = EcoMayorFlameGame(controller: widget.controller);
    widget.controller.addListener(_onStateChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Flame Game Canvas
            Positioned.fill(
              child: GameWidget(game: _game),
            ),

            // 2. Top HUD: Pollution Gauges & Currencies
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                color: Colors.black.withOpacity(0.75),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${state.cityName} (Turn ${state.turn})',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Row(
                          children: [
                            const Text('💰', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 3),
                            Text('\$${state.funds}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(width: 8),
                            const Text('💎', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 3),
                            Text('${state.gems}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(width: 8),
                            const Text('👥', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 3),
                            Text('${state.population}', style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _metricBadge('AQI', state.metrics.aqi.toStringAsFixed(0), state.metrics.aqi < 50 ? Colors.green : (state.metrics.aqi < 120 ? Colors.amber : Colors.red)),
                        const SizedBox(width: 4),
                        _metricBadge('Water', '${state.metrics.waterPurity.toStringAsFixed(0)}%', state.metrics.waterPurity > 75 ? Colors.green : (state.metrics.waterPurity > 45 ? Colors.amber : Colors.red)),
                        const SizedBox(width: 4),
                        _metricBadge('Soil', '${state.metrics.soilHealth.toStringAsFixed(0)}%', state.metrics.soilHealth > 70 ? Colors.green : (state.metrics.soilHealth > 45 ? Colors.amber : Colors.red)),
                        const SizedBox(width: 4),
                        _metricBadge('Waste', state.metrics.noiseWaste.toStringAsFixed(0), state.metrics.noiseWaste < 35 ? Colors.green : (state.metrics.noiseWaste < 65 ? Colors.amber : Colors.red)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 3. Advisor Pop-up Dialog
            if (widget.controller.activeAdvisorDialog != null)
              Positioned(
                top: 85,
                left: 12,
                right: 12,
                child: Card(
                  color: const Color(0xFF232D3F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Colors.greenAccent, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.asset(
                          widget.controller.activeAdvisorDialog!.portraitAsset,
                          width: 52,
                          height: 52,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.controller.activeAdvisorDialog!.advisorName} (${widget.controller.activeAdvisorDialog!.title})',
                                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.controller.activeAdvisorDialog!.message,
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.controller.activeAdvisorDialog!.evsConcept,
                                style: const TextStyle(color: Colors.amberAccent, fontStyle: FontStyle.italic, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                          onPressed: () => widget.controller.dismissAdvisor(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 4. Bottom Toolbar: Buildings Carousel & End Day Button
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black.withOpacity(0.85),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.controller.isDemolishMode ? Colors.red : Colors.grey[800],
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          onPressed: () => widget.controller.toggleDemolish(),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Demolish', style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.controller.selectedBuilding != null
                                ? 'Selected: ${widget.controller.selectedBuilding!.name} (\$${widget.controller.selectedBuilding!.cost})'
                                : (widget.controller.isDemolishMode ? 'Demolish mode active' : 'Tap a building below to place'),
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: () => widget.controller.endDay(),
                          icon: const Icon(Icons.wb_sunny, size: 16),
                          label: const Text('End Day', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 56,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: BuildingsData.all.values.map((b) {
                          final isSelected = widget.controller.selectedBuilding?.id == b.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () => widget.controller.selectBuilding(b),
                              child: Container(
                                width: 56,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.green.withOpacity(0.3) : Colors.grey[900],
                                  border: Border.all(
                                    color: isSelected ? Colors.greenAccent : Colors.grey[700]!,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset('assets/images/${b.spritePath}', width: 24, height: 24),
                                    const SizedBox(height: 2),
                                    Text(
                                      '\$${b.cost}',
                                      style: TextStyle(
                                        color: isSelected ? Colors.greenAccent : Colors.white70,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricBadge(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          border: Border.all(color: color, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
