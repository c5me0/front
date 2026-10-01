// Permission action card with pending, requesting, granted, and denied states. Keep
// progress and success feedback within the shared motion system.

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../content/app.g.dart';
import '../design_system/design_system.dart';

enum PermissionCardStatus { pending, requesting, granted, denied }

String permissionCardStatusLabel(
  PermissionCardStatus status, {
  AppContent copy = appContent,
}) => switch (status) {
  PermissionCardStatus.pending => copy.permissions.status.pending,
  PermissionCardStatus.requesting => copy.permissions.status.requesting,
  PermissionCardStatus.granted => copy.permissions.status.granted,
  PermissionCardStatus.denied => copy.permissions.status.denied,
};

///

class PermissionCard extends StatefulWidget {
  const PermissionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.status = PermissionCardStatus.pending,
  });

  final CameoIconName icon;
  final String title;
  final String description;
  final PermissionCardStatus status;

  static const Key cardKey = ValueKey('permissionCard.card');
  static const Key ringKey = ValueKey('permissionCard.ring');
  static const Key descriptionKey = ValueKey('permissionCard.description');
  static const Key deniedKey = ValueKey('permissionCard.denied');

  @override
  State<PermissionCard> createState() => PermissionCardState();
}

class PermissionCardState extends State<PermissionCard>
    with TickerProviderStateMixin {
  late final bool _grantedAtMount =
      widget.status == PermissionCardStatus.granted;

  late final AnimationController _grant = AnimationController.unbounded(
    vsync: this,
    value: _grantedAtMount ? 1 : 0,
  );
  late final AnimationController _ring = AnimationController.unbounded(
    vsync: this,
    value: _grantedAtMount ? CameoMotion.permissionV6RingExitScale : 1,
  );
  late final AnimationController _pop = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: CameoMotion.permissionSpin,
  );

  late final AnimationController _arc = AnimationController(
    vsync: this,
    duration: CameoMotion.durationFast,
    value: widget.status == PermissionCardStatus.requesting ? 1 : 0,
  );
  late final AnimationController _denied = AnimationController(
    vsync: this,
    duration: CameoMotion.durationBase,
    value: widget.status == PermissionCardStatus.denied ? 1 : 0,
  );
  bool _reduceMotion = false;

  double get grantProgress => _grant.value;
  double get ringScale => _ring.value;
  double get cardScale => _pop.value;
  bool get spinning => _spin.isAnimating;

  @override
  void initState() {
    super.initState();

    for (final c in [_grant, _ring, _pop, _spin, _arc, _denied]) {
      c.value;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncSpin();
  }

  @override
  void didUpdateWidget(PermissionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status == widget.status) return;
    _syncSpin();
    final granted = widget.status == PermissionCardStatus.granted;
    final wasGranted = oldWidget.status == PermissionCardStatus.granted;
    if (granted != wasGranted) {
      final ringTarget = granted ? CameoMotion.permissionV6RingExitScale : 1.0;
      if (_reduceMotion) {
        _grant.value = granted ? 1 : 0;
        _ring.value = ringTarget;
      } else {
        _grant.springTo(granted ? 1 : 0, CameoMotion.permissionV6GrantSpring);
        _ring.springTo(ringTarget, CameoMotion.permissionV6RingSpring);
      }
      if (granted) {
        HapticFeedback.lightImpact();
        if (!_reduceMotion) {
          const spring = CameoMotion.permissionV6PopSpring;
          final kick = springImpulse(
            spring,
            CameoMotion.permissionV6GrantPopScale,
          );
          _pop.value = 1;
          _pop.springTo(1, spring, velocity: kick.velocity);
        }
      }
    }
    final denied = widget.status == PermissionCardStatus.denied;
    _denied.animateTo(denied ? 1 : 0, curve: CameoMotion.easingStandard);
  }

  void _syncSpin() {
    final requesting = widget.status == PermissionCardStatus.requesting;
    if (requesting) {
      if (!_spin.isAnimating) {
        _spin
          ..value = 0
          ..repeat();
      }
      _arc.forward();
    } else {
      _arc.reverse().then((_) {
        if (mounted && widget.status != PermissionCardStatus.requesting) {
          _spin.stop();
        }
      });
    }
  }

  @override
  void dispose() {
    _grant.dispose();
    _ring.dispose();
    _pop.dispose();
    _spin.dispose();
    _arc.dispose();
    _denied.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final status = widget.status;
    final denied = AppContent.of(context).v6.permissions.denied;
    final description = status == PermissionCardStatus.denied
        ? denied
        : widget.description;
    return Semantics(
      container: true,
      label:
          '${widget.title}, $description, ${permissionCardStatusLabel(status, copy: AppContent.of(context))}',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: Listenable.merge([_grant, _pop, _denied]),
        builder: (context, _) {
          final g = _grant.value.clamp(0.0, 1.0);
          final fill = Color.lerp(
            c.backgroundFillNeutralBase,
            c.systemGreen,
            g,
          )!;
          final ink = Color.lerp(
            c.foregroundNeutralBase,
            c.staticWhiteBase,
            g,
          )!;
          final muted = Color.lerp(
            c.foregroundNeutralMuted,
            c.staticWhiteMuted,
            g,
          )!;
          final d = _denied.value;
          return Transform.scale(
            scale: _pop.value,
            child: SizedBox(
              key: PermissionCard.cardKey,
              height: CameoLayout.permissionCardV6Height,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: fill,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(
                      CameoLayout.permissionCardV6Radius,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CameoLayout.permissionCardV6PaddingX,
                    vertical: CameoLayout.permissionCardV6PaddingY,
                  ),
                  child: Row(
                    spacing: CameoLayout.permissionCardV6ContentGap,
                    children: [
                      CameoIcon(
                        widget.icon,
                        size: CameoLayout.permissionCardV6IconSize,
                        color: ink,
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: CameoLayout.permissionCardV6TextGap,
                          children: [
                            CameoText(
                              widget.title,

                              style: CameoTextStyles.bodyLgStrong.copyWith(
                                fontFeatures: const [
                                  FontFeature.liningFigures(),
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                              color: ink,
                              maxLines: 1,
                            ),
                            Stack(
                              children: [
                                Opacity(
                                  key: PermissionCard.descriptionKey,
                                  opacity: 1 - d,
                                  child: CameoText(
                                    widget.description,
                                    style: CameoTextStyles.bodySm,
                                    color: muted,
                                    maxLines: 1,
                                  ),
                                ),
                                Positioned.fill(
                                  key: const ValueKey(
                                    'permissionCard.deniedLayer',
                                  ),
                                  child: Opacity(
                                    key: PermissionCard.deniedKey,
                                    opacity: d,
                                    child: CameoText(
                                      denied,
                                      style: CameoTextStyles.bodySm,
                                      color: muted,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      AnimatedBuilder(
                        animation: Listenable.merge([_ring, _spin, _arc]),
                        builder: (context, _) => Transform.scale(
                          key: PermissionCard.ringKey,
                          scale: math.max(0, _ring.value),
                          child: CustomPaint(
                            size: const Size.square(
                              CameoLayout.permissionCardV6RingSize,
                            ),
                            painter: _RingPainter(
                              ring: c.borderOutline,
                              arc: c.foregroundNeutralMuted.withValues(
                                alpha:
                                    c.foregroundNeutralMuted.a *
                                    _arc.value.clamp(0.0, 1.0),
                              ),
                              turn: _spin.value,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.ring, required this.arc, this.turn = 0});

  final Color ring;
  final Color arc;
  final double turn;

  @override
  void paint(Canvas canvas, Size size) {
    const w = CameoLayout.permissionCardV6RingBorderWidth;
    final rect = (Offset.zero & size).deflate(w / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = ring;
    canvas.drawOval(rect, paint);
    if (arc.a == 0) return;
    canvas.drawArc(
      rect,
      -3 * math.pi / 4 + turn * 2 * math.pi,
      math.pi / 2,
      false,
      paint
        ..color = arc
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ring != ring || old.arc != arc || old.turn != turn;
}
