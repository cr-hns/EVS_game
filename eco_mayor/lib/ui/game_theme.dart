import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared look for EcoMayor: chunky pixel panels, outlined pixel-font text,
/// and bevelled buttons, instead of stock Material widgets.
class GameColors {
  static const ink = Color(0xFF120D09); // outer outlines
  static const wood = Color(0xFF3B2A1C); // panel fill
  static const woodLight = Color(0xFF5C4128); // bevel highlight
  static const woodDark = Color(0xFF24180F); // bevel shadow / slots
  static const parchment = Color(0xFFF3E3B5);
  static const gold = Color(0xFFFFC93C);
  static const leaf = Color(0xFF7CD34B);
  static const leafDark = Color(0xFF2F7A2A);
  static const danger = Color(0xFFE5483B);
  static const dangerDark = Color(0xFF7C1F18);
  static const sky = Color(0xFF5AC8F0);
  static const mapBackdrop = Color(0xFF16231A);
}

const String kGameFont = 'PixelifySans';

/// Pixelify draws 5 like S and 2 like Z, so any HUD text containing digits
/// uses Silkscreen, whose numerals are unambiguous.
const String kNumberFont = 'Silkscreen';

/// Pixel-font text with a hard 1px-ish outline and drop shadow, like game HUDs.
class GameText extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  final FontWeight weight;
  final TextAlign? align;
  final int? maxLines;

  const GameText(
    this.text, {
    super.key,
    this.size = 14,
    this.color = Colors.white,
    this.weight = FontWeight.w700,
    this.align,
    this.maxLines,
  });

  static final RegExp _numberRun = RegExp(r'[0-9][0-9,.]*');

  @override
  Widget build(BuildContext context) {
    final o = (size / 11).clamp(1.0, 2.5);
    // A single hard drop shadow. Side shadows would fill the openings of
    // letters like C and E and make them read as O and 8.
    final shadows = [
      Shadow(color: GameColors.ink, offset: Offset(o, o)),
      Shadow(color: const Color(0x66120D09), offset: Offset(o * 1.6, o * 1.6)),
    ];
    final wordStyle = TextStyle(
      fontFamily: kGameFont,
      fontSize: size,
      // Pixelify is a variable font: request its real weight rather than
      // letting Flutter fake bold.
      fontWeight: FontWeight.w400,
      fontVariations: [
        FontVariation('wght', weight.value.toDouble().clamp(400, 700)),
      ],
      color: color,
      height: 1.15,
      shadows: shadows,
    );
    // Digits use Silkscreen (Pixelify draws 5 like S and 2 like Z).
    final numberStyle = wordStyle.copyWith(
      fontFamily: kNumberFont,
      fontVariations: const [],
      fontWeight: weight.value >= 600 ? FontWeight.w700 : FontWeight.w400,
      fontSize: size * 0.9,
    );

    // ALL-CAPS labels (buttons, banners, DAY 1) read best entirely in
    // Silkscreen; Pixelify's bold capital C and E look like O and 8.
    if (!text.contains(RegExp('[a-z]'))) {
      return Text(
        text,
        style: numberStyle,
        textAlign: align,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
      );
    }

    final spans = <TextSpan>[];
    var last = 0;
    for (final m in _numberRun.allMatches(text)) {
      if (m.start > last)
        spans.add(TextSpan(text: text.substring(last, m.start)));
      spans.add(TextSpan(text: m.group(0), style: numberStyle));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));

    return Text.rich(
      TextSpan(style: wordStyle, children: spans),
      textAlign: align,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}

/// Bevelled wooden panel: dark outline, light top-left edge, dark bottom-right edge.
class GamePanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color fill;
  final Color? borderColor;

  const GamePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(8),
    this.fill = GameColors.wood,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: borderColor ?? GameColors.ink,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88000000),
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(2.5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(fill, Colors.white, 0.12)!, fill],
              stops: const [0, 0.35],
            ),
            border: Border(
              top: const BorderSide(color: GameColors.woodLight, width: 2),
              left: const BorderSide(color: GameColors.woodLight, width: 2),
              bottom: BorderSide(
                color: Color.lerp(fill, Colors.black, 0.45)!,
                width: 2,
              ),
              right: BorderSide(
                color: Color.lerp(fill, Colors.black, 0.45)!,
                width: 2,
              ),
            ),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Recessed slot used for counters and meters.
class GameSlot extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? glow;

  const GameSlot({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    this.glow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: GameColors.woodDark,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: glow ?? GameColors.ink,
          width: glow != null ? 2 : 1.5,
        ),
      ),
      child: child,
    );
  }
}

/// Chunky pressable button that sinks when pressed.
class GameButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  const GameButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.color = GameColors.leafDark,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  });

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final base = enabled ? widget.color : const Color(0xFF555555);
    final depth = _down ? 1.0 : 4.0;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              widget.onPressed!();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        margin: EdgeInsets.only(top: 4 - depth),
        decoration: BoxDecoration(
          color: GameColors.ink,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: EdgeInsets.fromLTRB(2, 2, 2, 2 + depth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(base, Colors.white, 0.3)!, base],
                stops: const [0, 0.5],
              ),
              border: Border(
                bottom: BorderSide(
                  color: Color.lerp(base, Colors.black, 0.4)!,
                  width: 2,
                ),
              ),
            ),
            child: Center(widthFactor: 1, heightFactor: 1, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Horizontal meter bar: fraction 0..1, coloured by how healthy it is.
class GameMeter extends StatelessWidget {
  final double fraction;
  final Color color;

  const GameMeter({super.key, required this.fraction, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 9,
      decoration: BoxDecoration(
        color: const Color(0xFF140E0A),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: GameColors.ink, width: 1),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: fraction.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, f, child) => Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: f, child: child),
        ),
        child: FractionallySizedBox(
          widthFactor: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(color, Colors.white, 0.35)!, color],
                stops: const [0, 0.5],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Green → amber → red depending on how close a metric is to its healthy end.
Color healthColor(double goodness) {
  if (goodness >= 0.66) return GameColors.leaf;
  if (goodness >= 0.4) return GameColors.gold;
  return GameColors.danger;
}

/// A number that counts to its new value and does a little pop when it
/// changes, coloured green/red for a moment to show which way it went.
class AnimatedNumber extends StatefulWidget {
  final num value;
  final double size;
  final Color color;

  const AnimatedNumber({
    super.key,
    required this.value,
    this.size = 14,
    this.color = Colors.white,
  });

  @override
  State<AnimatedNumber> createState() => _AnimatedNumberState();
}

class _AnimatedNumberState extends State<AnimatedNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  late double _from = widget.value.toDouble();
  late double _to = widget.value.toDouble();

  @override
  void didUpdateWidget(AnimatedNumber old) {
    super.didUpdateWidget(old);
    if (widget.value.round() != old.value.round()) {
      _from = _current;
      _to = widget.value.toDouble();
      _a.forward(from: 0);
    }
  }

  double get _current =>
      _from + (_to - _from) * Curves.easeOutCubic.transform(_a.value);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, _) {
        final t = _a.value;
        final pop = _a.isAnimating ? math.sin(t * math.pi) : 0.0;
        final flash = _to > _from ? GameColors.leaf : const Color(0xFFFF7A6B);
        return Transform.scale(
          scale: 1 + 0.18 * pop,
          child: GameText(
            '${_current.round()}',
            size: widget.size,
            color: Color.lerp(widget.color, flash, pop)!,
          ),
        );
      },
    );
  }
}
