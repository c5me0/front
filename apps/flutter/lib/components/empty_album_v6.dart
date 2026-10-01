// Empty album presentation with paired avatars and an import action. The surrounding
// screen supplies the light canvas.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../content/app.g.dart';
import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import '../navigation/spring_timing.dart';
import '../screens/home_timeline/album_timeline_model.dart';
import 'album_appear.dart';
import 'solid_button.dart';
import 'toast.dart' show toastIconOf;

String emptyAlbumInitialOf(String? name) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return labV6.emptyAlbum.meInitialSample;
  return String.fromCharCodes(trimmed.runes.take(1));
}

class EmptyAlbumV6 extends StatefulWidget {
  const EmptyAlbumV6({
    super.key,
    required this.hasPartner,
    required this.meName,
    required this.onImport,
    required this.onConnect,
    this.title,
    this.actionLabel,
  });

  final bool hasPartner;

  final String? meName;
  final VoidCallback onImport;
  final VoidCallback onConnect;
  final String? title, actionLabel;

  static const Key columnKey = ValueKey('emptyAlbumV6.column');
  static const Key meKey = ValueKey('emptyAlbumV6.me');
  static const Key partnerKey = ValueKey('emptyAlbumV6.partner');
  static const Key initialKey = ValueKey('emptyAlbumV6.initial');
  static const Key titleKey = ValueKey('emptyAlbumV6.title');
  static const Key ctaKey = ValueKey('emptyAlbumV6.cta');

  @override
  State<EmptyAlbumV6> createState() => EmptyAlbumV6State();
}

class EmptyAlbumV6State extends State<EmptyAlbumV6>
    with TickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: CameoMotion.emptyAlbumFloatPeriod,
  );
  late final List<AnimationController> _pops = [
    for (var i = 0; i < 2; i++) AnimationController.unbounded(vsync: this),
  ];
  late final List<AnimationController> _texts = [
    for (var i = 0; i < 2; i++) AnimationController.unbounded(vsync: this),
  ];
  final List<Timer> _timers = [];
  bool _started = false;
  bool _reduceMotion = false;

  int get _avatarCount => widget.hasPartner ? 2 : 1;

  @visibleForTesting
  double get clockMs =>
      _clock.value * CameoMotion.emptyAlbumFloatPeriod.inMilliseconds;

  @visibleForTesting
  double floatYOf(int i) => _reduceMotion ? 0 : emptyFloatY(clockMs, i);

  @visibleForTesting
  List<double> get entrance => [
    for (final c in [..._pops, ..._texts]) c.value,
  ];

  @override
  void initState() {
    super.initState();
    _clock;
    _pops;
    _texts;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_started && reduce == _reduceMotion) return;
    _reduceMotion = reduce;
    _start();
  }

  void _start() {
    _started = true;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    if (_reduceMotion) {
      _clock.stop();
      _clock.value = 0;
      for (final c in [..._pops, ..._texts]) {
        c.value = 1;
      }
      return;
    }
    _clock.repeat();
    final delays = emptyEntranceDelays(_avatarCount);
    void after(Duration d, AnimationController c, SpringDescription spring) {
      void play() {
        if (mounted) {
          c.animateWith(cameoSpringSimulation(spring, from: c.value, to: 1));
        }
      }

      if (d == Duration.zero) {
        play();
      } else {
        _timers.add(Timer(d, play));
      }
    }

    for (var i = 0; i < _avatarCount; i++) {
      after(delays.avatars[i], _pops[i], CameoMotion.emptyAlbumEnterSpring);
    }
    after(delays.title, _texts[0], CameoMotion.albumContentSpring);
    after(delays.cta, _texts[1], CameoMotion.albumContentSpring);
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _clock.dispose();
    for (final c in [..._pops, ..._texts]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _avatar(int i, Widget child, Key key) => AnimatedBuilder(
    key: key,
    animation: Listenable.merge([_pops[i], _clock]),
    child: SizedBox.square(
      dimension: CameoLayout.emptyAlbumV6AvatarSize,
      child: ClipOval(child: child),
    ),
    builder: (context, child) {
      final p = _pops[i].value;
      return Opacity(
        opacity: p.clamp(0.0, 1.0),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.translationValues(0, floatYOf(i), 0)
            ..scaleByDouble(math.max(0, p), math.max(0, p), 1, 1),
          child: child,
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final lab = labV6.emptyAlbum;
    final height = MediaQuery.sizeOf(context).height;
    final rise = _reduceMotion ? 0.0 : CameoMotion.albumContentRise;
    const size = CameoLayout.emptyAlbumV6AvatarSize;
    final me = _avatar(
      0,
      ColoredBox(
        color: c.backgroundFillNeutralInverted,
        child: Center(
          child: CameoText(
            emptyAlbumInitialOf(widget.meName),
            key: EmptyAlbumV6.initialKey,
            style: CameoTextStyles.headingLg,
            color: c.avatarInitial,
            maxLines: 1,
          ),
        ),
      ),
      EmptyAlbumV6.meKey,
    );
    final avatars = widget.hasPartner
        ? SizedBox(
            width: 2 * size - CameoLayout.emptyAlbumV6AvatarOverlap,
            height: size,
            child: Stack(
              children: [
                Positioned(
                  key: const ValueKey('emptyAlbumV6.slot.me'),
                  left: 0,
                  top: 0,
                  child: me,
                ),
                Positioned(
                  key: const ValueKey('emptyAlbumV6.slot.partner'),
                  left: size - CameoLayout.emptyAlbumV6AvatarOverlap,
                  top: 0,
                  child: _avatar(
                    1,
                    Image(
                      image: AssetImage(lab.partnerPhoto),
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                    ),
                    EmptyAlbumV6.partnerKey,
                  ),
                ),
              ],
            ),
          )
        : me;
    return Positioned(
      key: EmptyAlbumV6.columnKey,
      left: 0,
      right: 0,
      top: emptyColumnTop(height),
      height: CameoLayout.emptyAlbumV6ColumnHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: CameoLayout.emptyAlbumV6Gap,
        children: [
          ExcludeSemantics(child: avatars),
          AlbumAppear(
            progress: _texts[0],
            rise: rise,
            child: CameoText(
              widget.title ?? lab.title,
              key: EmptyAlbumV6.titleKey,
              style: CameoTextStyles.headingMdStrong,
              color: c.foregroundNeutralBase,
              maxLines: 1,
            ),
          ),
          AlbumAppear(
            progress: _texts[1],
            rise: rise,
            child: widget.hasPartner
                ? SolidButton(
                    key: EmptyAlbumV6.ctaKey,
                    icon: widget.actionLabel == null
                        ? toastIconOf(lab.ctaIcon)
                        : null,
                    label: widget.actionLabel ?? lab.cta,
                    variant: SolidButtonVariant.gray,
                    onPress: widget.onImport,
                  )
                : SolidButton(
                    key: EmptyAlbumV6.ctaKey,
                    icon: CameoIconName.users,
                    label: appContent.v6.emptyAlbum.ctaNoPartner,
                    variant: SolidButtonVariant.gray,
                    onPress: widget.onConnect,
                  ),
          ),
        ],
      ),
    );
  }
}
