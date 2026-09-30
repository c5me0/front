// Camera tab and in-call capture modes. Tab capture opens review before sending; in-
// call capture returns directly to the call overlay.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../components/call_camera_geometry.dart';
import '../../components/camera_viewfinder.dart';
import '../../components/review_overlay.dart';
import '../../components/shot.dart';
import '../../components/toast.dart';
import '../../components/toast_v6.dart';
import '../../components/v6_layout.dart';
import '../../content/lab.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/navigation.dart';
import '../../state/album_store.dart';
import '../../state/captured_photo.dart';
import '../instant_viewer/instant_subject.dart';

enum CameraV6Mode { tab, call }

typedef _Thumb = ({
  String key,
  ImageProvider image,
  bool video,
  InstantSubject subject,
});

_Thumb _partnerThumb(int seq) => (
  key: 'partner-$seq',
  image: partnerInstant.image,
  video: false,
  subject: partnerInstant,
);

_Thumb _captureThumb(AlbumPhoto photo) {
  final video = photo.capture?.isVideo ?? false;
  return (
    key: photo.id,
    image: photo.provider,
    video: video,
    subject: InstantSubject(
      image: photo.provider,
      share: photo.image,
      albumPhotoId: photo.id,
      video: video,
    ),
  );
}

typedef _Review = ({CapturedPhoto photo, String key, ReviewPhase phase});

class CameraV6Screen extends StatefulWidget {
  const CameraV6Screen({
    super.key,
    this.mode = CameraV6Mode.tab,
    this.cameraListLoader,
    this.review = false,
  });

  final CameraV6Mode mode;

  final bool review;

  final CameraListLoader? cameraListLoader;

  static const Key rootKey = ValueKey('cameraV6');
  static const Key viewfinderKey = ValueKey('cameraV6.viewfinder');
  static const Key shutterKey = ValueKey('cameraV6.shutter');
  static const Key shotKey = ValueKey('cameraV6.shot');
  static const Key thumbnailKey = ValueKey('cameraV6.thumbnail');
  static const Key toastKey = ValueKey('cameraV6.toast');
  static const Key barKey = ValueKey('cameraV6.bar');

  @override
  State<CameraV6Screen> createState() => CameraV6ScreenState();
}

class CameraV6ScreenState extends State<CameraV6Screen> {
  final ToastController _toast = ToastController();
  final GlobalKey _thumbAnchor = GlobalKey(debugLabel: 'cameraV6.thumbnail');
  final CameraViewfinderController _viewfinder = CameraViewfinderController();
  final OverlayPortalController _portal = OverlayPortalController(
    debugLabel: 'cameraV6.review',
  );
  final List<VoidCallback> _unregister = [];

  CameraFacing _facing = CameraFacing.back;
  int _shotKey = 0;
  bool _busy = false;
  bool _closed = false;

  bool _toastShown = false;
  Timer? _partnerTimer;
  int _partnerSeq = 0;

  _Thumb? _thumb;

  _Review? _review;
  int _reviewSeq = 0;
  _Thumb? _pendingThumb;
  bool _shutterSettle = false;
  bool _sendSettle = false;
  bool _deepLinkShown = false;

  bool _entered = false;
  bool _focused = true;
  Animation<double>? _routeAnimation;

  bool get _tab => widget.mode == CameraV6Mode.tab;
  bool get _reviewing => _review != null;

  ReviewStage get _stage => switch (_review?.phase) {
    null => ReviewStage.none,
    ReviewPhase.review => ReviewStage.review,
    ReviewPhase.send => ReviewStage.send,
    ReviewPhase.discard => ReviewStage.discard,
  };

  bool get partnerShared => _toastShown;
  CameraFacing get facing => _facing;
  String? get thumbnailKey => _thumb?.key;
  bool get thumbnailVideo => _thumb?.video ?? false;
  ReviewPhase? get reviewPhase => _review?.phase;

  bool _isTop() => mounted && CameoNav.isTop(context);

  @override
  void initState() {
    super.initState();
    _unregister
      ..add(
        FlowDemo.register(FlowDemoAction.cameraShutter, () {
          if (_busy || _closed || _reviewing) return false;
          if (_tab) _shutterSettle = true;
          _takePhoto();
          return true;
        }, isReady: _isTop),
      )
      ..add(
        FlowDemo.register(FlowDemoAction.reviewSend, () {
          if (!_tab || _review?.phase != ReviewPhase.review) return false;
          _sendSettle = true;
          return _onSend();
        }, isReady: _isTop),
      )
      ..add(
        FlowDemo.register(
          FlowDemoAction.cameraOpenShared,
          () => _tab && _toastShown && _openShared(),
          isReady: _isTop,
        ),
      );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_thumb == null) {
      final latest = AlbumScope.maybeRead(context)?.latestCapture;
      _thumb = latest != null ? _captureThumb(latest) : _partnerThumb(0);
    }
    final scope = context.dependOnInheritedWidgetOfExactType<CameoTabScope>();
    _focused = scope?.active ?? true;
    _armPartnerTimer();
    if (_entered || _routeAnimation != null) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      _onEntered();
    } else {
      _routeAnimation = animation..addStatusListener(_onRouteStatus);
    }
  }

  void _onRouteStatus(AnimationStatus status) {
    if (!status.isCompleted || !mounted) return;
    _detachRoute();
    setState(_onEntered);
  }

  void _onEntered() {
    _entered = true;

    if (_tab && widget.review && !_deepLinkShown) {
      _deepLinkShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openReview(CapturedPhoto.placeholder(labV6.camera.viewfinder));
        }
      });
    }
  }

  void _detachRoute() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = null;
  }

  void _armPartnerTimer() {
    if (!partnerToastArmed(
      tab: _tab,
      focused: _focused,
      shown: _toastShown,
      stage: _stage,
    )) {
      _partnerTimer?.cancel();
      _partnerTimer = null;
      return;
    }
    if (_partnerTimer != null) return;
    _partnerTimer = Timer(CameoMotion.instantPartnerDelay, () {
      _partnerTimer = null;
      if (!mounted) return;
      final t = labV6.camera.partnerToast;
      _toast.show(t.text, toastIconOf(t.icon));
      setState(() {
        _toastShown = true;
        _partnerSeq++;
        _thumb = _partnerThumb(_partnerSeq);
      });
    });
  }

  @override
  void dispose() {
    for (final unregister in _unregister) {
      unregister();
    }
    _partnerTimer?.cancel();
    _detachRoute();
    _toast.dispose();
    super.dispose();
  }

  static Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  bool _openViewer(InstantSubject subject, {required bool fromThumbnail}) {
    if (!_isTop() || _reviewing) return false;
    setInstantSubject(subject);
    _toast.hide();
    CameoNav.openInstant(
      context,
      rect: fromThumbnail ? _rectOf(_thumbAnchor) : null,
      sourceRadius: CameoLayout.tabBarV6CameraThumbnailRadius,
    );
    return true;
  }

  bool _openThumbnail() {
    final thumb = _thumb;
    return thumb != null && _openViewer(thumb.subject, fromThumbnail: true);
  }

  bool _openShared() => _openViewer(
    partnerInstant,
    fromThumbnail: identical(_thumb?.subject, partnerInstant),
  );

  void _openReview(CapturedPhoto photo) {
    if (reviewTransition(_stage, ReviewEvent.capture) == null) return;
    _reviewSeq++;
    setState(() {
      _review = (
        photo: photo,
        key: '${photo.uri}#$_reviewSeq',
        phase: ReviewPhase.review,
      );
    });
    _portal.show();
    _armPartnerTimer();
  }

  void _setPhase(ReviewPhase phase) {
    final review = _review;
    if (review == null) return;
    setState(
      () => _review = (photo: review.photo, key: review.key, phase: phase),
    );
  }

  bool _onSend() {
    final review = _review;
    if (review == null || reviewTransition(_stage, ReviewEvent.send) == null) {
      return false;
    }
    final album = AlbumScope.maybeRead(context);
    if (album != null) {
      _pendingThumb = _captureThumb(album.addCapture(review.photo));
    }
    _setPhase(ReviewPhase.send);
    return true;
  }

  bool _onDiscard() {
    if (reviewTransition(_stage, ReviewEvent.discard) == null) return false;
    _setPhase(ReviewPhase.discard);
    return true;
  }

  void _onLanded() {
    final next = _pendingThumb;
    _pendingThumb = null;
    if (next != null && mounted) setState(() => _thumb = next);
  }

  void _onReviewEntered() {
    if (!_shutterSettle) return;
    _shutterSettle = false;
    FlowDemo.settle(FlowDemoAction.cameraShutter);
  }

  void _onReviewExited(String key) {
    if (!mounted || _review?.key != key) return;
    if (reviewTransition(_stage, ReviewEvent.exited) == null) return;
    setState(() => _review = null);
    _portal.hide();
    _armPartnerTimer();
  }

  void _onThumbPopSettled() {
    if (!_sendSettle) return;
    _sendSettle = false;
    FlowDemo.settle(FlowDemoAction.reviewSend);
  }

  void _deliver(CapturedPhoto photo) {
    if (!mounted) return;
    if (_tab) {
      _openReview(photo);
      return;
    }
    if (_closed || !_isTop()) return;
    _closed = true;
    CameoNav.pop<CapturedPhoto>(context, photo);
  }

  Future<void> _takePhoto() async {
    if (_busy || _closed || _reviewing) return;
    _busy = true;
    setState(() => _shotKey++);
    final results = await Future.wait<Object?>([
      _viewfinder.capture(),
      _viewfinder.flash(),
    ]);
    _busy = false;
    if (mounted) _deliver(results.first! as CapturedPhoto);
  }

  void _onRecordStart() => _busy = true;

  Future<void> _onRecordEnd(Duration elapsed) async {
    final poster = await _viewfinder.capture();
    _busy = false;
    if (mounted) _deliver(poster.asVideo(elapsed));
  }

  void _onFlip() => setState(() => _facing = _facing.opposite);

  TabBarCameraSlots _slots() {
    final thumb = _thumb!;
    return TabBarCameraSlots(
      thumbnail: TabBarThumbnail(
        key: CameraV6Screen.thumbnailKey,
        image: thumb.image,
        video: thumb.video,
        popKey: thumb.key,
        anchor: _thumbAnchor,
        onPopSettled: _onThumbPopSettled,
        onPress: _openThumbnail,
        semanticLabel: thumb.video ? '마지막 동영상 보기' : '마지막 사진 보기',
      ),
      onFlip: _onFlip,
      flipLabel: _facing == CameraFacing.back ? '전면 카메라로 전환' : '후면 카메라로 전환',
      flipDisabled: _reviewing,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slots = _slots();
    if (_tab) {
      TabBarCamera.report(context, slots);
      TabBarVisibility.report(context, hidden: reviewHidesTabBar(_stage));
    }
    return CameoTheme(
      mode: CameoColorMode.dark,
      child: GlassBackdrop(
        tone: GlassBackdropTone.fromToken(
          CameoEffects.liquidGlassBackdropCameraV6,
        ),
        child: Builder(builder: (context) => _body(context, slots)),
      ),
    );
  }

  Widget _body(BuildContext context, TabBarCameraSlots slots) {
    final c = CameoTheme.colorsOf(context);
    final l = V6Layout.of(context);
    final vf = cameraViewfinderRect(l.width);
    final shot = cameraShotCenter(l.width);
    final box = shotRingBox();
    final stack = Stack(
      key: CameraV6Screen.rootKey,
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          key: const ValueKey('cameraV6.layer.background'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                labV6.camera.viewfinder,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                gaplessPlayback: true,
              ),
              ColoredBox(color: c.dimScrim),
            ],
          ),
        ),
        Positioned.fromRect(
          key: CameraV6Screen.viewfinderKey,
          rect: vf,
          child: CameraViewfinder(
            key: ValueKey(_entered && _focused),
            facing: _facing,
            active: _entered && _focused,
            controller: _viewfinder,
            placeholder: labV6.camera.viewfinder,
            radius: CameoLayout.cameraV6ViewfinderRadius,
            flashColor: c.staticWhiteBase,
            shadeColor: c.staticBlackBase,
            cameraListLoader: widget.cameraListLoader,
          ),
        ),
        Positioned(
          key: CameraV6Screen.shotKey,
          left: shot.dx - box / 2,
          top: shot.dy - box / 2,
          width: box,
          height: box,
          child: Shot(
            buttonKey: CameraV6Screen.shutterKey,
            onPhoto: _takePhoto,
            onRecordStart: _onRecordStart,
            onRecordEnd: _onRecordEnd,
            feedbackKey: _shotKey,
            disabled: _reviewing,
          ),
        ),
        if (_tab)
          Positioned(
            key: CameraV6Screen.toastKey,
            left: 0,
            right: 0,
            top: l.toastV6CameraTop,
            child: ToastV6Host(
              controller: _toast,
              variant: ToastV6Variant.elevated,
              placement: ToastV6Placement.camera,
              onPress: _openShared,
            ),
          )
        else
          Positioned(
            key: CameraV6Screen.barKey,
            left: 0,
            right: 0,
            bottom: 0,
            child: TabBarV6(
              selected: CameoTabs.camera,
              onSelect: (_) {},
              variant: TabBarV6Variant.camera,
              tone: TabBarV6Tone.camera,
              camera: slots,
              tabsDisabled: true,
            ),
          ),
      ],
    );
    if (!_tab) return stack;

    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _reviewLayer,
      child: stack,
    );
  }

  Widget _reviewLayer(BuildContext context) {
    final review = _review;
    if (review == null || !_focused) return const SizedBox.shrink();
    return CameoTheme(
      mode: CameoColorMode.dark,
      child: ReviewOverlay(
        key: ValueKey('cameraV6.review.${review.key}'),
        photo: ReviewPhoto(key: review.key, image: review.photo.image),
        phase: review.phase,
        onSend: _onSend,
        onDiscard: _onDiscard,
        onEntered: _onReviewEntered,
        onLanded: _onLanded,
        onExited: () => _onReviewExited(review.key),
      ),
    );
  }
}
