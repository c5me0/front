// Album timeline with imports, favorites, soft deletion, selection, and photo viewing.
// Report tab-bar tone and browsing mode from the current viewport.

import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../components/album_hero.dart' show ScrollOffsetListenable;
import '../../components/album_nav_v6.dart';
import '../../components/album_section_v6.dart';
import '../../components/confirm_sheet.dart';
import '../../components/empty_album_v6.dart';
import '../../components/backend_notice.dart';
import '../../components/solid_button.dart';
import '../../api/api_error_text.dart';
import '../../components/photo_grid_v6.dart';
import '../../content/app.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/navigation.dart';
import '../../state/album_import.dart';
import '../../state/album_store.dart';
import '../../state/device_services.dart';
import '../../state/session.dart';
import '../photo_viewer/viewer_presence.dart';
import 'album_timeline_model.dart';
import 'cell_locator.dart';

abstract final class HomeTimelineDemo {
  static const Duration hopDwell = Duration(milliseconds: 1400);

  static const Duration toggleInterval = Duration(milliseconds: 350);

  static const int toggleCount = 3;

  static const int openPhotoIndex = 1;
}

abstract final class HomeTimelineDevDemo {
  static const Duration like = Duration(milliseconds: 1500);
  static const int likeIndex = 3;
  static const Duration liked = Duration(milliseconds: 3200);
  static const Duration likedClose = Duration(milliseconds: 5200);
  static const Duration select = Duration(milliseconds: 6600);
  static const Duration toggle = Duration(milliseconds: 7400);
  static const Duration trash = Duration(milliseconds: 9000);
  static const Duration confirm = Duration(milliseconds: 10600);
  static const Duration selectClose = Duration(milliseconds: 12400);
  static const Duration deleted = Duration(milliseconds: 13800);
  static const Duration restoreToggle = Duration(milliseconds: 15400);
  static const Duration restore = Duration(milliseconds: 16400);
  static const Duration deletedClose = Duration(milliseconds: 18200);
}

typedef _AlbumData = ({
  List<AlbumSection> sections,
  List<AlbumSection> liked,
  List<AlbumSection> deleted,
  bool empty,
  bool hasPartner,
});

AlbumMode albumModeOfView(AlbumView view) => switch (view) {
  AlbumView.timeline => AlbumMode.timeline,
  AlbumView.select => AlbumMode.select,
  AlbumView.liked => AlbumMode.liked,
  AlbumView.deleted => AlbumMode.deleted,
};

class HomeTimelineScreen extends StatefulWidget {
  const HomeTimelineScreen({super.key, this.initialView = AlbumView.timeline});

  final AlbumView initialView;

  static const Key scrollKey = ValueKey('homeTimeline.scroll');
  static const Key emptyKey = ValueKey('homeTimeline.empty');
  static const Key selectKey = AlbumNavV6.selectKey;
  static const Key navPillKey = AlbumNavV6.mainPillKey;
  static const Key selectCloseKey = AlbumNavV6.closeKey;
  static const Key selectPillKey = AlbumNavV6.selectionPillKey;
  static const Key restorePillKey = AlbumNavV6.restorePillKey;
  static const Key navKey = ValueKey('homeTimeline.nav');
  static const Key deleteSheetKey = ValueKey('homeTimeline.deleteSheet');
  static const Key overscrollTopKey = ValueKey('homeTimeline.overscroll.top');
  static const Key overscrollBottomKey = ValueKey(
    'homeTimeline.overscroll.bottom',
  );
  static const Key canvasKey = ValueKey('homeTimeline.canvas');
  static Key sectionKey(String id) => ValueKey('homeTimeline.section.$id');
  static Key cellKey(String photoId) => PhotoGridV6.cellKey(photoId);
  static Key callKey(String sectionId, int index) =>
      AlbumSectionV6.cardKey(sectionId, index);

  @override
  State<HomeTimelineScreen> createState() => HomeTimelineScreenState();
}

class HomeTimelineScreenState extends State<HomeTimelineScreen>
    with TickerProviderStateMixin {
  static bool _launchParamsUsed = false;

  @visibleForTesting
  static void resetLaunchParamsForTesting() => _launchParamsUsed = false;

  final ScrollController _scroll = ScrollController();
  late final ScrollOffsetListenable _scrollY = ScrollOffsetListenable(_scroll);

  late final AnimationController _scrollDrive;
  bool _driving = false;

  late AlbumMode _mode = albumModeOfView(widget.initialView);
  late final AnimationController _modeProgress;
  Set<String> _selected = const {};

  final GlobalKey _probeKey = GlobalKey(debugLabel: 'homeTimeline.content');
  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<String, GlobalKey<PhotoGridV6State>> _gridKeys = {};
  final Map<String, ValueNotifier<double>> _tops = {};
  List<ToneBand> _bands = const [];
  double _contentHeight = 0;
  bool _measurePending = false;

  late final AnimationController _navTone;
  late final AnimationController _tabTone;
  int? _toneCode;
  AlbumTone _navToneShown = AlbumTone.photo;
  AlbumTone _tabToneShown = AlbumTone.photo;

  bool _sectionsShown = false;

  TabBarV6Mode? _reportedMode;
  bool _reportedExpandable = false;
  final TabBarScrollState _barScroll = TabBarScrollState();
  TabBarV6Tone? _reportedTone;

  _AlbumData? _data;
  bool _wasEmpty = false;

  final OverlayPortalController _sheetPortal = OverlayPortalController();
  final ConfirmSheetController _sheet = ConfirmSheetController();
  bool _sheetOpen = false;
  int _sheetCount = 0;

  final List<VoidCallback> _unregister = [];
  final List<Timer> _timers = [];
  final DemoTimeline _devDemo = DemoTimeline();
  bool _reduceMotion = false;

  AlbumMode get mode => _mode;
  bool get selecting => isSelectionMode(_mode);
  Set<String> get selected => Set.unmodifiable(_prunedSelected());
  @visibleForTesting
  double get modeProgress => _modeProgress.value;
  @visibleForTesting
  double get selectProgress => _modeProgress.value;
  @visibleForTesting
  GlassBackdropTone get navBackdrop => toneBackdropOf(_navToneShown);
  @visibleForTesting
  AlbumTone get navTone => _navToneShown;
  @visibleForTesting
  AlbumTone get tabTone => _tabToneShown;
  @visibleForTesting
  double get navToneProgress => _navTone.value;
  @visibleForTesting
  List<ToneBand> get toneBands => _bands;
  @visibleForTesting
  double sectionTopOf(String id) => _tops[id]?.value ?? -1;

  @visibleForTesting
  List<AlbumSection> get drawnSections => _drawn(_data);

  bool get _isTop => mounted && CameoNav.isTop(context);

  double get _viewportH => MediaQuery.sizeOf(context).height;

  @override
  void initState() {
    super.initState();

    _scrollDrive = AnimationController.unbounded(vsync: this)
      ..addListener(_onScrollDrive);
    _modeProgress = AnimationController.unbounded(
      vsync: this,
      value: albumModeProgressTarget(_mode),
    );
    _navTone = AnimationController.unbounded(vsync: this)
      ..addListener(_onNavTone);
    _tabTone = AnimationController.unbounded(vsync: this)
      ..addListener(_onTabTone);
    _scroll.addListener(_onScroll);
    ViewerPresence.listenable.addListener(_onPresence);
    _unregister
      ..add(
        registerCellLocator((photoId) {
          for (final key in _gridKeys.values) {
            final rect = key.currentState?.locate(photoId);
            if (rect != null) return rect;
          }
          return null;
        }),
      )
      ..add(_register(FlowDemoAction.homeScroll, _demoScroll))
      ..add(_register(FlowDemoAction.homeOpenPhoto, _demoOpenPhoto))
      ..add(
        _register(
          FlowDemoAction.homeLiked,
          () => _demoMode(AlbumModeEvent.liked, FlowDemoAction.homeLiked),
        ),
      )
      ..add(
        _register(
          FlowDemoAction.likedClose,
          () => _demoClose(AlbumMode.liked, FlowDemoAction.likedClose),
        ),
      )
      ..add(
        _register(
          FlowDemoAction.homeDeleted,
          () => _demoMode(AlbumModeEvent.deleted, FlowDemoAction.homeDeleted),
        ),
      )
      ..add(
        _register(
          FlowDemoAction.deletedClose,
          () => _demoClose(AlbumMode.deleted, FlowDemoAction.deletedClose),
        ),
      )
      ..add(
        _register(
          FlowDemoAction.homeSelect,
          () => _demoMode(AlbumModeEvent.select, FlowDemoAction.homeSelect),
        ),
      )
      ..add(_register(FlowDemoAction.selectToggle, _demoToggle))
      ..add(
        _register(
          FlowDemoAction.selectClose,
          () => _demoClose(AlbumMode.select, FlowDemoAction.selectClose),
        ),
      )
      ..add(_register(FlowDemoAction.homeOpenCallCard, _demoOpenCallCard));
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyLaunchParams());
  }

  VoidCallback _register(FlowDemoAction action, FlowDemoHandler handler) =>
      FlowDemo.register(action, handler, isReady: () => _isTop);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void dispose() {
    for (final unregister in _unregister) {
      unregister();
    }
    for (final t in _timers) {
      t.cancel();
    }
    _devDemo.cancel();
    ViewerPresence.listenable.removeListener(_onPresence);
    _scroll.removeListener(_onScroll);
    _scrollDrive.dispose();
    _modeProgress.dispose();
    _navTone.dispose();
    _tabTone.dispose();
    _scroll.dispose();
    for (final n in _tops.values) {
      n.dispose();
    }
    super.dispose();
  }

  GlobalKey _sectionKey(String id) =>
      _sectionKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'section.$id'));

  GlobalKey<PhotoGridV6State> _gridKey(String id) => _gridKeys.putIfAbsent(
    id,
    () => GlobalKey<PhotoGridV6State>(debugLabel: 'grid.$id'),
  );

  ValueNotifier<double> _top(String id) =>
      _tops.putIfAbsent(id, () => ValueNotifier<double>(-1));

  void _later(Duration d, VoidCallback fn) => _timers.add(
    Timer(d, () {
      if (mounted) fn();
    }),
  );

  void _settle(FlowDemoAction action) {
    FlowDemo.settle(action);
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _onPresence() {
    if (mounted) setState(() {});
  }

  List<AlbumSection> _drawn(_AlbumData? data) {
    if (data == null) return const [];
    if (_mode == AlbumMode.timeline && data.empty) return const [];
    return albumSectionsForMode(
      sections: data.empty ? const [] : data.sections,
      liked: data.liked,
      deleted: data.deleted,
      mode: _mode,
    );
  }

  bool get _showEmpty {
    final data = _data;
    return data != null &&
        data.empty &&
        (_mode == AlbumMode.timeline || _mode == AlbumMode.select);
  }

  void _scheduleMeasure() {
    if (_measurePending) return;
    _measurePending = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _measurePending = false;
      if (mounted) _measure();
    });
  }

  void _measure() {
    final probe = _probeKey.currentContext?.findRenderObject();
    final sections = _drawn(_data);
    if (probe is! RenderBox || !probe.attached) {
      _bands = const [];
      _updateTone();
      return;
    }
    final width = MediaQuery.sizeOf(context).width;
    final bands = <ToneBand>[];
    for (final s in sections) {
      final box = _sectionKeys[s.id]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero, ancestor: probe).dy;
      _top(s.id).value = top;
      bands.add(
        ToneBand.of(top, box.size.height, AlbumSectionV6.planOf(s, width).tone),
      );
    }
    _bands = bands;
    _contentHeight = probe.size.height;
    _updateTone();
  }

  void _onScroll() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      _scheduleMeasure();
      return;
    }
    _updateTone();
  }

  void _updateTone() {
    if (!mounted) return;
    int nav;
    int tab;
    if (_showEmpty) {
      nav = 1;
      tab = 1;
    } else {
      if (_bands.isEmpty) return;
      final y = _scrollY.value;
      int toneAt(double sample) =>
          toneAtY(_bands, y + sample) == AlbumTone.light ? 1 : 0;
      nav = toneAt(navToneSampleY);
      tab = toneAt(tabBarToneSampleY(_viewportH));
    }
    final code = nav + 2 * tab;
    final previous = _toneCode;
    if (code == previous) return;
    _toneCode = code;
    final prevNav = previous == null ? -1 : previous % 2;
    final prevTab = previous == null ? -1 : previous ~/ 2;
    void drive(AnimationController c, int target) {
      if (previous == null || _reduceMotion) {
        c.value = target.toDouble();
      } else {
        c.animateWith(
          cameoSpringSimulation(
            CameoMotion.albumToneSpring,
            from: c.value,
            to: target.toDouble(),
            velocity: c.velocity,
          ),
        );
      }
    }

    if (nav != prevNav) drive(_navTone, nav);
    if (tab != prevTab) drive(_tabTone, tab);
  }

  void _onNavTone() {
    final t = toneOfProgress(_navTone.value);
    if (t != _navToneShown && mounted) setState(() => _navToneShown = t);
  }

  void _onTabTone() {
    final t = toneOfProgress(_tabTone.value);
    if (t != _tabToneShown && mounted) setState(() => _tabToneShown = t);
  }

  void _dispatch(AlbumModeEvent event) {
    if (!mounted) return;
    final next = albumModeAfter(_mode, event);
    if (next == _mode) return;
    if (next == AlbumMode.liked && AlbumScope.read(context).usesBackend) {
      unawaited(AlbumScope.read(context).remote.refreshFavorites());
    }
    _restoreBarScrollPosition();
    final enteringView = next == AlbumMode.liked || next == AlbumMode.deleted;
    setState(() {
      _mode = next;
      _selected = const {};
    });
    final target = albumModeProgressTarget(next);
    if (_reduceMotion) {
      _modeProgress.value = target;
    } else {
      _modeProgress.animateWith(
        cameoSpringSimulation(
          CameoMotion.selectModeSpring,
          from: _modeProgress.value,
          to: target,
          velocity: _modeProgress.velocity,
        ),
      );
    }

    if (enteringView) _springScrollTo(0, CameoMotion.selectModeSpring);
    _scheduleMeasure();
  }

  Set<String> _prunedSelected() {
    final sections = _drawn(_data);
    return prunedSelection(_selected, {
      for (final s in sections)
        for (final p in s.photos) p.id,
    });
  }

  List<String> _selectedInOrder() {
    final selected = _prunedSelected();
    return [
      for (final s in _drawn(_data))
        for (final p in s.photos)
          if (selected.contains(p.id)) p.id,
    ];
  }

  void _toggle(String id) {
    if (!mounted || !selecting) return;
    setState(() => _selected = toggledSelection(_prunedSelected(), id));
  }

  void _clearSelection() => setState(() => _selected = const {});

  bool _openPhoto(String sectionId, String photoId) {
    if (_mode != AlbumMode.timeline || !_isTop) return false;
    final data = _data;
    if (data == null) return false;
    AlbumSection? section;
    for (final s in data.sections) {
      if (s.id == sectionId) section = s;
    }
    final index = section?.photos.indexWhere((p) => p.id == photoId) ?? -1;
    final rect = _gridKeys[sectionId]?.currentState?.locate(photoId);
    if (section == null || index < 0 || rect == null) return false;
    _restoreBarScrollPosition();
    _reportTabBarMode();
    CameoNav.openPhotoViewer(context, sectionId, index, rect);
    return true;
  }

  void _onToggleLike(String photoId) {
    _restoreBarScrollPosition();
    _reportTabBarMode();
    AlbumScope.read(context).toggleLike(photoId);
  }

  bool _openCallCard(String sectionId, int index) {
    if ((_mode != AlbumMode.timeline && _mode != AlbumMode.liked) || !_isTop) {
      return false;
    }
    final album = AlbumScope.read(context);
    if (album.usesBackend) {
      final sections = _mode == AlbumMode.liked
          ? album.likedSections
          : album.sections;
      final calls = sections.where((s) => s.id == sectionId).firstOrNull?.calls;
      if (calls == null || index >= calls.length) return false;
      CameoNav.push<void>(
        context,
        '${CameoRoutes.transcriptPath}?id=${Uri.encodeQueryComponent(calls[index].nodeId)}',
      );
      return true;
    }
    CameoNav.push<void>(context, CameoRoutes.transcript());
    return true;
  }

  void _import() {
    if (!_isTop) return;
    if (SessionScope.read(context).premiumRequired) {
      unawaited(CameoNav.openPayment(context));
      return;
    }
    unawaited(importPhotosFrom(context));
  }

  Future<void> _shareSelected() async {
    final album = AlbumScope.read(context);
    final service = ShareService.of(context);
    final ids = _selectedInOrder();
    final images = [
      for (final id in ids)
        if (album.anyPhotoById(id) case final photo?) photo.image,
    ];
    if (images.isEmpty) return;
    final outcome = await service.shareImages(images);
    if (outcome == ShareOutcome.shared) album.markShared(ids);
  }

  void _heart() {
    final album = AlbumScope.read(context);
    final ids = _selectedInOrder();
    if (ids.isEmpty) return;
    if (_mode == AlbumMode.liked) {
      album.setLikes(ids, false);
    } else {
      final target = selectionHeartTarget([
        for (final id in ids) album.anyPhotoById(id)?.liked ?? false,
      ]);
      if (target == null) return;
      album.setLikes(ids, target);
    }
    _clearSelection();
  }

  void _restore() {
    final ids = _selectedInOrder();
    if (ids.isEmpty) return;
    AlbumScope.read(context).restorePhotos(ids);
    _clearSelection();
  }

  void _requestDelete() {
    final ids = _selectedInOrder();
    if (ids.isEmpty) return;
    setState(() {
      _sheetCount = ids.length;
      _sheetOpen = true;
    });
    _sheetPortal.show();
  }

  Future<void> _confirmDelete() async {
    final ok = await AlbumScope.read(context).removePhotos(_selectedInOrder());
    if (!mounted) return;
    setState(() {
      if (ok) _selected = const {};
      _sheetOpen = false;
    });
  }

  void _cancelDelete() => setState(() => _sheetOpen = false);

  late final AlbumNavV6Actions _actions = AlbumNavV6Actions(
    onSelect: () => _dispatch(AlbumModeEvent.select),
    onImport: _import,
    onLiked: () => _dispatch(AlbumModeEvent.liked),
    onDeleted: () => _dispatch(AlbumModeEvent.deleted),
    onClose: () => _dispatch(AlbumModeEvent.close),
    onShare: () => unawaited(_shareSelected()),
    onHeart: _heart,
    onDelete: _requestDelete,
    onRestore: _restore,
  );

  void _onScrollDrive() {
    if (!_driving || !_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    _scroll.jumpTo(_scrollDrive.value.clamp(0.0, max));
  }

  bool _onScrollNotification(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    if (n is ScrollStartNotification) {
      if (n.dragDetails != null && _driving) {
        _driving = false;
        _scrollDrive.stop();
      }
      _barScroll.begin(
        n.metrics.pixels,
        n.metrics.minScrollExtent,
        n.metrics.maxScrollExtent,
      );
    } else if (n is ScrollUpdateNotification && _isTop) {
      if (_barScroll.update(
        n.metrics.pixels,
        n.metrics.minScrollExtent,
        n.metrics.maxScrollExtent,
      )) {
        _reportTabBarMode();
      }
    } else if (n is ScrollEndNotification && !_driving) {
      if (_barScroll.end()) _reportTabBarMode();
    }
    return false;
  }

  void _expandTabBar() {
    if (!mounted || !_barScroll.expand()) return;
    _reportTabBarMode();
  }

  void _restoreBarScrollPosition() {
    if (_scroll.hasClients) {
      final position = _scroll.position;
      _barScroll.restore(
        position.pixels,
        position.minScrollExtent,
        position.maxScrollExtent,
      );
    } else {
      _barScroll.restore(0, 0, 0);
    }
  }

  void _finishScrollDrive() {
    if (!mounted) return;
    _driving = false;
    if (_barScroll.end()) _reportTabBarMode();
  }

  void _reportTabBarMode() {
    final forced = isSelectionMode(_mode);
    final mode = forced || _barScroll.minimized
        ? TabBarV6Mode.mini
        : TabBarV6Mode.full;
    final expandable = !forced && _barScroll.minimized;
    if (mode == _reportedMode && expandable == _reportedExpandable) return;
    _reportedMode = mode;
    _reportedExpandable = expandable;
    TabBarMode.report(
      context,
      mode,
      onExpand: expandable ? _expandTabBar : null,
    );
  }

  void _springScrollTo(
    double target, [
    SpringDescription spring = CameoSprings.smooth,
  ]) {
    if (!_scroll.hasClients) return;
    final to = target.clamp(0.0, _scroll.position.maxScrollExtent);
    if ((_scroll.offset - to).abs() < 0.5) return;
    _driving = true;
    if (_reduceMotion) {
      _scroll.jumpTo(to);
      _finishScrollDrive();
      return;
    }
    _scrollDrive.value = _scroll.offset;
    _scrollDrive
        .animateWith(
          cameoSpringSimulation(spring, from: _scroll.offset, to: to),
        )
        .then((_) => _finishScrollDrive());
  }

  bool _demoScroll() {
    final data = _data;
    if (data == null ||
        _showEmpty ||
        _mode != AlbumMode.timeline ||
        !_scroll.hasClients) {
      return false;
    }
    final sections = _drawn(data);
    final tops = [for (final s in sections) _tops[s.id]?.value ?? 0.0];
    final stops = demoScrollStops(tops, _contentHeight, _viewportH);
    for (var i = 0; i < stops.length; i++) {
      final y = stops[i];
      _later(HomeTimelineDemo.hopDwell * i, () => _springScrollTo(y));
    }
    _later(HomeTimelineDemo.hopDwell * stops.length, () {
      _driving = false;
      _settle(FlowDemoAction.homeScroll);
    });
    return true;
  }

  AlbumSection? get _first {
    final sections = _drawn(_data);
    return sections.isEmpty ? null : sections.first;
  }

  bool _demoOpenPhoto() {
    final first = _first;
    if (first == null ||
        first.photos.length <= HomeTimelineDemo.openPhotoIndex) {
      return false;
    }
    return _openPhoto(
      first.id,
      first.photos[HomeTimelineDemo.openPhotoIndex].id,
    );
  }

  bool _demoMode(AlbumModeEvent event, FlowDemoAction action) {
    if (_mode != AlbumMode.timeline || _data == null) return false;
    if (event == AlbumModeEvent.select && (_showEmpty || _first == null)) {
      return false;
    }
    _dispatch(event);
    _later(
      springSettleDuration(CameoMotion.selectModeSpring),
      () => _settle(action),
    );
    return true;
  }

  bool _demoClose(AlbumMode from, FlowDemoAction action) {
    if (_mode != from) return false;
    _dispatch(AlbumModeEvent.close);
    _later(
      springSettleDuration(CameoMotion.selectModeSpring),
      () => _settle(action),
    );
    return true;
  }

  bool _demoToggle() {
    final first = _first;
    if (!selecting || first == null) return false;
    final ids = demoSelectionIds(
      first.photos,
      _mode,
      HomeTimelineDemo.toggleCount,
    );
    for (var i = 0; i < ids.length; i++) {
      final id = ids[i];
      _later(HomeTimelineDemo.toggleInterval * i, () => _toggle(id));
    }
    _later(
      HomeTimelineDemo.toggleInterval * ids.length,
      () => _settle(FlowDemoAction.selectToggle),
    );
    return true;
  }

  bool _demoOpenCallCard() {
    final first = _first;
    if (first == null || first.calls.isEmpty) return false;
    return _openCallCard(first.id, 0);
  }

  void _applyLaunchParams() {
    if (_launchParamsUsed || !mounted) return;
    _launchParamsUsed = true;

    final location = CameoLocation.of(context);
    if (location.path != CameoRoutes.home) return;
    final album = AlbumScope.read(context);
    int? count(String name) => int.tryParse(location.param(name) ?? '');
    final liked = count('liked');
    final deleted = count('deleted');
    final firstTimeline = album.sections.isEmpty ? null : album.sections.first;
    if (firstTimeline != null) {
      final photos = firstTimeline.photos;
      if (liked != null && liked > 0) {
        album.setLikes([for (final p in photos.take(liked)) p.id], true);
      }
      if (deleted != null && deleted > 0) {
        album.deletePhotos([for (final p in photos.take(deleted)) p.id]);
      }
    }
    final scroll = double.tryParse(location.param('scroll') ?? '');
    if (scroll != null && scroll > 0 && _scroll.hasClients) {
      _scroll.jumpTo(scroll.clamp(0.0, _scroll.position.maxScrollExtent));
    }
    final select = count('select');
    if (select != null && select > 0) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_mode == AlbumMode.timeline) _dispatch(AlbumModeEvent.select);
        final first = _first;
        if (first == null) return;
        setState(() {
          _selected = demoSelectionIds(first.photos, _mode, select).toSet();
        });
      });
    }
    if (CameoRoutes.demoOf(location)) _startDevDemo();
  }

  void _startDevDemo() {
    String? photo(int i) {
      final sections = _drawn(_data);
      for (final s in sections) {
        if (s.photos.length > i) return s.photos[i].id;
      }
      return null;
    }

    void toggleFirst(int n) {
      final first = _first;
      if (first == null) return;
      for (final id in demoSelectionIds(first.photos, _mode, n)) {
        _toggle(id);
      }
    }

    _devDemo.start([
      (
        at: HomeTimelineDevDemo.like,
        run: () {
          final id = photo(HomeTimelineDevDemo.likeIndex);
          if (id != null && mounted) _onToggleLike(id);
        },
      ),
      (at: HomeTimelineDevDemo.liked, run: _actions.onLiked),
      (at: HomeTimelineDevDemo.likedClose, run: _actions.onClose),
      (at: HomeTimelineDevDemo.select, run: _actions.onSelect),
      for (var k = 0; k < HomeTimelineDemo.toggleCount; k++)
        (
          at: HomeTimelineDevDemo.toggle + HomeTimelineDemo.toggleInterval * k,
          run: () {
            final first = _first;
            if (first == null) return;
            final ids = demoSelectionIds(
              first.photos,
              _mode,
              HomeTimelineDemo.toggleCount,
            );
            if (k < ids.length) _toggle(ids[k]);
          },
        ),
      (at: HomeTimelineDevDemo.trash, run: _actions.onDelete),
      (at: HomeTimelineDevDemo.confirm, run: () => _sheet.confirm()),
      (at: HomeTimelineDevDemo.selectClose, run: _actions.onClose),
      (at: HomeTimelineDevDemo.deleted, run: _actions.onDeleted),
      (at: HomeTimelineDevDemo.restoreToggle, run: () => toggleFirst(1)),
      (at: HomeTimelineDevDemo.restore, run: _actions.onRestore),
      (at: HomeTimelineDevDemo.deletedClose, run: _actions.onClose),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final album = AlbumScope.of(context);
    final controller = SessionScope.of(context);
    final session = controller.session;
    final recoveryCouple = controller.remoteCouple;
    final recoveryId = recoveryCouple != null && recoveryCouple.canRestore
        ? recoveryCouple.id
        : null;
    final hasPartner = session.partner != null;
    final liveEmpty = album.isEmptyFor(hasPartner: hasPartner);
    final _AlbumData live = (
      sections: liveEmpty ? const <AlbumSection>[] : album.sections,
      liked: album.likedSections,
      deleted: album.deletedSections,
      empty: liveEmpty,
      hasPartner: hasPartner,
    );

    if (!ViewerPresence.isOpen || _data == null) _data = live;
    final data = _data!;

    if (data.empty && !_wasEmpty && _mode != AlbumMode.timeline) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _dispatch(AlbumModeEvent.empty);
      });
    }
    _wasEmpty = data.empty;
    final showEmpty = _showEmpty;
    if (showEmpty) {
      _barScroll.restore(0, 0, 0);

      SchedulerBinding.instance.addPostFrameCallback((_) => _updateTone());
    }

    _reportTabBarMode();
    final barTone = _tabToneShown == AlbumTone.light
        ? TabBarV6Tone.canvas
        : TabBarV6Tone.photo;
    if (barTone != _reportedTone) {
      _reportedTone = barTone;
      TabBarTone.report(context, barTone);
    }
    final c = CameoTheme.colorsOf(context);

    return OverlayPortal.targetsRootOverlay(
      controller: _sheetPortal,
      overlayChildBuilder: _buildSheet,
      child: CameoStatusBar(
        style: toneStatusGlyphsLight(_navToneShown)
            ? CameoStatusBarStyle.lightContent
            : CameoStatusBarStyle.darkContent,
        child: GlassBackdrop(
          tone: GlassBackdropTone.fromToken(
            CameoEffects.liquidGlassBackdropAlbumV6,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (showEmpty)
                KeyedSubtree(
                  key: HomeTimelineScreen.emptyKey,
                  child: ColoredBox(
                    key: HomeTimelineScreen.canvasKey,
                    color: c.backgroundCanvasNeutralBase,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        EmptyAlbumV6(
                          hasPartner: data.hasPartner,
                          meName: session.name,
                          title: controller.premiumRequired && hasPartner
                              ? appContent.v6.backend.premiumTitle
                              : null,
                          actionLabel: controller.premiumRequired && hasPartner
                              ? appContent.v6.backend.premiumAction
                              : null,
                          onImport: _import,
                          onConnect: () => CameoNav.openConnect(context),
                        ),
                      ],
                    ),
                  ),
                )
              else
                KeyedSubtree(
                  key: const ValueKey('homeTimeline.timelineLayer'),
                  child: _timeline(context, _drawn(data)),
                ),
              KeyedSubtree(
                key: HomeTimelineScreen.navKey,
                child: AlbumNavV6(
                  mode: _mode,
                  progress: _modeProgress,
                  toneProgress: _navTone,
                  backdrop: toneBackdropOf(_navToneShown),
                  actions: _actions,
                  selectDisabled: showEmpty,
                  showDeleted: !album.usesBackend,
                  onRefresh: album.usesBackend
                      ? () => unawaited(album.remote.refresh(renewUrls: true))
                      : null,
                ),
              ),
              if (recoveryId != null ||
                  (controller.premiumRequired && hasPartner && !showEmpty))
                Positioned(
                  key: const ValueKey('album.membershipNotice'),
                  top: CameoLayout.albumNavV6HeaderHeight,
                  left: 0,
                  right: 0,
                  child: BackendNotice(
                    message: recoveryId != null
                        ? appContent.v6.backend.recoveryAvailable
                        : appContent.v6.backend.premiumRequired,
                    onRetry: () =>
                        CameoNav.openPayment(context, archiveId: recoveryId),
                  ),
                )
              else if (album.usesBackend &&
                  (album.remote.error != null ||
                      album.remote.uploading ||
                      (album.remote.loading && album.isEmpty)))
                Positioned(
                  key: const ValueKey('album.backendNotice'),
                  top: CameoLayout.albumNavV6HeaderHeight,
                  left: 0,
                  right: 0,
                  child: BackendNotice(
                    message: album.remote.error != null
                        ? '${apiErrorCodeText(album.remote.error!)} ${appContent.v6.backend.retry}'
                        : album.remote.uploading
                        ? appContent.v6.backend.uploading
                        : appContent.v6.backend.loading,
                    onRetry: album.remote.error != null
                        ? () => unawaited(album.remote.refresh())
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeline(BuildContext context, List<AlbumSection> sections) {
    if (!_sectionsShown && sections.isNotEmpty) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => _sectionsShown = true,
      );
    }
    final c = CameoTheme.colorsOf(context);
    final selected = _prunedSelected();
    final viewportH = _viewportH;
    final width = MediaQuery.sizeOf(context).width;
    Color tintOf(AlbumSection s) =>
        c.byRole[AlbumSectionV6.planOf(s, width).tint] ??
        c.backgroundCanvasNeutralBase;
    final firstTint = sections.isEmpty ? c.sectionTint : tintOf(sections.first);
    final lastTint = sections.isEmpty ? c.sectionTint : tintOf(sections.last);
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ColoredBox(
                  key: HomeTimelineScreen.overscrollTopKey,
                  color: firstTint,
                ),
              ),
              Expanded(
                child: ColoredBox(
                  key: HomeTimelineScreen.overscrollBottomKey,
                  color: lastTint,
                ),
              ),
            ],
          ),
        ),
        NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: SingleChildScrollView(
            key: HomeTimelineScreen.scrollKey,
            controller: _scroll,
            child: _LayoutProbe(
              key: _probeKey,
              onLayout: _scheduleMeasure,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < sections.length; i++)
                    _SectionJoin(
                      key: HomeTimelineScreen.sectionKey(sections[i].id),

                      fade: _sectionsShown && !_reduceMotion,
                      child: AlbumSectionV6(
                        key: _sectionKey(sections[i].id),
                        section: sections[i],
                        index: i,
                        isLast: i == sections.length - 1,
                        prevTint: i > 0
                            ? AlbumSectionV6.planOf(sections[i - 1], width).tint
                            : null,
                        scrollY: _scrollY,
                        sectionTop: _top(sections[i].id),
                        viewportH: viewportH,
                        mode: _mode,
                        modeProgress: _modeProgress,
                        selected: selected,
                        reduceMotion: _reduceMotion,
                        onToggleLike: _onToggleLike,
                        onOpenPhoto: (sectionId, photoId) =>
                            _openPhoto(sectionId, photoId),
                        onToggleSelect: _toggle,
                        onOpenCall: (sectionId, index) =>
                            _openCallCard(sectionId, index),
                        gridKey: _gridKey(sections[i].id),
                      ),
                    ),
                  if (AlbumScope.read(context).usesBackend &&
                      (_mode == AlbumMode.liked
                          ? AlbumScope.read(context).remote.favoritesHaveMore
                          : AlbumScope.read(context).remote.hasMore))
                    Padding(
                      padding: const EdgeInsets.only(
                        left: CameoLayout.albumNavV6RowPaddingX,
                        right: CameoLayout.albumNavV6RowPaddingX,
                        bottom: CameoLayout.tabBarV6FullContainerHeight,
                      ),
                      child: SolidButton(
                        key: const ValueKey('album.loadMore'),
                        label: appContent.v6.backend.loadMore,
                        onPress: () => unawaited(
                          _mode == AlbumMode.liked
                              ? AlbumScope.read(
                                  context,
                                ).remote.refreshFavorites(more: true)
                              : AlbumScope.read(context).remote.loadMore(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSheet(BuildContext context) {
    final copy = appContent.v6.album.deleteSheet;
    return KeyedSubtree(
      key: HomeTimelineScreen.deleteSheetKey,
      child: ConfirmSheet(
        visible: _sheetOpen,
        title: fillTemplate(copy.title, {'count': _sheetCount}),
        body: AlbumScope.read(context).usesBackend
            ? appContent.v6.backend.permanentDelete
            : copy.body,
        confirmLabel: copy.confirm,
        cancelLabel: copy.cancel,
        destructive: true,
        controller: _sheet,
        onConfirm: _confirmDelete,
        onCancel: _cancelDelete,
      ),
    );
  }
}

class _SectionJoin extends StatefulWidget {
  const _SectionJoin({super.key, required this.fade, required this.child});

  final bool fade;
  final Widget child;

  @override
  State<_SectionJoin> createState() => _SectionJoinState();
}

class _SectionJoinState extends State<_SectionJoin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _p = AnimationController.unbounded(
    vsync: this,
    value: widget.fade ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.fade) {
      _p.animateWith(
        cameoSpringSimulation(CameoMotion.selectModeSpring, from: 0, to: 1),
      );
    }
  }

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _p,
    child: widget.child,
    builder: (context, child) =>
        Opacity(opacity: _p.value.clamp(0.0, 1.0), child: child),
  );
}

class _LayoutProbe extends SingleChildRenderObjectWidget {
  const _LayoutProbe({super.key, required this.onLayout, super.child});

  final VoidCallback onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLayoutProbe(onLayout);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLayoutProbe renderObject,
  ) => renderObject.onLayout = onLayout;
}

class _RenderLayoutProbe extends RenderProxyBox {
  _RenderLayoutProbe(this.onLayout);

  VoidCallback onLayout;

  @override
  void performLayout() {
    super.performLayout();
    onLayout();
  }
}
