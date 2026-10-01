// Unified photo viewer with source zoom, horizontal paging, thumbnail navigation,
// favorites, sharing, and soft deletion.

import 'dart:async';

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../components/confirm_sheet.dart';
import '../../components/scrim_button.dart';
import '../../components/scrim_pill.dart';
import '../../components/thumb_strip.dart';
import '../../components/toast.dart' show toastIconOf;
import '../../components/v6_layout.dart';
import '../../content/app.g.dart';
import '../../content/lab.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/navigation.dart';
import '../../state/album_store.dart';
import '../../state/device_services.dart';
import '../home_timeline/album_timeline_model.dart';
import '../home_timeline/cell_locator.dart';
import '../instant_viewer/instant_subject.dart';
import 'viewer_presence.dart';

abstract final class PhotoViewerDevDemo {
  static const Duration pageNext = Duration(milliseconds: 1800);
  static const Duration stripJump = Duration(milliseconds: 3400);
  static const Duration pageBack = Duration(milliseconds: 5000);
  static const Duration drag = Duration(milliseconds: 6800);
  static const Duration dragDuration = Duration(milliseconds: 450);
  static const Duration dragHold = Duration(milliseconds: 500);

  static const int jump = 2;

  static const double pageDx = 0.6;
  static const double dragFraction = 0.3;
}

class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.sectionId,
    required this.index,
    this.subject,
  });

  final String sectionId;

  final int index;

  final InstantSubject? subject;

  static const Key cardKey = ValueKey('photoViewer.card');
  static const Key pillKey = ValueKey('photoViewer.pill');
  static const Key closeKey = ValueKey('photoViewer.close');
  static const Key topRowKey = ValueKey('photoViewer.topRow');
  static const Key stripKey = ValueKey('photoViewer.strip');
  static const Key dateKey = ValueKey('photoViewer.date');
  static const Key datePillKey = ValueKey('photoViewer.datePill');
  static const Key gestureKey = ValueKey('photoViewer.gesture');
  static const Key dragKey = ValueKey('photoViewer.drag');
  static const Key deleteSheetKey = ValueKey('photoViewer.deleteSheet');
  static Key pageKey(String photoId) => ValueKey('photoViewer.page.$photoId');

  @override
  State<PhotoViewerScreen> createState() => PhotoViewerScreenState();
}

typedef _ViewerPage = ({String key, ImageProvider image});

class PhotoViewerScreenState extends State<PhotoViewerScreen>
    with TickerProviderStateMixin {
  final List<VoidCallback> _unregister = [];
  final List<Timer> _timers = [];

  String? _sectionId;

  String? _photoId;
  bool _resolved = false;

  bool _retarget = true;

  AlbumPhoto? _knownPhoto;
  int _knownIndex = 0;

  int _index = 0;
  int _count = 0;
  List<AlbumPhoto> _photos = const [];

  bool _localLiked = false;

  late final AnimationController _pos;
  late final AnimationController _strip;

  late final AnimationController _tx;
  late final AnimationController _ty;
  late final AnimationController _scale;
  late final AnimationController _dimK;
  late final AnimationController _chromeK;

  int _axis = 0;
  Offset _downAt = Offset.zero;
  Offset _drag = Offset.zero;

  CameoViewerRoute<Object?>? _route;

  bool _sheetOpen = false;
  bool _sheetMounted = false;

  final DemoTimeline _devDemo = DemoTimeline();
  AnimationController? _demoDrag;

  @visibleForTesting
  String? get photoId => _photoId;
  @visibleForTesting
  double get pagePosition => _pos.value;
  @visibleForTesting
  double get stripPosition => _strip.value;
  @visibleForTesting
  bool get albumMode => _sectionId != null;
  @visibleForTesting
  bool get partnerLiked => _localLiked;
  @visibleForTesting
  ({double tx, double ty, double scale, double dim, double chrome})
  get dragLook => (
    tx: _tx.value,
    ty: _ty.value,
    scale: _scale.value,
    dim: _dimK.value,
    chrome: _chromeK.value,
  );

  double get _width => MediaQuery.sizeOf(context).width;
  double get _height => MediaQuery.sizeOf(context).height;
  double get _cardH => viewerCardRectV6(_width).height;
  double get _step => viewerPageStep(_width);

  @override
  void initState() {
    super.initState();
    _pos = AnimationController.unbounded(
      vsync: this,
      value: widget.index.toDouble(),
    );
    _strip = AnimationController.unbounded(
      vsync: this,
      value: widget.index.toDouble(),
    );
    _tx = AnimationController.unbounded(vsync: this);
    _ty = AnimationController.unbounded(vsync: this);
    _scale = AnimationController.unbounded(vsync: this, value: 1);
    _dimK = AnimationController.unbounded(vsync: this, value: 1)
      ..addListener(_onDim);
    _chromeK = AnimationController.unbounded(vsync: this);
    ViewerPresence.set(true);
    bool ready() => mounted && CameoNav.isTop(context);
    _unregister
      ..add(
        FlowDemo.register(FlowDemoAction.viewerLike, _demoLike, isReady: ready),
      )
      ..add(
        FlowDemo.register(
          FlowDemoAction.viewerStrip,
          _demoStrip,
          isReady: ready,
        ),
      );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = CameoViewerRoute.maybeOf(context);
    if (_resolved) return;
    _resolved = true;
    final album = AlbumScope.maybeRead(context);
    final subject = widget.subject;
    if (subject != null) {
      _retarget = false;
      final id = subject.albumPhotoId;
      final at = id == null ? null : album?.locate(id);
      if (at != null) {
        _sectionId = at.sectionId;
        _photoId = at.photo.id;
        _knownPhoto = at.photo;
        _knownIndex = at.index;
      }
    } else {
      final photo = album?.photoAt(widget.sectionId, widget.index);
      _sectionId = widget.sectionId;
      _photoId = photo?.id;
      _knownPhoto = photo;
      _knownIndex = widget.index < 0 ? 0 : widget.index;

      final id = photo?.id;
      if (_route != null && _route!.currentSource == null && id != null) {
        _timers.add(
          Timer(springSettleDuration(CameoMotion.viewerZoomSpring), () {
            final route = _route;
            if (!mounted || route == null || route.currentSource != null) {
              return;
            }
            final rect = locateAlbumCell(id);
            if (rect == null) return;
            ViewerSource.set(id, rect);
            route.sourceKey = id;
          }),
        );
      }
    }
    _pos.value = _knownIndex.toDouble();
    _strip.value = _knownIndex.toDouble();
    if (CameoRoutes.demoOf(CameoLocation.of(context))) _startDevDemo();
  }

  @override
  void dispose() {
    for (final u in _unregister) {
      u();
    }
    for (final t in _timers) {
      t.cancel();
    }
    _devDemo.cancel();
    _demoDrag?.dispose();
    ViewerPresence.set(false);
    _pos.dispose();
    _strip.dispose();
    _tx.dispose();
    _ty.dispose();
    _scale.dispose();
    _dimK.dispose();
    _chromeK.dispose();
    super.dispose();
  }

  void _onDim() => _route?.dimScale.value = _dimK.value;

  bool get _isAlbum => _sectionId != null && _photoId != null;

  bool _like() {
    if (_isAlbum) {
      final photo = _knownPhoto;
      if (photo == null) return false;
      AlbumScope.read(context).toggleLike(photo.id);
      return true;
    }
    if (widget.subject == null) return false;
    setState(() => _localLiked = !_localLiked);
    return true;
  }

  bool _demoLike() {
    if (!_like()) return false;
    _timers.add(
      Timer(springSettleDuration(CameoMotion.heartPopSpring), () {
        FlowDemo.settle(FlowDemoAction.viewerLike);
        SchedulerBinding.instance.ensureVisualUpdate();
      }),
    );
    return true;
  }

  bool _demoStrip() {
    if (_count <= 1) return false;
    final target = _index + 1 < _count ? _index + 1 : _index - 1;
    _jumpTo(target);
    _timers.add(
      Timer(springSettleDuration(CameoMotion.stripV6CenterSpring), () {
        FlowDemo.settle(FlowDemoAction.viewerStrip);
        SchedulerBinding.instance.ensureVisualUpdate();
      }),
    );
    return true;
  }

  Future<void> _share() async {
    final service = ShareService.of(context);
    if (_isAlbum) {
      final photo = _knownPhoto;
      if (photo == null) return;
      final album = AlbumScope.read(context);
      final outcome = await service.shareImages([photo.image]);
      if (outcome == ShareOutcome.shared) album.markShared([photo.id]);
      return;
    }
    final subject = widget.subject;
    if (subject != null) await service.shareImages([subject.share]);
  }

  void _requestDelete() {
    if (!_isAlbum || _knownPhoto == null) return;
    setState(() {
      _sheetMounted = true;
      _sheetOpen = true;
    });
  }

  Future<void> _confirmDelete() async {
    final photo = _knownPhoto;
    setState(() => _sheetOpen = false);
    if (photo == null) return;
    final ok = await AlbumScope.read(context).removePhotos([photo.id]);
    if (mounted && ok) CameoNav.pop(context);
  }

  void _close() => CameoNav.pop(context);

  void _springTo(AnimationController c, double to, SpringDescription spring) =>
      c.animateWith(
        cameoSpringSimulation(
          spring,
          from: c.value,
          to: to,
          velocity: c.velocity,
        ),
      );

  void _onPage(int target) {
    if (target < 0 || target >= _photos.length) return;
    final next = _photos[target];
    setState(() => _photoId = next.id);
    if (!_retarget) return;
    final rect = locateAlbumCell(next.id);
    if (rect != null) {
      ViewerSource.set(next.id, rect);
      _route?.sourceKey = next.id;
    }
  }

  /// RN `jumpTo`.
  void _jumpTo(int k) {
    if (k < 0 || k >= _count) return;
    if (k == _index) {
      _springTo(_strip, k.toDouble(), CameoMotion.stripV6CenterSpring);
      return;
    }
    _pos.stop();
    _pos.value = stripJumpStart(_index, k);
    _springTo(_pos, k.toDouble(), CameoMotion.viewerPageSpring);
    _springTo(_strip, k.toDouble(), CameoMotion.stripV6CenterSpring);
    _onPage(k);
  }

  void _stopDrag() {
    for (final c in [_tx, _ty, _scale, _dimK, _chromeK]) {
      c.stop();
    }
  }

  void _followPage(double dx) {
    _pos.value = viewerPagePosition(_index, _count, dx, _step);

    _strip.stop();
    _strip.value = _pos.value;
  }

  void _releasePage(double dx, double vx) {
    if (!mounted) return;
    final i = _index;
    final target = viewerPageTarget(i, _count, dx, vx, _step);
    _pos.animateWith(
      cameoSpringSimulation(
        CameoMotion.viewerPageSpring,
        from: _pos.value,
        to: target.toDouble(),
        velocity: -vx / _step,
      ),
    );
    _springTo(_strip, target.toDouble(), CameoMotion.stripV6CenterSpring);
    if (target != i) _onPage(target);
  }

  void _followDrag(double dx, double dy) {
    final look = viewerDragLook(dx, dy, _cardH);
    _tx.value = look.tx;
    _ty.value = look.ty;
    _scale.value = look.scale;
    _dimK.value = look.dim;
    _chromeK.value = look.chrome;
  }

  void _releaseDrag(double dy, double vy) {
    const zoom = CameoMotion.viewerZoomSpring;
    _springTo(_tx, 0, zoom);
    _springTo(_ty, 0, zoom);
    _springTo(_scale, 1, zoom);
    if (viewerShouldDismiss(dy, vy, _cardH)) {
      _close();
    } else {
      _springTo(_dimK, 1, zoom);
      _springTo(_chromeK, 0, zoom);
    }
  }

  void _hStart(DragStartDetails d) {
    _axis = 1;
    _downAt = d.globalPosition;
    _drag = Offset.zero;
    _pos.stop();
  }

  void _hUpdate(DragUpdateDetails d) {
    if (_axis != 1) return;
    _drag = d.globalPosition - _downAt;
    _followPage(_drag.dx);
  }

  void _hEnd(DragEndDetails d) {
    if (_axis != 1) return;
    _axis = 0;
    _releasePage(_drag.dx, d.velocity.pixelsPerSecond.dx);
  }

  void _hCancel() {
    if (_axis != 1) return;
    _axis = 0;
    _releasePage(0, 0);
  }

  void _vStart(DragStartDetails d) {
    _axis = 2;
    _downAt = d.globalPosition;
    _drag = Offset.zero;
    _stopDrag();
  }

  void _vUpdate(DragUpdateDetails d) {
    if (_axis != 2) return;
    _drag = d.globalPosition - _downAt;
    _followDrag(_drag.dx, _drag.dy);
  }

  void _vEnd(DragEndDetails d) {
    if (_axis != 2) return;
    _axis = 0;
    _releaseDrag(_drag.dy, d.velocity.pixelsPerSecond.dy);
  }

  void _vCancel() {
    if (_axis != 2) return;
    _axis = 0;
    _releaseDrag(0, 0);
  }

  void _startDevDemo() {
    _devDemo.start([
      (
        at: PhotoViewerDevDemo.pageNext,
        run: () => _releasePage(-PhotoViewerDevDemo.pageDx * _step, 0),
      ),
      (
        at: PhotoViewerDevDemo.stripJump,
        run: () {
          final k = _index + PhotoViewerDevDemo.jump < _count
              ? _index + PhotoViewerDevDemo.jump
              : _index - PhotoViewerDevDemo.jump;
          _jumpTo(k);
        },
      ),
      (
        at: PhotoViewerDevDemo.pageBack,
        run: () => _releasePage(PhotoViewerDevDemo.pageDx * _step, 0),
      ),
      (
        at: PhotoViewerDevDemo.drag,
        run: () {
          if (!mounted) return;
          _stopDrag();
          final dy = PhotoViewerDevDemo.dragFraction * _cardH;
          final c = _demoDrag ??=
              AnimationController(
                vsync: this,
                duration: PhotoViewerDevDemo.dragDuration,
              )..addListener(() {
                final t = Curves.easeInOutQuad.transform(_demoDrag!.value);
                _followDrag(0, t * dy);
              });
          c.forward(from: 0);
        },
      ),
      (
        at:
            PhotoViewerDevDemo.drag +
            PhotoViewerDevDemo.dragDuration +
            PhotoViewerDevDemo.dragHold,
        run: () {
          if (mounted) {
            _releaseDrag(PhotoViewerDevDemo.dragFraction * _cardH, 0);
          }
        },
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final album = _maybeWatchAlbum(context);
    final width = _width;
    final height = _height;
    final layout = V6Layout.of(context);
    final cardRect = viewerCardRectV6(width);
    final step = viewerPageStep(width);
    final travel = viewerChromeTravel(width, height);
    final stripTop = viewerStripTop(width);

    final List<_ViewerPage> pages;
    final int index;
    AlbumPhoto? photo;
    final subject = widget.subject;
    if (_sectionId != null) {
      final photos =
          album?.sectionOf(_sectionId!)?.photos ?? const <AlbumPhoto>[];
      final id = _photoId;
      final liveIndex = id == null ? -1 : photos.indexWhere((p) => p.id == id);
      if (liveIndex >= 0) {
        _knownPhoto = photos[liveIndex];
        _knownIndex = liveIndex;
      }
      photo = _knownPhoto;
      index = _knownIndex;
      _photos = photos;
      if (photo == null) {
        pages = [(key: 'content', image: AssetImage(labV6.viewer.image))];
        _count = 1;
      } else if (liveIndex < 0) {
        pages = [(key: photo.id, image: photo.provider)];
        _count = 1;
      } else {
        pages = [for (final p in photos) (key: p.id, image: p.provider)];
        _count = photos.length;
      }
    } else {
      _photos = const [];
      index = 0;
      _count = 1;
      pages = [
        (
          key: 'subject',
          image: subject?.image ?? AssetImage(labV6.viewer.image),
        ),
      ];
    }
    _index = index;
    final single = pages.length == 1;
    final liked = _sectionId != null ? (photo?.liked ?? false) : _localLiked;
    final canAct = _sectionId != null ? photo != null : subject != null;

    Widget card(int k, ImageProvider image) {
      final img = Image(
        image: image,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        excludeFromSemantics: true,
      );
      if (k == (single ? 0 : index)) {
        return ViewerZoomCard(
          key: PhotoViewerScreen.cardKey,
          card: cardRect,
          radius: CameoLayout.viewerV6CardRadius,
          child: img,
        );
      }
      return Positioned.fromRect(
        rect: cardRect,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(CameoLayout.viewerV6CardRadius),
          child: img,
        ),
      );
    }

    final window = single ? const [0] : viewerPageWindow(index, pages.length);
    final copy = appContent.v6.album;
    final pillItems = <ScrimPillItem>[
      for (final key in labV6.viewer.actions)
        if (key == 'share-2')
          ScrimPillItem(
            icon: toastIconOf(key),
            semanticLabel: copy.shareLabel,
            onPress: canAct ? () => unawaited(_share()) : null,
          )
        else if (key == 'heart')
          ScrimPillItem(
            icon: toastIconOf(key),
            active: liked,
            semanticLabel: liked ? copy.unlikeLabel : copy.likeLabel,
            onPress: canAct ? () => _like() : null,
          )
        else if (_sectionId != null)
          ScrimPillItem(
            icon: toastIconOf(key),
            semanticLabel: copy.deleteLabel,
            onPress: canAct ? _requestDelete : null,
          ),
    ];

    return GlassBackdrop(
      tone: GlassBackdropTone.fromToken(
        CameoEffects.liquidGlassBackdropViewerV6,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            key: PhotoViewerScreen.gestureKey,
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onHorizontalDragStart: single ? null : _hStart,
            onHorizontalDragUpdate: single ? null : _hUpdate,
            onHorizontalDragEnd: single ? null : _hEnd,
            onHorizontalDragCancel: single ? null : _hCancel,
            onVerticalDragStart: _vStart,
            onVerticalDragUpdate: _vUpdate,
            onVerticalDragEnd: _vEnd,
            onVerticalDragCancel: _vCancel,
            child: AnimatedBuilder(
              animation: Listenable.merge([_tx, _ty, _scale, _pos]),
              builder: (context, _) => Transform(
                key: PhotoViewerScreen.dragKey,
                origin: cardRect.center,
                transform: Matrix4.translationValues(_tx.value, _ty.value, 0)
                  ..scaleByDouble(_scale.value, _scale.value, 1, 1),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    for (final k in window)
                      Positioned.fill(
                        key: PhotoViewerScreen.pageKey(pages[k].key),
                        child: Transform.translate(
                          offset: Offset(
                            single ? 0 : (k - _pos.value) * step,
                            0,
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [card(k, pages[k].image)],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            key: PhotoViewerScreen.topRowKey,
            left: 0,
            right: 0,
            top: CameoLayout.topNavV6Top,
            height: CameoLayout.topNavV6ButtonSize,
            child: ViewerChromeSlide(
              edge: ViewerChromeEdge.top,
              distance: -travel.top,
              child: _ChromePush(
                push: _chromeK,
                distance: -travel.top,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      key: const ValueKey('photoViewer.slot.close'),
                      left: CameoLayout.topNavV6PaddingX,
                      top: 0,
                      child: ScrimButton(
                        key: PhotoViewerScreen.closeKey,
                        size: ScrimButtonSize.md,
                        icon: toastIconOf(labV6.viewer.closeIcon),
                        semanticLabel: copy.closeLabel,
                        onPress: _close,
                      ),
                    ),
                    Positioned(
                      key: const ValueKey('photoViewer.slot.pill'),
                      left: layout.topNavPillLeft(pillItems.length),
                      top: 0,
                      child: ScrimPill(
                        key: PhotoViewerScreen.pillKey,
                        items: pillItems,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            key: PhotoViewerScreen.stripKey,
            left: 0,
            right: 0,
            top: stripTop,
            height: CameoLayout.viewerV6StripCellSize,
            child: ViewerChromeSlide(
              edge: ViewerChromeEdge.bottom,
              distance: travel.strip,
              child: _ChromePush(
                push: _chromeK,
                distance: travel.strip,
                child: ThumbStrip(
                  images: [for (final p in pages) p.image],
                  position: single ? kAlwaysDismissedAnimation : _strip,
                  onTap: single ? null : _jumpTo,
                ),
              ),
            ),
          ),

          Positioned(
            key: PhotoViewerScreen.datePillKey,
            left: 0,
            right: 0,
            top: viewerDatePillTop(height),
            height: CameoLayout.viewerV6DatePillHeight,
            child: ViewerChromeSlide(
              edge: ViewerChromeEdge.bottom,
              distance: travel.date,
              child: _ChromePush(
                push: _chromeK,
                distance: travel.date,
                child: Center(child: _DatePill(label: labV6.viewer.date)),
              ),
            ),
          ),
          if (_sheetMounted)
            Positioned.fill(
              key: PhotoViewerScreen.deleteSheetKey,
              child: ConfirmSheet(
                visible: _sheetOpen,
                title: fillTemplate(copy.deleteSheet.title, {'count': 1}),
                body: AlbumScope.read(context).usesBackend ? appContent.v6.backend.permanentDelete : copy.deleteSheet.body,
                confirmLabel: copy.deleteSheet.confirm,
                cancelLabel: copy.deleteSheet.cancel,
                destructive: true,
                onConfirm: _confirmDelete,
                onCancel: () => setState(() => _sheetOpen = false),
              ),
            ),
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final radius = BorderRadius.circular(
      CameoLayout.viewerV6DatePillHeight / 2,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.staticWhiteBase,
        borderRadius: radius,
        boxShadow: const [CameoShadows.scrim],
      ),

      position: DecorationPosition.background,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: c.borderScrim,
            width: CameoLayout.scrimButtonV6BorderWidth,
          ),
        ),
        child: SizedBox(
          height: CameoLayout.viewerV6DatePillHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal:
                  CameoLayout.viewerV6DatePillPadding +
                  CameoLayout.scrimButtonV6LabelPaddingX,
            ),
            child: Center(
              widthFactor: 1,
              child: CameoText(
                label,
                key: PhotoViewerScreen.dateKey,
                style: CameoTextStyles.bodyMd,
                color: c.staticBlackBase,
                maxLines: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChromePush extends StatelessWidget {
  const _ChromePush({
    required this.push,
    required this.distance,
    required this.child,
  });

  final Animation<double> push;
  final double distance;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: push,
    child: child,
    builder: (context, child) => Transform.translate(
      offset: Offset(0, push.value * distance),
      child: child,
    ),
  );
}

AlbumStore? _maybeWatchAlbum(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<AlbumScope>()?.notifier;
