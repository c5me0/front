// Application composition root. Bind session, album, device services, theme, and
// navigation; defer the initial route until stored session state is loaded.

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'content/lab.g.dart';
import 'state/app_language.dart';

import 'design_system/design_system.dart';
import 'navigation/navigation.dart';
import 'state/album_store.dart';
import 'state/device_services.dart';
import 'state/permissions.dart';
import 'state/session.dart';
import 'api/api_config.dart';
import 'api/cameo_api.dart';
import 'api/credential_store.dart';
import 'state/live_call.dart';
import 'state/system_calls.dart';
import 'state/revenuecat_billing.dart';
import 'components/confirm_sheet.dart';
import 'content/app.g.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(CameoStatusBarStyle.darkContent.overlay);
  final language = await AppLanguageController.load();
  runApp(CameoApp(initialRoute: resolveInitialRoute(), language: language));
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
    this.language,
  });

  final String initialRoute;

  final SessionController? session;

  final PermissionService permissions;

  final AlbumStore? album;

  final DeviceServices? services;
  final AppLanguageController? language;

  @override
  State<CameoApp> createState() => _CameoAppState();
}

class _CameoAppState extends State<CameoApp> with WidgetsBindingObserver {
  Timer? _refreshTimer;
  late final AppLanguageController _language =
      widget.language ?? AppLanguageController();

  void _languageChanged() {
    _album.setLanguage(_language.language.code);
    setState(() {});
  }

  late final LiveCallController _calls = LiveCallController(
    permissions: widget.permissions,
  );
  late final SystemCalls _systemCalls = SystemCalls(_onSystemCall);
  late final RevenueCatBilling _billing = RevenueCatBilling(
    RevenueCatConfig.fromEnvironment(),
    account: _session,
  );
  late final CameoLaunch _launch = CameoLaunch.parse(
    widget.initialRoute,
    allowDemo: !_session.usesBackend,
  );
  late final SessionController _session = widget.session ?? _createSession();

  SessionController _createSession() {
    final config = ApiConfig.fromEnvironment();
    return SessionController(
      api: config == null
          ? null
          : CameoApi(
              config: config,
              credentials: SecureCredentialStore(config.baseUri),
            ),
    );
  }

  late final AlbumStore _album = widget.album ?? AlbumStore();
  late final DeviceServices _services =
      widget.services ?? DeviceServices.system();
  final GlobalKey<NavigatorState> _navigator = GlobalKey(
    debugLabel: 'cameo.root',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _album.setLanguage(_language.language.code);
    _language.addListener(_languageChanged);
    _session.bindAlbum(_album);
    _session.addListener(_syncCalls);
    _calls.addListener(_syncSystemCall);
    _syncCalls();
    _session.load(dev: _launch.devSession, partnerNone: _launch.partnerNone);
    final albumReset = _launch.albumReset;
    if (albumReset != null) _album.reset(empty: albumReset);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refresh(),
    );
  }

  void _syncCalls() {
    _calls.configure(
      _session.backend,
      _session.userId,
      _session.premiumRequired ? null : _session.session.partner?.id,
      _album.remote,
    );
    unawaited(_billing.identify());
    if (_session.isLoaded) {
      unawaited(_systemCalls.configure(_session.backend, _session.userId));
    }
  }

  void _syncSystemCall() => _systemCalls.sync(
    _calls,
    _session.session.partner?.name ??
        (_language.language == AppLanguage.english ? appContentEn : appContent)
            .v6
            .backend
            .partnerName,
  );

  Future<void> _onSystemCall(Map<String, dynamic> event) async {
    if (!mounted || !_session.usesBackend) return;
    final id = event['id'] as String?;
    switch (event['type']) {
      case 'answer':
        if (id == null) return;
        await _session.refreshBackend();
        if (!mounted || _session.userId == null || _session.premiumRequired) {
          await _systemCalls.reportEnded(id);
          return;
        }
        unawaited(_calls.start(id: id));
        _navigator.currentState?.pushNamed(
          '/call?id=${Uri.encodeQueryComponent(id)}',
        );
      case 'end':
        if (id == _calls.callId) {
          await _calls.end();
        } else if (id != null) {
          try {
            await _session.backend!.declineCall(id);
          } catch (_) {}
        }
      case 'reset':
        await _calls.end();
      case 'mute':
        _calls.setMuted(event['muted'] == true);
      case 'incoming':
        await _calls.pollIncoming();
      case 'refresh':
        await _refresh();
      case 'open_record':
        await _refresh();
        if (mounted && id != null) {
          _navigator.currentState?.pushNamed(
            '/transcript?id=${Uri.encodeQueryComponent(id)}',
          );
        }
    }
  }

  Future<void> _refresh() async {
    if (!mounted || !_session.usesBackend) return;
    await _session.refreshBackend();
    if (mounted) await _album.remote.refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _calls.setForeground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      unawaited(_billing.refresh());
      unawaited(_systemCalls.refreshRegistration());
      unawaited(_refresh());
      _refreshTimer ??= Timer.periodic(
        const Duration(seconds: 30),
        (_) => _refresh(),
      );
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _session.removeListener(_syncCalls);
    _calls.removeListener(_syncSystemCall);
    _language.removeListener(_languageChanged);
    if (widget.language == null) _language.dispose();
    _systemCalls.dispose();
    _billing.dispose();
    _calls.dispose();
    if (widget.session == null) _session.dispose();
    if (widget.album == null) _album.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = CameoPalette.of(kCameoRootColorMode);
    return AppLanguageScope(
      controller: _language,
      child: WidgetsApp(
        locale: _language.language.locale,
        supportedLocales: AppLanguageController.supportedLocales,
        localizationsDelegates: const [
          AppContent.delegate,
          LabV6.delegate,
          LabSamples.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
        ],
        title: 'cameo',
        color: palette.backgroundCanvasBase,
        debugShowCheckedModeBanner: false,
        textStyle: CameoTextStyles.bodyLg.copyWith(
          color: palette.foregroundNeutralBase,
        ),
        navigatorKey: _navigator,
        initialRoute: _launch.location.toString(),

        onGenerateInitialRoutes: (_) => cameoInitialRoutes(
          _launch.location,
          _session.session,
          controller: _session,
        ),
        onGenerateRoute: (settings) {
          final path = CameoLocation.parse(
            settings.name ?? CameoRoutes.home,
          ).path;
          final redirect = liveRouteRedirect(_session, path);
          return onGenerateCameoRoute(
            redirect == null ? settings : RouteSettings(name: redirect),
          );
        },

        builder: (context, navigator) => SessionScope(
          controller: _session,
          child: BillingScope(
            billing: _billing,
            child: LiveCallScope(
              controller: _calls,
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
                                  child: ListenableBuilder(
                                    listenable: _calls,
                                    child: navigator!,
                                    builder: (context, child) => Stack(
                                      children: [
                                        Positioned.fill(
                                          key: const ValueKey('app.navigator'),
                                          child: child!,
                                        ),
                                        if (_calls.incoming != null &&
                                            !_calls.hasCall)
                                          Positioned.fill(
                                            key: const ValueKey(
                                              'app.incomingCall',
                                            ),
                                            child: ConfirmSheet(
                                              visible: true,
                                              title: AppContent.of(
                                                context,
                                              ).v6.backend.callIncoming,
                                              body:
                                                  _session
                                                      .session
                                                      .partner
                                                      ?.name ??
                                                  AppContent.of(
                                                    context,
                                                  ).v6.backend.partnerName,
                                              confirmLabel: AppContent.of(
                                                context,
                                              ).v6.backend.answer,
                                              cancelLabel: AppContent.of(
                                                context,
                                              ).v6.backend.decline,
                                              onConfirm: () {
                                                final id = _calls.incoming?.id;
                                                if (id == null) return;
                                                unawaited(_calls.start(id: id));
                                                _navigator.currentState?.pushNamed(
                                                  '/call?id=${Uri.encodeQueryComponent(id)}',
                                                );
                                              },
                                              onCancel: () =>
                                                  unawaited(_calls.decline()),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                )
                              : const SizedBox.expand(),
                        ),
                      ),
                    ),
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
