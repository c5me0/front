// Call interface with volume, highlights, photo sharing, capture overlays, and sleep
// mode. Device services own volume and brightness restoration.

//

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../components/aod_v6.dart';
import '../../components/call_bar_v6.dart';
import '../../components/call_camera_geometry.dart';
import '../../components/captured_card.dart';
import '../../components/caller_block.dart'
    show ExactLineBox, formatCallTime, parseCallTime;
import '../../components/photo_sheet.dart';
import '../../components/scrim_button.dart';
import '../../components/toast.dart';
import '../../components/toast_v6.dart';
import '../../components/volume_slider.dart';
import '../../content/lab.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/navigation.dart';
import '../../state/album_store.dart';
import '../../state/captured_photo.dart';
import '../../state/live_call.dart';
import '../../api/api_error_text.dart';
import '../../content/app.g.dart';
import '../../state/device_services.dart';
import '../../state/session.dart';
import 'call_entrance.dart';

abstract final class CallAppear {
  static const int callerBlock = 0;
  static const int controlBar = 1;
  static const int extra = 2;
}

typedef CallSleep = SleepPhase;

enum CallSlider { hidden, shown, exiting }

typedef _CardState = ({
  int key,
  List<CapturedCardItem> items,
  bool visible,
  bool instant,
});

final List<String> _sheetPreferred = [
  for (final p in labInCallV5.photoSheet.photos) p.image,
];

final Set<String> _sheetFigmaSelected = {
  for (final p in labInCallV5.photoSheet.photos)
    if (p.selected) p.image,
};

const String _hiresSuffix = '-hires';

CameoIconName _iconOf(String name) => CameoIconName.values.firstWhere(
  (i) => i.key == name,
  orElse: () => CameoIconName.x,
);

Size _sizeOf(AlbumPhoto photo) {
  if (photo.remote case final remote?) {
    return Size((remote.width ?? 1).toDouble(), (remote.height ?? 1).toDouble());
  }
  final capture = photo.capture;
  if (capture != null) return Size(capture.width, capture.height);
  final s = LabImages.sizes[photo.image];
  return s == null ? Size.zero : Size(s.width.toDouble(), s.height.toDouble());
}

CapturedCardItem cardItemOfPhoto(AlbumPhoto photo) {
  final size = _sizeOf(photo);
  return CapturedCardItem(
    key: photo.id,
    image: photo.provider,
    width: size.width,
    height: size.height,
    video: photo.capture?.videoDuration,
  );
}

CapturedCardItem cardItemOfCapture(CapturedPhoto photo) => CapturedCardItem(
  key: photo.uri,
  image: photo.image,
  width: photo.width,
  height: photo.height,
  video: photo.videoDuration,
);

List<AlbumPhoto> sheetPhotosOf(AlbumStore album) => photoSheetOrder([
  for (final s in album.sections)
    for (final p in [...s.photos, ...coveredContentPhotos(s.content)])
      (
        photo: p,
        id: p.id,
        file: p.capture == null ? p.image : null,
        today: s.isToday,
      ),
], _sheetPreferred);

typedef _InitialUi = ({
  _CardState? card,
  bool slider,
  bool highlight,
  bool sleep,
});

class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    this.state = CallState.base,
    this.demo = false,
    this.sheet,
    this.callId,
  });

  final String? callId;

  final CallState state;

  final bool demo;

  final PhotoSheetVariant? sheet;

  static const Key rootKey = ValueKey('callV6');
  static const Key minimizeKey = ValueKey('callV6.minimize');
  static const Key moonKey = ValueKey('callV6.moon');
  static const Key callerKey = ValueKey('callV6.caller');
  static const Key nameKey = ValueKey('callV6.name');
  static const Key timerKey = ValueKey('callV6.timer');
  static const Key backgroundKey = ValueKey('callV6.background');
  static const Key gradientKey = ValueKey('callV6.gradient');
  static const Key sliderSlotKey = ValueKey('callV6.slider');
  static const Key toastSlotKey = ValueKey('callV6.toast');

  static const Key cardLayerKey = ValueKey('callV6.cardLayer');
  static const Key sheetLayerKey = ValueKey('callV6.sheetLayer');

  static const Key dimLayerKey = ValueKey('callV6.dimLayer');
  static const Key navLayerKey = ValueKey('callV6.navLayer');
  static const Key barLayerKey = ValueKey('callV6.barLayer');
  static const Key aodLayerKey = ValueKey('callV6.aodLayer');

  @override
  State<CallScreen> createState() => CallScreenState();
}

class CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  LiveCallController? _live;
  String? _receivedPhotoId, _lastCallError;
  int _lastHighlight = 0;
  final ToastController _toast = ToastController();
  bool _toastPinned = false;

  bool _entered = false;
  Animation<double>? _routeAnimation;
  Timer? _extraTimer;

  final DemoTimeline _demo = DemoTimeline();

  final List<VoidCallback> _unregisterFlow = [];

  final Set<Timer> _later = {};

  late final int _timerBase = parseCallTime(labInCallV5.timer);
  final ValueNotifier<int> _elapsed = ValueNotifier(0);
  Timer? _ticker;

  CallSlider _slider = CallSlider.hidden;
  bool _sliderPinned = false;
  Timer? _sliderTimer;

  int _cardSeq = 0;
  _CardState? _card;
  bool _closeCardSettle = false;

  bool _sheetOpen = false;
  Set<String> _picked = {};

  Set<String> _sheetShared = {};
  bool _openSheetSettle = false;

  CallSleep _sleep = CallSleep.off;
  double? _volumeBeforeSleep;
  bool _sleepSettle = false;
  bool _endSettle = false;
  late final AodV6Progress _aod = AodV6Progress(
    vsync: this,
    onSettled: _onAodSettled,
  );

  bool _muted = false;

  late VolumeService _volume;
  late BrightnessService _brightness;

  _InitialUi? _initial;

  bool get sheetOpen => _sheetOpen;
  CallSleep get sleep => _sleep;
  CallSlider get slider => _slider;
  bool get muted => _muted;
  bool get cardVisible => _card?.visible ?? false;
  List<CapturedCardItem> get cardItems => _card?.items ?? const [];
  Set<String> get picked => Set.unmodifiable(_picked);
  bool get aod => _sleep == CallSleep.aod;
  AodV6Progress get aodProgress => _aod;

  Set<CallBarSlot> get barSelected {
    final s = callBarSelection(
      sliderShown: _slider == CallSlider.shown,
      sheetOpen: _sheetOpen,
      toastVisible: _toast.visible,
      muted: _muted,
    );
    return {
      if (s.volume) CallBarSlot.volume,
      if (s.camera) CallBarSlot.camera,
      if (s.highlight) CallBarSlot.highlight,
      if (s.microphone) CallBarSlot.microphone,
    };
  }

  PhotoSheetVariant get _variant =>
      widget.sheet ??
      SessionScope.maybeRead(context)?.session.prefs.photoSheetVariant ??
      PhotoSheetVariant.fallback;

  List<AlbumPhoto> get _sheetPhotos {
    final album = AlbumScope.maybeRead(context);
    return album == null ? const [] : sheetPhotosOf(album);
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (!mounted) return;
        final base = _elapsed.value;
        _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
          if (mounted) _elapsed.value = _live?.elapsed ?? base + t.tick;
        });
      }, debugLabel: 'CallScreen.timer')
      ..ensureVisualUpdate();

    _toast.addListener(_onToast);
    if (widget.demo) _demo.start(_demoSteps());
    bool ready() => _isTop;
    void reg(FlowDemoAction action, FlowDemoHandler handler) =>
        _unregisterFlow.add(FlowDemo.register(action, handler, isReady: ready));
    reg(FlowDemoAction.callVolume, _flowVolume);
    reg(FlowDemoAction.callHighlight, _flowHighlight);
    reg(FlowDemoAction.callCamera, _flowCamera);
    reg(FlowDemoAction.sheetLive, () => _sheetOpen && _onLive());
    reg(FlowDemoAction.callCloseCard, _flowCloseCard);
    reg(FlowDemoAction.callSleep, _flowSleep);
    reg(FlowDemoAction.aodEnd, _flowAodEnd);
    reg(FlowDemoAction.callEndCall, _onEnd);
  }

  void _onToast() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_live == null &&
        SessionScope.read(context).usesBackend &&
        !widget.demo) {
      _live = LiveCallScope.read(context);
      _live?.addListener(_onLiveState);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_live?.start(id: widget.callId));
      });
    }
    _volume = VolumeService.of(context);
    _brightness = BrightnessService.of(context);
    if (_initial == null) {
      final initial = _initialUi();
      _initial = initial;
      _card = initial.card;
      if (_card != null) _cardSeq = _card!.key;
    }
    if (_entered || _routeAnimation != null) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      _enter();
    } else {
      _routeAnimation = animation..addStatusListener(_onRouteStatus);
    }
  }

  void _onLiveState() {
    if (!mounted) return;
    final live = _live!;
    _elapsed.value = live.elapsed;
    setState(() => _muted = live.muted);
    if (live.receivedPhoto case final photo?
        when photo.id != _receivedPhotoId) {
      _receivedPhotoId = photo.id;
      _showCard([
        CapturedCardItem(
          key: photo.id,
          image: NetworkImage(photo.url),
          width: (photo.width ?? 1).toDouble(),
          height: (photo.height ?? 1).toDouble(),
        ),
      ]);
    }
    if (live.highlightEvents != _lastHighlight) {
      _lastHighlight = live.highlightEvents;
      _showHighlight();
    }
    if (live.error != null &&
        live.error != _lastCallError &&
        live.error != 'call_reconnecting') {
      _lastCallError = live.error;
      _toast.show(apiErrorCodeText(live.error!), CameoIconName.x);
    }
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status.isCompleted && mounted) setState(_enter);
  }

  void _detachRoute() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = null;
  }

  void _enter() {
    _detachRoute();
    if (_entered) return;
    _entered = true;
    final initial = _initial;
    final openSheet = widget.sheet != null && !widget.demo;
    if (initial == null) return;
    if (!initial.slider && !initial.highlight && !initial.sleep && !openSheet) {
      return;
    }
    _extraTimer = Timer(CameoMotion.staggerItem * CallAppear.extra, () {
      if (!mounted) return;
      if (initial.slider) _showSlider(pinned: true);
      if (initial.highlight) _onHighlight(pinned: true);
      if (initial.sleep) _startSleep();
      if (openSheet) {
        final preselect = _variant == PhotoSheetVariant.multi
            ? {
                for (final p in _sheetPhotos)
                  if (p.capture == null &&
                      _sheetFigmaSelected.contains(p.image))
                    p.id,
              }
            : <String>{};
        setState(() {
          _picked = preselect;
          _sheetOpen = true;
        });
      }
    });
  }

  _InitialUi _initialUi() {
    final flags = callInitialFlags(widget.state.param);
    _CardState cardOf(CapturedCardItem item) =>
        (key: 1, items: [item], visible: true, instant: true);
    _CardState? card;
    switch (flags.card) {
      case null:
        card = null;
      case CapturedOrientation.landscape:
        final album = AlbumScope.maybeRead(context);
        final landscape = album == null
            ? null
            : sheetPhotosOf(album).where((p) {
                final s = _sizeOf(p);
                return capturedCardOrientation(s.width, s.height) ==
                    CapturedOrientation.landscape;
              }).firstOrNull;
        card = cardOf(
          landscape != null ? cardItemOfPhoto(landscape) : _figmaCardItem(),
        );
      case CapturedOrientation.portrait:
        card = cardOf(_figmaCardItem());
    }
    return (
      card: card,
      slider: flags.slider,
      highlight: flags.highlight,
      sleep: flags.sleep,
    );
  }

  CapturedCardItem _figmaCardItem() {
    final file = labInCallV5.capturedCard.image;
    final size = LabImages.sizes[file];
    return CapturedCardItem(
      key: file,
      image: AssetImage(file),
      width: (size?.width ?? 0).toDouble(),
      height: (size?.height ?? 0).toDouble(),
    );
  }

  bool get _isTop => mounted && CameoNav.isTop(context);

  void _after(Duration delay, VoidCallback fn) {
    late final Timer timer;
    timer = Timer(delay, () {
      _later.remove(timer);
      if (mounted) fn();
    });
    _later.add(timer);
  }

  void _clearSliderTimer() {
    _sliderTimer?.cancel();
    _sliderTimer = null;
  }

  void _hideSlider() {
    _clearSliderTimer();
    _sliderPinned = false;
    if (_slider == CallSlider.shown) {
      setState(() => _slider = CallSlider.exiting);
    }
  }

  void _armSliderTimer() {
    _clearSliderTimer();
    if (_sliderPinned) return;
    _sliderTimer = Timer(CameoMotion.sliderIdleHide, () {
      if (mounted) _hideSlider();
    });
  }

  void _showSlider({bool pinned = false}) {
    _toast.hide();
    setState(() {
      _toastPinned = false;
      _sliderPinned = pinned;
      _slider = CallSlider.shown;
    });
    _armSliderTimer();
  }

  void _onHighlight({bool pinned = false}) {
    if (_live != null) {
      _live!.addHighlight().then((ok) {
        if (mounted && ok) _showHighlight();
      });
      return;
    }
    _showHighlight(pinned: pinned);
  }

  void _showHighlight({bool pinned = false}) {
    _closeSheet();
    _hideSlider();
    setState(() => _toastPinned = pinned);
    final t = labV6.call.highlightToast;
    _toast.show(t.text, toastIconOf(t.icon));
    HapticFeedback.mediumImpact();
  }

  void _showCard(List<CapturedCardItem> items) {
    if (items.isEmpty || !mounted) return;
    setState(() {
      _cardSeq++;
      _card = (key: _cardSeq, items: items, visible: true, instant: false);
    });
  }

  void _closeCard() {
    final card = _card;
    if (card == null || !card.visible) return;
    setState(
      () => _card = (
        key: card.key,
        items: card.items,
        visible: false,
        instant: card.instant,
      ),
    );
  }

  void _onCardHidden(int key) {
    final card = _card;
    if (card != null && card.key == key && !card.visible) {
      setState(() => _card = null);
    }
    if (_closeCardSettle) {
      _closeCardSettle = false;
      FlowDemo.settle(FlowDemoAction.callCloseCard);
    }
  }

  void _openPhotoSheet([Set<String> preselect = const {}]) {
    _hideSlider();
    _toast.hide();
    setState(() {
      _picked = {...preselect};
      _sheetOpen = true;
    });
  }

  void _closeSheet() {
    if (_sheetOpen) setState(() => _sheetOpen = false);
  }

  List<PhotoSheetItem> _sheetItems(List<AlbumPhoto> photos) {
    final multi = _variant == PhotoSheetVariant.multi;
    return [
      for (final p in photos)
        PhotoSheetItem(
          id: p.id,
          image: p.provider,
          checked: multi
              ? _picked.contains(p.id)
              : p.shared || _sheetShared.contains(p.id),
        ),
    ];
  }

  void _markShared(AlbumStore album, List<String> ids) {
    album.markShared(ids);
    setState(() => _sheetShared = {..._sheetShared, ...ids});
  }

  void _onTapPhoto(String id) {
    final album = AlbumScope.maybeRead(context);
    if (album == null) return;
    final photo = sheetPhotosOf(album).where((p) => p.id == id).firstOrNull;
    if (photo == null) return;
    if (_variant == PhotoSheetVariant.instant) {
      if (_live != null) {
        unawaited(_shareRemote([photo]));
        return;
      }
      _markShared(album, [photo.id]);
      _closeSheet();
      _showCard([cardItemOfPhoto(photo)]);
      return;
    }
    setState(() {
      _picked = {..._picked};
      if (!_picked.remove(photo.id)) _picked.add(photo.id);
    });
  }

  void _onShare() {
    final album = AlbumScope.maybeRead(context);
    if (album == null) return;
    final chosen = [
      for (final p in sheetPhotosOf(album))
        if (_picked.contains(p.id)) p,
    ];
    if (chosen.isEmpty) return;
    if (_live != null) {
      unawaited(_shareRemote(chosen));
      return;
    }
    _markShared(album, [for (final p in chosen) p.id]);
    _closeSheet();
    _showCard([for (final p in chosen) cardItemOfPhoto(p)]);
  }

  Future<void> _shareRemote(List<AlbumPhoto> photos) async {
    final album = AlbumScope.read(context);
    final sent = <AlbumPhoto>[];
    for (final photo in photos) {
      if (await _live!.sharePhoto(photo.id) != null) sent.add(photo);
      if (!mounted) return;
    }
    if (sent.isEmpty) return;
    _markShared(album, sent.map((p) => p.id).toList());
    _closeSheet();
    _showCard(sent.map(cardItemOfPhoto).toList());
  }

  bool _onLive() {
    if (!_isTop) return false;
    _closeSheet();
    final album = AlbumScope.read(context);
    CameoNav.openCameraFromCall(context).then((photo) async {
      if (photo == null || !mounted) return;
      if (_live != null) {
        final saved = await album.savePhotos([photo]);
        if (!mounted) return;
        if (saved.isEmpty) {
          _toast.show(
            apiErrorCodeText(album.remote.error ?? 'upload_failed'),
            CameoIconName.x,
          );
        } else {
          await _shareRemote(saved);
        }
      } else {
        _showCard([cardItemOfCapture(photo)]);
      }
    });
    return true;
  }

  void _setSleep(CallSleep next) {
    setState(() => _sleep = next);
    _aod.update(
      next == CallSleep.aod,
      reduceMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
    );
  }

  void _onAodSettled(bool asleep) {
    if (asleep && _sleepSettle) {
      _sleepSettle = false;
      FlowDemo.settle(FlowDemoAction.callSleep);
    }
    if (!asleep && _endSettle) {
      _endSettle = false;
      FlowDemo.settle(FlowDemoAction.aodEnd);
    }
  }

  bool _startSleep() {
    final next = sleepTransition(_sleep, SleepEvent.moon);
    if (next == null) return false;
    _closeSheet();
    _hideSlider();
    _toast.hide();
    _toastPinned = false;
    _closeCard();
    final volume = _volume;
    volume.get().then((v) {
      _volumeBeforeSleep = v;
      volume.fadeTo(CameoMotion.sleepVolumeTarget, CameoMotion.sleepVolumeFade);
    });
    _brightness.set(0);
    _setSleep(next);
    return true;
  }

  bool _endSleep() {
    final next = sleepTransition(_sleep, SleepEvent.end);
    if (next == null) return false;
    _brightness.restore();
    final before = _volumeBeforeSleep;
    _volumeBeforeSleep = null;
    if (before != null) _volume.fadeTo(before, CameoMotion.sleepWakeVolume);
    _setSleep(next);
    return true;
  }

  bool _onEnd() {
    if (!_isTop) return false;
    if (_live?.hasCall == true) {
      _live!.end().then((_) {
        if (mounted && _isTop) CameoNav.pop(context);
      });
      return true;
    }
    return CameoNav.pop(context);
  }

  void _onMinimize() {
    if (_isTop) CameoNav.pop(context);
  }

  void _onBar(CallBarSlot slot) {
    switch (slot) {
      case CallBarSlot.volume:
        _closeSheet();
        if (_slider == CallSlider.shown) {
          _hideSlider();
        } else {
          _showSlider();
        }
      case CallBarSlot.microphone:
        if (_live != null) {
          _live!.setMuted(!_live!.muted);
        } else {
          setState(() => _muted = !_muted);
        }
      case CallBarSlot.camera:
        if (_sheetOpen) {
          _closeSheet();
        } else {
          _openPhotoSheet();
        }
      case CallBarSlot.highlight:
        _onHighlight();
      case CallBarSlot.end:
        _onEnd();
    }
  }

  Future<bool> _moveVolumeForDemo() async {
    final volume = _volume;
    final from = await volume.get();
    const d = CallDemoV6.volumeMoveDelta;
    final to = from + d <= 1 ? from + d : from - d;
    return volume.fadeTo(to, CallDemoV6.volumeMoveDuration);
  }

  int _demoPortraitIndex(List<AlbumPhoto> photos) {
    final file = labInCallV5.capturedCard.image.replaceAll(_hiresSuffix, '');
    final i = photos.indexWhere((p) => p.capture == null && p.image == file);
    return i < 0 ? 0 : i;
  }

  List<DemoStep> _demoSteps() => [
    (
      at: CallDemoV6.volume,
      run: () {
        if (_slider != CallSlider.shown) _showSlider();
      },
    ),
    (at: CallDemoV6.volumeMove, run: _moveVolumeForDemo),
    (at: CallDemoV6.highlight, run: _onHighlight),
    (
      at: CallDemoV6.sheet,
      run: () {
        if (!_sheetOpen) _openPhotoSheet();
      },
    ),
    (
      at: CallDemoV6.pick,
      run: () {
        final photos = _sheetPhotos;
        final i = _variant == PhotoSheetVariant.instant
            ? _demoPortraitIndex(photos)
            : 0;
        if (_sheetOpen && i < photos.length) _onTapPhoto(photos[i].id);
      },
    ),
    (
      at: CallDemoV6.pickSecond,
      run: () {
        final photos = _sheetPhotos;
        if (_variant == PhotoSheetVariant.multi &&
            _sheetOpen &&
            photos.length > 1 &&
            !_picked.contains(photos[1].id)) {
          _onTapPhoto(photos[1].id);
        }
      },
    ),
    (
      at: CallDemoV6.share,
      run: () {
        if (_variant == PhotoSheetVariant.multi && _sheetOpen) _onShare();
      },
    ),
    (at: CallDemoV6.closeCard, run: _closeCard),
    (at: CallDemoV6.sleep, run: _startSleep),
    (at: CallDemoV6.sleepEnd, run: _endSleep),
  ];

  bool _flowVolume() {
    if (_slider != CallSlider.shown) _showSlider();
    _moveVolumeForDemo().then((_) {
      if (mounted) FlowDemo.settle(FlowDemoAction.callVolume);
    });
    return true;
  }

  bool _flowHighlight() {
    _onHighlight();
    _after(
      CameoMotion.durationBase,
      () => FlowDemo.settle(FlowDemoAction.callHighlight),
    );
    return true;
  }

  bool _flowCamera() {
    if (_sheetOpen) return false;
    _openSheetSettle = true;
    _openPhotoSheet();
    return true;
  }

  bool _flowCloseCard() {
    if (_card?.visible ?? false) {
      _closeCardSettle = true;
      _closeCard();
    } else {
      _after(
        Duration.zero,
        () => FlowDemo.settle(FlowDemoAction.callCloseCard),
      );
    }
    return true;
  }

  bool _flowSleep() {
    if (sleepTransition(_sleep, SleepEvent.moon) == null) return false;
    _sleepSettle = true;
    return _startSleep();
  }

  bool _flowAodEnd() {
    if (sleepTransition(_sleep, SleepEvent.end) == null) return false;
    _endSettle = true;
    return _endSleep();
  }

  @override
  void dispose() {
    _live?.removeListener(_onLiveState);
    for (final unregister in _unregisterFlow) {
      unregister();
    }

    if (_sleep == CallSleep.aod) {
      _brightness.restore();
      final before = _volumeBeforeSleep;
      if (before != null) _volume.set(before);
    }
    _demo.cancel();
    _detachRoute();
    _extraTimer?.cancel();
    _ticker?.cancel();
    _clearSliderTimer();
    for (final t in _later) {
      t.cancel();
    }
    _later.clear();
    _toast
      ..removeListener(_onToast)
      ..dispose();
    _elapsed.dispose();
    _aod.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CameoTheme(
      mode: CameoColorMode.dark,
      child: GlassBackdrop(
        tone: GlassBackdropTone.fromToken(
          CameoEffects.liquidGlassBackdropCallV6,
        ),
        child: Builder(builder: _body),
      ),
    );
  }

  Widget _caller(CameoPalette c) {
    return ValueListenableBuilder<int>(
      valueListenable: _elapsed,
      builder: (context, elapsed, _) {
        final live = _live;
        final name = live == null
            ? labInCallV5.name
            : SessionScope.read(context).session.partner?.name ??
                  appContent.v6.backend.partnerName;
        final copy = appContent.v6.backend;
        final time = live == null
            ? formatCallTime(_timerBase + elapsed)
            : live.error == 'call_reconnecting'
            ? copy.callReconnecting
            : live.active
            ? formatCallTime(live.elapsed)
            : live.hasCall
            ? copy.callRinging
            : copy.callEnded;
        return Semantics(
          label: '$name, 통화 시간 $time',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CameoLayout.callV6CallerPaddingX,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExactLineBox(
                  name,
                  CameoTextStyles.display,
                  c.staticWhiteBase,
                  key: CallScreen.nameKey,
                ),
                ExactLineBox(
                  time,
                  CameoTextStyles.headingSm,
                  c.staticWhiteMuted,
                  key: CallScreen.timerKey,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final w = MediaQuery.sizeOf(context).width;
    final album = _maybeWatchAlbum(context);
    final photos = album == null ? const <AlbumPhoto>[] : sheetPhotosOf(album);
    final card = _card;
    final asleep = _sleep == CallSleep.aod;
    final nav = callNavButtons(w);

    Widget aodShift(double distance, Widget child) => AnimatedBuilder(
      animation: _aod.ui,
      child: child,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _aod.ui.value * distance),
        child: child,
      ),
    );

    return ColoredBox(
      key: CallScreen.rootKey,
      color: c.backgroundCanvasBase,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            key: CallScreen.backgroundKey,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: CameoLayout.callV6BackgroundPhotoOpacity,
                  child: Image.asset(
                    labInCallV5.background,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    gaplessPlayback: true,
                  ),
                ),
                AnimatedBuilder(
                  animation: _aod.dim,
                  builder: (context, child) => Opacity(
                    opacity: 1 - _aod.dim.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                  child: DecoratedBox(
                    key: CallScreen.gradientKey,
                    decoration: BoxDecoration(
                      gradient: c.gradients.callBackgroundV6,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned.fill(
            key: CallScreen.dimLayerKey,
            child: AodV6Dim(dim: _aod.dim),
          ),
          Positioned(
            key: CallScreen.callerKey,
            left: 0,
            right: 0,
            top: CameoLayout.callV6CallerTop,
            child: CallEntrance(
              play: _entered,
              index: CallAppear.callerBlock,
              rise: CameoMotion.staggerRise,
              child: _caller(c),
            ),
          ),
          if (card != null)
            Positioned.fill(
              key: CallScreen.cardLayerKey,
              child: CapturedCard(
                key: ValueKey('callV6.card.${card.key}'),
                items: card.items,
                visible: card.visible,
                appearInstantly: card.instant,
                onClose: _closeCard,
                onHidden: () => _onCardHidden(card.key),
              ),
            ),

          Positioned.fill(
            key: CallScreen.navLayerKey,
            child: IgnorePointer(
              ignoring: asleep,
              child: aodShift(
                aodControlOffsets.nav,
                Stack(
                  children: [
                    Positioned(
                      left: nav.leftX,
                      top: nav.top,
                      child: ScrimButton(
                        key: CallScreen.minimizeKey,
                        size: ScrimButtonSize.md,
                        tone: ScrimButtonTone.light,
                        icon: _iconOf(labV6.call.navIcons[0]),
                        semanticLabel: '통화 화면 닫기',
                        onPress: _onMinimize,
                      ),
                    ),
                    Positioned(
                      left: nav.rightX,
                      top: nav.top,
                      child: ScrimButton(
                        key: CallScreen.moonKey,
                        size: ScrimButtonSize.md,
                        tone: ScrimButtonTone.light,
                        icon: _iconOf(labV6.call.navIcons[1]),
                        semanticLabel: '취침 모드',
                        onPress: _startSleep,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_entered)
            Positioned.fill(
              key: CallScreen.sheetLayerKey,
              child: PhotoSheet(
                open: _sheetOpen,
                variant: _variant,
                items: _sheetItems(photos),
                selectedCount: _picked.length,
                onTapPhoto: (item, _) => _onTapPhoto(item.id),
                onShare: _onShare,
                onLive: _onLive,
                onClose: _closeSheet,
                onOpened: () {
                  if (!_openSheetSettle) return;
                  _openSheetSettle = false;
                  FlowDemo.settle(FlowDemoAction.callCamera);
                },
                livePreview: _entered && _sheetOpen,
              ),
            ),
          if (_slider != CallSlider.hidden)
            Positioned(
              key: CallScreen.sliderSlotKey,
              left: 0,
              right: 0,
              bottom: callBottomNavHeight(),
              child: VolumeSlider(
                visible: _slider == CallSlider.shown,
                onHidden: () {
                  if (_slider == CallSlider.exiting) {
                    setState(() => _slider = CallSlider.hidden);
                  }
                },
                onInteraction: (phase) => phase == VolumeSliderInteraction.start
                    ? _clearSliderTimer()
                    : _armSliderTimer(),
              ),
            ),

          Positioned(
            key: CallScreen.barLayerKey,
            left: 0,
            right: 0,
            bottom: 0,
            child: CallEntrance(
              play: _entered,
              index: CallAppear.controlBar,
              rise: callBottomNavHeight(),
              fade: false,
              child: IgnorePointer(
                ignoring: asleep,
                child: aodShift(
                  aodControlOffsets.bar,
                  CallBarV6(selected: barSelected, onPress: _onBar),
                ),
              ),
            ),
          ),
          Positioned.fill(
            key: CallScreen.aodLayerKey,
            child: AodV6EndButton(
              button: _aod.button,
              asleep: asleep,
              onEnd: _endSleep,
            ),
          ),
          Positioned(
            key: CallScreen.toastSlotKey,
            left: 0,
            right: 0,
            bottom: callBottomNavHeight(),
            child: ToastV6Host(
              controller: _toast,
              variant: ToastV6Variant.flat,
              autoHide: !_toastPinned,
            ),
          ),
        ],
      ),
    );
  }
}

AlbumStore? _maybeWatchAlbum(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<AlbumScope>()?.notifier;
