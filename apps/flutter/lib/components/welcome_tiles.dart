// Eighteen generated couple photos repeat across three drifting columns. Repeat each
// column's photo and height sequence together to avoid seams; reduced motion stops the
// drift.

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../content/app.g.dart';
import '../design_system/design_system.dart';
import 'onboarding_v6_layout.dart';

///

class WelcomeTiles extends StatefulWidget {
  const WelcomeTiles({super.key});

  static Key columnKey(int column) => ValueKey('welcomeTiles.column.$column');

  static Key tileKey(int column, int index) =>
      ValueKey('welcomeTiles.tile.$column.$index');

  static const Key fadeKey = ValueKey('welcomeTiles.fade');

  @override
  State<WelcomeTiles> createState() => WelcomeTilesState();
}

class WelcomeTilesState extends State<WelcomeTiles>
    with TickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: CameoMotion.welcomeFadeIn,
  );
  late final Ticker _ticker = createTicker(_tick);
  final ValueNotifier<double> _elapsedMs = ValueNotifier(0);
  bool _reduceMotion = false;
  bool _started = false;

  double get elapsedMs => _elapsedMs.value;

  void _tick(Duration elapsed) {
    _elapsedMs.value =
        elapsed.inMicroseconds / Duration.microsecondsPerMillisecond;
  }

  @override
  void initState() {
    super.initState();
    _fade;
    _ticker;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_started) {
      _started = true;
      _fade.animateTo(1, curve: CameoMotion.easingStandard);
    }
    if (_reduceMotion) {
      if (_ticker.isActive) _ticker.stop();
      _elapsedMs.value = 0;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _fade.dispose();
    _elapsedMs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: ClipRect(
          child: FadeTransition(
            key: WelcomeTiles.fadeKey,
            opacity: _fade,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                final tileWidth = welcomeTileWidth(w);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var col = 0; col < welcomeColumnCount; col++)
                      Positioned(
                        key: ValueKey('welcomeTiles.columnBox.$col'),
                        left: welcomeColumnLeft(col, w),
                        top: welcomeColumnTop(col),
                        width: tileWidth,
                        child: _column(col, w, h, c.welcomeTile),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _column(int col, double width, double height, Color color) {
    final heights = welcomeTileHeights(col, width);
    final photos = appContent.v6.welcome.photos;
    final count = welcomeTileCount(col, width, height);
    final loop = welcomeLoopLength(col, width);
    final direction = welcomeDirection(col);
    final radius = BorderRadius.circular(CameoLayout.welcomeV6TilesRadius);
    final strip = RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CameoLayout.welcomeV6TilesGap,
        children: [
          for (var k = 0; k < count; k++)
            SizedBox(
              key: WelcomeTiles.tileKey(col, k),
              height: heights[k % heights.length],
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: color,
                  shape: RoundedSuperellipseBorder(borderRadius: radius),
                  image: DecorationImage(
                    image: AssetImage(
                      photos[(k % heights.length) * welcomeColumnCount + col],
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return ValueListenableBuilder<double>(
      valueListenable: _elapsedMs,
      child: strip,
      builder: (context, ms, strip) => Transform.translate(
        key: WelcomeTiles.columnKey(col),
        offset: Offset(
          0,
          welcomeColumnTranslate(
            ms,
            direction,
            loop,
            CameoMotion.welcomeDriftSpeed,
          ),
        ),
        child: strip,
      ),
    );
  }
}
