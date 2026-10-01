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
import '../../components/media_details.dart';
import '../../components/v6_layout.dart';
import '../../content/lab.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/navigation.dart';
import '../../state/album_store.dart';
import '../../state/captured_photo.dart';
import '../../api/api_error_text.dart';
import '../../api/cameo_api.dart';
import '../../content/app.g.dart';
import '../../state/session.dart';
import '../../state/share_service.dart';
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
  final video = photo.isVideo;
  return (
    key: photo.id,
    image: photo.thumbnailProvider,
    video: video,
    subject: InstantSubject(
      image: photo.provider,
      share: photo.image,
      albumPhotoId: photo.id,
      aspectRatio: photo.aspectRatio,
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
  bool _recording = false;
  Future<bool>? _recordStart;
  bool _uploading = false;
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
  bool _reviewLiked = false;
  String? _reviewError;

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
    final album = context.dependOnInheritedWidgetOfExactType<AlbumScope>()?.notifier;

    if (_thumb == null) {
      final latest = album?.latestCapture;
      _thumb = latest != null
          ? _captureThumb(latest)
          : SessionScope.read(context).usesBackend
          ? null
          : _partnerThumb(0);
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
          _openReview(
            CapturedPhoto.placeholder(LabV6.of(context).camera.viewfinder),
          );
        }
      });
    }
  }

  void _detachRoute() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = null;
  }

  void _armPartnerTimer() {
    if (SessionScope.read(context).usesBackend) return;
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
      final t = LabV6.of(context).camera.partnerToast;
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

  bool _openViewer(
    InstantSubject subject, {
    required bool fromThumbnail,
    Rect? rect,
  }) {
    if (!_isTop() || _reviewing || _busy) return false;
    setInstantSubject(subject);
    _toast.hide();
    CameoNav.openInstant(
      context,
      rect: rect ?? (fromThumbnail ? _rectOf(_thumbAnchor) : null),
      sourceRadius: rect != null
          ? CameoLayout.cameraV6ViewfinderRadius
          : CameoLayout.tabBarV6CameraThumbnailRadius,
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
      _reviewLiked = false;
      _reviewError = null;
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
    if (review == null ||
        _uploading ||
        reviewTransition(_stage, ReviewEvent.send) == null) {
      return false;
    }
    final album = AlbumScope.maybeRead(context);
    if (album?.usesBackend == true &&
        SessionScope.read(context).session.partner == null) {
      setState(() => _reviewError = 'couple:not_connected');
      return false;
    }
    if (album?.usesBackend == true) {
      setState(() {
        _uploading = true;
        _reviewError = null;
      });
      _toast.show(
        AppContent.of(context).v6.backend.uploading,
        CameoIconName.arrowUp,
      );
      album!.savePhotos([review.photo]).then((photos) {
        if (!mounted || _review?.key != review.key) return;
        setState(() => _uploading = false);
        if (photos.isEmpty) {
          setState(() => _reviewError = album.remote.error ?? 'upload_failed');
          _toast.show(
            apiErrorCodeText(
              album.remote.error ?? 'upload_failed',
              copy: AppContent.of(context),
            ),
            CameoIconName.x,
          );
          return;
        }
        _toast.hide();
        if (_reviewLiked) album.toggleLike(photos.first.id);
        _pendingThumb = _captureThumb(photos.first);
        _setPhase(ReviewPhase.send);
      });
      return true;
    }
    if (album != null) {
      final added = album.addCapture(review.photo);
      if (_reviewLiked) album.toggleLike(added.id);
      _pendingThumb = _captureThumb(added);
    }
    _setPhase(ReviewPhase.send);
    return true;
  }

  bool _onDiscard() {
    if (_uploading) return false;
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
    final sent = _review?.phase == ReviewPhase.send;
    setState(() => _review = null);
    _portal.hide();
    _armPartnerTimer();
    if (sent && _thumb != null) {
      _openViewer(
        _thumb!.subject,
        fromThumbnail: false,
        rect: cameraViewfinderRect(
          MediaQuery.sizeOf(context).width,
          height: MediaQuery.sizeOf(context).height,
        ),
      );
      _onThumbPopSettled();
    }
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
    setState(() {
      _busy = true;
      _shotKey++;
    });
    final live = SessionScope.read(context).usesBackend;
    try {
      final photo = await _viewfinder.capture();
      if (live && photo.source == CapturedPhotoSource.placeholder) {
        throw const ApiException('camera_unavailable');
      }
      await _viewfinder.flash();
      if (mounted && _focused) _deliver(photo);
    } catch (problem) {
      if (mounted) {
        _toast.show(
          apiErrorText(problem, copy: AppContent.of(context)),
          CameoIconName.x,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onRecordStart() {
    if (_busy || _reviewing) return;
    setState(() {
      _busy = true;
      _recording = true;
    });
    _recordStart = _startRecording();
  }

  Future<bool> _startRecording() async {
    if (!SessionScope.read(context).usesBackend &&
        _viewfinder.source == CameraViewfinderSource.placeholder) {
      return true;
    }
    try {
      await _viewfinder.startRecording(audio: _tab);
      return true;
    } catch (problem) {
      if (mounted) {
        _toast.show(
          apiErrorText(problem, copy: AppContent.of(context)),
          CameoIconName.x,
        );
      }
      return false;
    }
  }

  Future<void> _onRecordEnd(Duration elapsed) async {
    final start = _recordStart;
    if (start == null) return;
    _recordStart = null;
    final demo =
        !SessionScope.read(context).usesBackend &&
        _viewfinder.source == CameraViewfinderSource.placeholder;
    setState(() => _recording = false);
    try {
      if (!await start) return;
      final photo = demo
          ? (await _viewfinder.capture()).asVideo(elapsed)
          : await _viewfinder.stopRecording();
      if (mounted && _focused) _deliver(photo);
    } catch (problem) {
      if (mounted) {
        _toast.show(
          apiErrorText(problem, copy: AppContent.of(context)),
          CameoIconName.x,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onFlip() => setState(() => _facing = _facing.opposite);

  TabBarCameraSlots _slots() {
    final thumb = _thumb;
    return TabBarCameraSlots(
      thumbnail: TabBarThumbnail(
        key: CameraV6Screen.thumbnailKey,
        image: thumb?.image,
        video: thumb?.video ?? false,
        popKey: thumb?.key,
        anchor: _thumbAnchor,
        onPopSettled: _onThumbPopSettled,
        onPress: thumb == null || _busy ? null : _openThumbnail,
        semanticLabel: thumb == null
            ? AppContent.of(context).v6.backend.cameraEmptyThumbnail
            : thumb.video
            ? AppContent.of(context).v6.accessibility.lastVideo
            : AppContent.of(context).v6.accessibility.lastPhoto,
      ),
      onFlip: _onFlip,
      flipLabel: _facing == CameraFacing.back
          ? AppContent.of(context).v6.accessibility.frontCamera
          : AppContent.of(context).v6.accessibility.backCamera,
      flipDisabled: _reviewing || _busy,
      recording: _recording,
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
    final vf = cameraViewfinderRect(l.width, height: l.height);
    final shot = cameraShotCenter(l.width, height: l.height);
    final box = shotRingBox();
    final active =
        _entered &&
        _focused &&
        !_reviewing &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    final stack = Stack(
      key: CameraV6Screen.rootKey,
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          key: const ValueKey('cameraV6.layer.background'),
          child: ColoredBox(color: c.staticBlackBase),
        ),
        Positioned.fromRect(
          key: CameraV6Screen.viewfinderKey,
          rect: vf,
          child: CameraViewfinder(
            key: ValueKey(active),
            facing: _facing,
            active: active,
            controller: _viewfinder,
            placeholder: LabV6.of(context).camera.viewfinder,
            radius: CameoLayout.cameraV6ViewfinderRadius,
            flashColor: c.staticWhiteBase,
            shadeColor: c.staticBlackBase,
            cameraListLoader:
                widget.cameraListLoader ??
                (SessionScope.read(context).usesBackend
                    ? null
                    : () async => []),
            onSourceChange: (_) {
              if (mounted) setState(() {});
            },
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
            disabled:
                !active ||
                _viewfinder.source == CameraViewfinderSource.probing ||
                _reviewing ||
                (_busy && !_recording),
          ),
        ),
        Positioned(
          key: CameraV6Screen.toastKey,
          left: 0,
          right: 0,
          top: l.toastV6CameraTop,
          child: ToastV6Host(
            controller: _toast,
            variant: ToastV6Variant.elevated,
            placement: ToastV6Placement.camera,
            onPress: _toastShown && !SessionScope.read(context).usesBackend ? _openShared : null,
          ),
        ),
        if (!_tab)
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
        photo: ReviewPhoto(
          key: review.key,
          image: review.photo.image,
          videoUri:
              review.photo.isVideo &&
                  review.photo.source != CapturedPhotoSource.placeholder
              ? review.photo.uri
              : null,
        ),
        busy: _uploading,
        liked: _reviewLiked,
        onLike: () => setState(() => _reviewLiked = !_reviewLiked),
        onShare: () =>
            unawaited(ShareService.of(context).shareImages([review.photo.uri])),
        onMore: () => unawaited(
          showMediaDetails(
            context,
            video: review.photo.isVideo,
            width: review.photo.width,
            height: review.photo.height,
            duration: review.photo.videoDuration,
          ),
        ),
        error: _reviewError == null
            ? null
            : apiErrorCodeText(_reviewError!, copy: AppContent.of(context)),
        onErrorAction: _reviewError == 'couple:not_connected'
            ? () => unawaited(CameoNav.openConnect(context))
            : _reviewError == 'storage:quota_exceeded' &&
                  SessionScope.read(context).shouldOfferStorageUpgrade
            ? () => unawaited(CameoNav.openPayment(context))
            : null,
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
