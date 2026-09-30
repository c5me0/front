// Application composition root. Bind session, album, device services, theme, and
// navigation; defer the initial route until stored session state is loaded.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'design_system/design_system.dart';
import 'navigation/navigation.dart';
import 'state/album_store.dart';
import 'state/device_services.dart';
import 'state/permissions.dart';
import 'state/session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(CameoStatusBarStyle.darkContent.overlay);
  runApp(CameoApp(initialRoute: resolveInitialRoute()));
}

const CameoColorMode kCameoRootColorMode = CameoColorMode.light;

class CameoApp extends StatefulWidget {
  const CameoApp({
    super.key,
    this.initialRoute = CameoRoutes.home,
    this.session,
    this.permissions = const SystemPermissionService(),
    this.album,
    this.services,
  });

  final String initialRoute;

  final SessionController? session;

  final PermissionService permissions;

  final AlbumStore? album;

  final DeviceServices? services;

  @override
  State<CameoApp> createState() => _CameoAppState();
}

class _CameoAppState extends State<CameoApp> {
  late final CameoLaunch _launch = CameoLaunch.parse(widget.initialRoute);
  late final SessionController _session = widget.session ?? SessionController();

  late final AlbumStore _album = widget.album ?? AlbumStore();
  late final DeviceServices _services =
      widget.services ?? DeviceServices.system();
  final GlobalKey<NavigatorState> _navigator = GlobalKey(
    debugLabel: 'cameo.root',
  );

  @override
  void initState() {
    super.initState();
    _session.bindAlbum(_album);
    _session.load(dev: _launch.devSession, partnerNone: _launch.partnerNone);
    final albumReset = _launch.albumReset;
    if (albumReset != null) _album.reset(empty: albumReset);
  }

  @override
  void dispose() {
    if (widget.session == null) _session.dispose();
    if (widget.album == null) _album.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = CameoPalette.of(kCameoRootColorMode);
    return WidgetsApp(
      title: 'cameo',
      color: palette.backgroundCanvasBase,
      debugShowCheckedModeBanner: false,
      textStyle: CameoTextStyles.bodyLg.copyWith(
        color: palette.foregroundNeutralBase,
      ),
      navigatorKey: _navigator,
      initialRoute: _launch.location.toString(),

      onGenerateInitialRoutes: (_) =>
          cameoInitialRoutes(_launch.location, _session.session),
      onGenerateRoute: onGenerateCameoRoute,

      builder: (context, navigator) => SessionScope(
        controller: _session,
        child: AlbumScope(
          store: _album,
          child: DeviceServicesScope(
            services: _services,
            child: CameoReducedMotionScope(
              child: CameoTheme(
                mode: kCameoRootColorMode,
                child: ColoredBox(
                  color: palette.backgroundCanvasBase,
                  child: ListenableBuilder(
                    listenable: _session,

                    builder: (context, _) => _session.isLoaded
                        ? CameoAppRoot(
                            session: _session,
                            album: _album,
                            navigatorKey: _navigator,
                            startFlowDemo: _launch.flowDemo,
                            permissions: widget.permissions,
                            child: navigator!,
                          )
                        : const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
