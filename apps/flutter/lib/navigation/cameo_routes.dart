// Route registry with presentation, status-bar style, session guard, and screen
// builder. Unknown paths fall back to the home route.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import '../preview/foundation_preview.dart';
import '../screens/album/album_screen.dart';
import '../screens/album_gangneung/album_gangneung_screen.dart';
import '../screens/call/call_screen.dart';
import '../screens/call_v1/call_v1_screen.dart';
import '../screens/camera/camera_screen.dart';
import '../screens/camera_v6/camera_v6_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/home_timeline/home_timeline_screen.dart';
import '../screens/instant_viewer/instant_viewer_screen.dart';
import '../screens/lab/glass_v6_harness.dart';
import '../screens/lab/lab_screen.dart';
import '../screens/partner/partner_screen.dart';
import '../screens/payment/payment_screen.dart';
import '../screens/permissions/permissions_screen.dart';
import '../screens/phone/phone_screen.dart';
import '../screens/photo_viewer/photo_viewer_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/breakup_screen.dart';
import '../screens/transcript/transcript_route.dart';
import '../screens/verify/verify_screen.dart';
import '../screens/welcome/welcome_screen.dart';
import '../state/session.dart';
import 'app_tabs.dart';
import 'cameo_location.dart';
import 'cameo_modal_route.dart';
import 'cameo_page_route.dart';
import 'cameo_shell_route.dart';
import 'cameo_viewer_route.dart';
import 'cameo_zoom_route.dart';
import 'route_params.dart';
import 'status_bar.dart';
import 'zoom_source.dart';

enum CameoPresentation { push, modal, tab, viewer }

typedef CameoScreenBuilder =
    Widget Function(BuildContext context, CameoLocation location);

@immutable
class CameoRouteSpec {
  const CameoRouteSpec({
    required this.path,
    required this.presentation,
    required this.statusBar,
    required this.builder,
    this.guard,
    this.tab,
    this.nested = false,
  });

  final String path;
  final CameoPresentation presentation;
  final CameoStatusBarStyle Function(CameoLocation location) statusBar;
  final CameoScreenBuilder builder;

  final SessionStatus? guard;

  final int? tab;

  final bool nested;
}

///

/// |---|---|---|---|

///

/// `/call` `state=base|media-16x9|media-4x3|media-1x1|sleep-toast` · `sheet=instant|multi` · `demo=1` / `/camera-v3` `demo=1` /

///

abstract final class CameoRoutes {
  static const String welcome = '/welcome';
  static const String phone = '/phone';
  static const String verifyPath = '/verify';
  static const String profile = '/profile';
  static const String partner = '/partner';
  static const String permissions = '/permissions';

  static const String home = '/';
  static const String albumsGangneung = '/albums/gangneung';
  static const String settings = '/settings';
  static const String connect = '/connect';
  static const String payment = '/payment';
  static const String breakup = '/breakup';

  // v5

  static const String capture = '/capture';

  static const String photoPath = '/photo';

  static const String instant = '/instant';

  static const String homeV4 = '/home-v4';

  static const String lab = '/lab';
  static const String foundation = '/foundation';
  static const String album = '/album';
  static const String albumGangneung = '/album-gangneung';
  static const String transcriptPath = '/transcript';
  static const String callPath = '/call';
  static const String callV1 = '/call-v1';

  static const String camera = '/camera';

  static const String cameraV3 = '/camera-v3';

  /// `?scene=album|canvas|call|camera|tabbar` · (tabbar) `mode=full|mini` · `variant=album|camera` · `demo=1`
  static const String glassV6 = '/glass-v6';

  static String glassV6Location(GlassV6Scene scene, {bool demo = false}) =>
      CameoLocation(glassV6, {
        'scene': scene.name,
        if (demo) 'demo': demoOn,
      }).toString();

  static String verify({required String phone}) =>
      CameoLocation(verifyPath, {'phone': phone}).toString();

  static String verifyPhoneOf(CameoLocation location) =>
      location.param('phone') ?? '';

  static String transcript({
    TranscriptTheme theme = TranscriptTheme.fallback,
  }) => CameoLocation(transcriptPath, {'theme': theme.param}).toString();

  /// '/call' (base) · '/call?state=media-16x9|media-4x3|media-1x1|sleep-toast' · '&sheet=instant|multi' —

  static String call({
    CallState state = CallState.base,
    PhotoSheetVariant? sheet,
  }) => CameoLocation(callPath, {
    if (state != CallState.fallback) 'state': state.param,
    if (sheet != null) sheetParam: sheet.param,
  }).toString();

  static const String sheetParam = 'sheet';

  static PhotoSheetVariant? photoSheetOf(CameoLocation location) =>
      PhotoSheetVariant.tryParse(location.param(sheetParam));

  static String photo({required String sectionId, required int index}) =>
      CameoLocation(photoPath, {
        'section': sectionId,
        'index': '$index',
      }).toString();

  static String photoSectionOf(CameoLocation location) =>
      location.param('section') ?? labAlbumV5.sections.first.id;

  static int photoIndexOf(CameoLocation location) {
    final i = int.tryParse(location.param('index') ?? '');
    return i == null || i < 0 ? 0 : i;
  }

  static const String viewParam = 'view';

  static AlbumView albumViewOf(CameoLocation location) =>
      AlbumView.tryParse(location.param(viewParam)) ?? AlbumView.fallback;

  static String albumView(AlbumView view) => view == AlbumView.fallback
      ? home
      : CameoLocation(home, {viewParam: view.param}).toString();

  static const String reviewParam = 'review';

  static bool captureReviewOf(CameoLocation location) =>
      location.param(reviewParam) == demoOn;

  /// '/capture' · '/capture?review=1'
  static String captureLocation({bool review = false}) => review
      ? CameoLocation(capture, {reviewParam: demoOn}).toString()
      : capture;

  static const String stateParam = 'state';

  static PartnerRouteState partnerStateOf(CameoLocation location) =>
      PartnerRouteState.tryParse(location.param(stateParam)) ??
      PartnerRouteState.fallback;

  /// '/partner' · '/partner?state=done'
  static String partnerLocation({
    PartnerRouteState state = PartnerRouteState.input,
  }) => state == PartnerRouteState.fallback
      ? partner
      : CameoLocation(partner, {stateParam: state.param}).toString();

  static VerifyRouteState verifyStateOf(CameoLocation location) =>
      VerifyRouteState.tryParse(location.param(stateParam)) ??
      VerifyRouteState.fallback;

  static TranscriptTheme transcriptThemeOf(CameoLocation location) =>
      TranscriptTheme.tryParse(location.param('theme')) ??
      TranscriptTheme.fallback;

  static double? initialScrollOf(CameoLocation location) {
    final value = double.tryParse(location.param('scroll') ?? '');
    return value != null && value.isFinite && value >= 0 ? value : null;
  }

  static const String demoOn = '1';

  static bool demoOf(CameoLocation location) =>
      location.param('demo') == demoOn;

  static String withDemo(String location) {
    final l = CameoLocation.parse(location);
    return CameoLocation(l.path, {...l.params, 'demo': demoOn}).toString();
  }

  static const String demoFlow = 'flow';

  static bool flowDemoOf(CameoLocation location) =>
      location.path == home && location.param('demo') == demoFlow;

  static const String flowDemo = '$home?demo=$demoFlow';

  static CallState callStateOf(CameoLocation location) =>
      CallState.tryParse(location.param('state')) ?? CallState.fallback;

  static const String sessionParam = 'session';
  static const String partnerParam = 'partner';
  static const String partnerNone = 'none';
  static const String albumParam = 'album';
  static const String albumEmpty = 'empty';
  static const String albumFull = 'full';

  static bool? albumEmptyOf(CameoLocation location) =>
      switch (location.param(albumParam)) {
        albumEmpty => true,
        albumFull => false,
        _ => null,
      };

  static DevSessionKind? devSessionOf(CameoLocation location) =>
      DevSessionKind.tryParse(location.param(sessionParam));

  static bool partnerNoneOf(CameoLocation location) =>
      location.param(partnerParam) == partnerNone;

  static const Set<String> _devParams = {
    sessionParam,
    partnerParam,
    albumParam,
  };

  static CameoLocation withoutDevParams(CameoLocation location) {
    if (!location.params.keys.any(_devParams.contains)) return location;
    return CameoLocation(location.path, {
      for (final e in location.params.entries)
        if (!_devParams.contains(e.key)) e.key: e.value,
    });
  }

  static final Map<String, CameoRouteSpec> table = {
    for (final spec in _specs) spec.path: spec,
  };

  static bool isKnownPath(String path) => table.containsKey(path);

  static CameoStatusBarStyle _dark(CameoLocation _) =>
      CameoStatusBarStyle.darkContent;

  static CameoStatusBarStyle _light(CameoLocation _) =>
      CameoStatusBarStyle.lightContent;

  static final List<CameoRouteSpec> _specs = [
    CameoRouteSpec(
      path: welcome,
      presentation: CameoPresentation.push,
      statusBar: _dark,
      guard: SessionStatus.signedOut,
      builder: (_, _) => const WelcomeScreen(),
    ),
    CameoRouteSpec(
      path: phone,
      presentation: CameoPresentation.push,
      statusBar: _dark,
      guard: SessionStatus.signedOut,
      builder: (_, _) => const PhoneScreen(),
    ),
    CameoRouteSpec(
      path: verifyPath,
      presentation: CameoPresentation.push,
      statusBar: _dark,
      guard: SessionStatus.signedOut,
      builder: (_, l) =>
          VerifyScreen(phone: verifyPhoneOf(l), state: verifyStateOf(l)),
    ),

    CameoRouteSpec(
      path: profile,
      presentation: CameoPresentation.push,
      statusBar: _dark,
      guard: SessionStatus.onboarding,
      builder: (_, _) => const ProfileScreen(),
    ),
    CameoRouteSpec(
      path: partner,
      presentation: CameoPresentation.push,
      statusBar: _dark,
      guard: SessionStatus.onboarding,
      builder: (_, l) => PartnerScreen(state: partnerStateOf(l)),
    ),
    CameoRouteSpec(
      path: permissions,
      presentation: CameoPresentation.push,
      statusBar: _dark,
      guard: SessionStatus.onboarding,
      builder: (_, _) => const PermissionsScreen(),
    ),

    CameoRouteSpec(
      path: home,
      presentation: CameoPresentation.tab,
      statusBar: _light,
      guard: SessionStatus.member,
      tab: CameoTabs.albums,
      builder: (_, l) => HomeTimelineScreen(initialView: albumViewOf(l)),
    ),

    CameoRouteSpec(
      path: capture,
      presentation: CameoPresentation.tab,
      statusBar: _light,
      guard: SessionStatus.member,
      tab: CameoTabs.camera,
      builder: (_, l) =>
          CameraV6Screen(mode: CameraV6Mode.tab, review: captureReviewOf(l)),
    ),

    CameoRouteSpec(
      path: albumsGangneung,
      presentation: CameoPresentation.tab,
      statusBar: _light,
      guard: SessionStatus.member,
      tab: CameoTabs.albums,
      nested: true,
      builder: (_, l) => AlbumGangneungScreen(
        inTabs: true,
        initialScroll: initialScrollOf(l),
        demo: demoOf(l),
      ),
    ),
    CameoRouteSpec(
      path: settings,
      presentation: CameoPresentation.tab,
      statusBar: _dark,
      guard: SessionStatus.member,
      tab: CameoTabs.settings,
      builder: (_, _) => const SettingsScreen(),
    ),
    CameoRouteSpec(
      path: connect,
      presentation: CameoPresentation.push,
      statusBar: _dark,
      guard: SessionStatus.member,
      builder: (_, _) => const PartnerScreen(mode: PartnerMode.settings),
    ),
    CameoRouteSpec(
      path: payment,
      presentation: CameoPresentation.push,
      statusBar: _dark,
      guard: SessionStatus.member,
      builder: (_, location) =>
          PaymentScreen(archiveId: location.param('recovery')),
    ),
    CameoRouteSpec(
      path: breakup,
      presentation: CameoPresentation.push,
      statusBar: _dark,
      guard: SessionStatus.member,
      builder: (_, _) => const BreakupScreen(),
    ),

    CameoRouteSpec(
      path: photoPath,
      presentation: CameoPresentation.viewer,
      statusBar: _light,
      builder: (_, l) => PhotoViewerScreen(
        sectionId: photoSectionOf(l),
        index: photoIndexOf(l),
      ),
    ),
    CameoRouteSpec(
      path: instant,
      presentation: CameoPresentation.viewer,
      statusBar: _light,
      builder: (_, _) => const InstantViewerScreen(),
    ),

    CameoRouteSpec(
      path: homeV4,
      presentation: CameoPresentation.push,
      statusBar: _dark,
      builder: (_, _) => const HomeScreen(),
    ),

    CameoRouteSpec(
      path: lab,
      presentation: CameoPresentation.push,
      statusBar: _dark,
      builder: (_, _) => const LabScreen(),
    ),
    CameoRouteSpec(
      path: foundation,
      presentation: CameoPresentation.push,
      statusBar: _light,
      builder: (context, _) => ColoredBox(
        color: CameoTheme.colorsOf(context).backgroundCanvasBase,
        child: const FoundationPreview(),
      ),
    ),
    CameoRouteSpec(
      path: album,
      presentation: CameoPresentation.push,
      statusBar: _light,
      builder: (_, l) =>
          AlbumScreen(initialScroll: initialScrollOf(l), demo: demoOf(l)),
    ),
    CameoRouteSpec(
      path: albumGangneung,
      presentation: CameoPresentation.push,
      statusBar: _light,
      builder: (_, l) => AlbumGangneungScreen(
        initialScroll: initialScrollOf(l),
        demo: demoOf(l),
      ),
    ),

    CameoRouteSpec(
      path: transcriptPath,
      presentation: CameoPresentation.push,
      statusBar: transcriptStatusBarFor,
      builder: (_, l) => transcriptScreenFor(l),
    ),
    CameoRouteSpec(
      path: callPath,
      presentation: CameoPresentation.modal,
      statusBar: _light,
      builder: (_, l) => CallScreen(
        state: callStateOf(l),
        demo: demoOf(l),
        sheet: photoSheetOf(l),
      ),
    ),
    CameoRouteSpec(
      path: callV1,
      presentation: CameoPresentation.modal,
      statusBar: _light,
      builder: (_, _) => const CallV1Screen(),
    ),

    CameoRouteSpec(
      path: cameraV3,
      presentation: CameoPresentation.modal,
      statusBar: _light,
      builder: (_, l) => CameraScreen(demo: demoOf(l)),
    ),

    CameoRouteSpec(
      path: glassV6,
      presentation: CameoPresentation.push,
      statusBar: (l) => l.param('scene') == GlassV6Scene.canvas.name
          ? CameoStatusBarStyle.darkContent
          : CameoStatusBarStyle.lightContent,
      builder: (_, l) => GlassV6Harness(
        scene: GlassV6Scene.tryParse(l.param('scene')) ?? GlassV6Scene.album,
        mode: l.param('mode') == 'mini' ? TabBarV6Mode.mini : TabBarV6Mode.full,
        variant: l.param('variant') == 'camera'
            ? TabBarV6Variant.camera
            : TabBarV6Variant.album,
        demo: demoOf(l),
      ),
    ),

    CameoRouteSpec(
      path: camera,
      presentation: CameoPresentation.modal,
      statusBar: _light,
      builder: (context, _) => ColoredBox(
        color: CameoTheme.colorsOf(context).staticBlackBase,
        child: const CameraV6Screen(mode: CameraV6Mode.call),
      ),
    ),
  ];
}

///

Route<dynamic> onGenerateCameoRoute(RouteSettings settings) =>
    cameoRouteFor<dynamic>(settings);

Route<T> cameoRouteFor<T>(
  RouteSettings settings, {
  CameoPageEntry entry = CameoPageEntry.slide,
}) {
  final name = settings.name ?? CameoRoutes.home;
  final location = CameoLocation.parse(name);
  final spec = _specOf(location, name);
  _warnInvalidParams(location);

  final args = settings.arguments;
  final presentation = args is CameoPresentation ? args : spec.presentation;
  final routeSettings = RouteSettings(name: name, arguments: location);
  final build = _screenBuilder(spec, location);

  return switch (presentation) {
    CameoPresentation.push => CameoPageRoute<T>(
      settings: routeSettings,
      builder: build,
      entry: entry,
    ),
    CameoPresentation.modal => CameoModalRoute<T>(
      settings: routeSettings,
      builder: build,
    ),

    CameoPresentation.viewer => CameoViewerRoute<T>(
      settings: routeSettings,
      builder: build,
    ),

    CameoPresentation.tab => CameoShellRoute<T>(
      settings: routeSettings,
      builder: (context) => CameoStatusBar(
        style: CameoStatusBarStyle.lightContent,
        child: AppTabs(
          initialTab: spec.tab ?? CameoTabs.albums,

          albumsRoutes: spec.nested
              ? [CameoRoutes.home, location.toString()]
              : [
                  location.path == CameoRoutes.home
                      ? location.toString()
                      : CameoRoutes.home,
                ],

          initialLocation: spec.nested || spec.tab == CameoTabs.albums
              ? null
              : location.toString(),
        ),
      ),
    ),
  };
}

Route<dynamic> onGenerateCameoTabRoute(RouteSettings settings) =>
    cameoTabRouteFor<dynamic>(settings);

Route<T> cameoTabRouteFor<T>(RouteSettings settings) {
  final name = settings.name ?? CameoRoutes.home;
  final location = CameoLocation.parse(name);
  final spec = CameoRoutes.table[location.path];
  if (spec == null ||
      spec.presentation != CameoPresentation.tab ||
      spec.tab != CameoTabs.albums) {
    debugPrint('[cameo] "$name" is not a tab-0 route → ${CameoRoutes.home}');
    return cameoTabRouteFor<T>(const RouteSettings(name: CameoRoutes.home));
  }
  return CameoPageRoute<T>(
    settings: RouteSettings(name: name, arguments: location),
    builder: _screenBuilder(spec, location),
  );
}

Route<T> cameoViewerRouteFor<T>(
  String location, {
  Rect? source,
  String? sourceKey,
  double sourceRadius = 0,
}) {
  final parsed = CameoLocation.parse(location);
  final spec = _specOf(parsed, location);
  return CameoViewerRoute<T>(
    settings: RouteSettings(name: location, arguments: parsed),
    source: source,
    sourceKey: sourceKey,
    sourceRadius: sourceRadius,
    builder: _screenBuilder(spec, parsed),
  );
}

Route<T> cameoZoomRouteFor<T>(ZoomTarget target, Rect source) {
  final location = CameoLocation.parse(target.location);
  final spec = _specOf(location, target.location);
  return CameoZoomPageRoute<T>(
    settings: RouteSettings(name: target.location, arguments: location),
    target: target,
    source: source,
    builder: _screenBuilder(spec, location),
  );
}

Widget cameoScreenFor(BuildContext context, String name) {
  final location = CameoLocation.parse(name);
  return _screenBuilder(_specOf(location, name), location)(context);
}

CameoRouteSpec _specOf(CameoLocation location, String name) {
  final spec = CameoRoutes.table[location.path];
  if (spec != null) return spec;
  debugPrint('[cameo] unknown route "$name" → ${CameoRoutes.home}');
  return CameoRoutes.table[CameoRoutes.home]!;
}

WidgetBuilder _screenBuilder(CameoRouteSpec spec, CameoLocation location) =>
    (context) => CameoStatusBar(
      style: spec.statusBar(location),
      child: spec.builder(context, location),
    );

void _warnInvalidParams(CameoLocation location) {
  if (!kDebugMode) return;
  final theme = location.param('theme');
  if (location.path == CameoRoutes.transcriptPath &&
      theme != null &&
      TranscriptTheme.tryParse(theme) == null) {
    debugPrint(
      '[cameo] unknown theme "$theme" → ${TranscriptTheme.fallback.param}',
    );
  }
  final demo = location.param('demo');
  final flow =
      location.path == CameoRoutes.home && demo == CameoRoutes.demoFlow;
  if (demo != null && demo != CameoRoutes.demoOn && !flow) {
    debugPrint(
      '[cameo] demo="$demo" → off (only demo=${CameoRoutes.demoOn}, '
      'or demo=${CameoRoutes.demoFlow} on ${CameoRoutes.home})',
    );
  }
  final session = location.param(CameoRoutes.sessionParam);
  if (session != null && DevSessionKind.tryParse(session) == null) {
    debugPrint(
      '[cameo] unknown session "$session" → stored session '
      '(guest|onboarding|member)',
    );
  }
  final sheet = location.param(CameoRoutes.sheetParam);
  if (location.path == CameoRoutes.callPath &&
      sheet != null &&
      PhotoSheetVariant.tryParse(sheet) == null) {
    debugPrint(
      '[cameo] unknown sheet "$sheet" → session setting (instant|multi)',
    );
  }
  final album = location.param(CameoRoutes.albumParam);
  if (album != null && CameoRoutes.albumEmptyOf(location) == null) {
    debugPrint('[cameo] unknown album "$album" → unchanged (empty|full)');
  }
  final view = location.param(CameoRoutes.viewParam);
  if (location.path == CameoRoutes.home &&
      view != null &&
      AlbumView.tryParse(view) == null) {
    debugPrint(
      '[cameo] unknown view "$view" → timeline (liked|deleted|select)',
    );
  }
  final review = location.param(CameoRoutes.reviewParam);
  if (location.path == CameoRoutes.capture &&
      review != null &&
      review != CameoRoutes.demoOn) {
    debugPrint('[cameo] review="$review" → off (only review=1)');
  }
  final state = location.param('state');
  if (location.path == CameoRoutes.partner &&
      state != null &&
      PartnerRouteState.tryParse(state) == null) {
    debugPrint('[cameo] unknown partner state "$state" → input (done)');
  }
  if (location.path == CameoRoutes.verifyPath &&
      state != null &&
      VerifyRouteState.tryParse(state) == null) {
    debugPrint('[cameo] unknown verify state "$state" → input (success)');
  }
  if (location.path == CameoRoutes.callPath &&
      state != null &&
      CallState.tryParse(state) == null) {
    debugPrint(
      '[cameo] unknown call state "$state" → ${CallState.fallback.param}',
    );
  }
}
