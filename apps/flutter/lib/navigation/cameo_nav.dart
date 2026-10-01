// Navigation entry points and top-route guards. Root overlays use the root navigator;
// album subroutes use the nested album stack.

import 'package:flutter/widgets.dart';

import '../state/album_store.dart';
import '../state/session.dart' show PhotoSheetVariant, SessionScope;
import '../state/captured_photo.dart';
import 'app_tabs.dart';
import 'cameo_location.dart';
import 'cameo_modal_route.dart';
import 'cameo_page_route.dart';
import 'cameo_routes.dart';
import 'cameo_viewer_route.dart';
import 'zoom_source.dart';

abstract interface class CameoLocationHost {
  void openLocation(String location);
}

class CameoLocationHostScope extends InheritedWidget {
  const CameoLocationHostScope({
    super.key,
    required this.host,
    required super.child,
  });

  final CameoLocationHost host;

  static CameoLocationHost? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CameoLocationHostScope>()?.host;

  @override
  bool updateShouldNotify(CameoLocationHostScope oldWidget) =>
      host != oldWidget.host;
}

///
/// ```dart
/// CameoNav.push(context, CameoRoutes.transcript(theme: TranscriptTheme.photo));

/// // v4
/// CameoNav.openPhone(context);  CameoNav.openVerify(context, '01012345678');
/// CameoNav.openPartner(context);  CameoNav.openPermissions(context);  CameoNav.openConnect(context);

/// // v5

/// ```
///

abstract final class CameoNav {
  ///

  static bool isTop(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    return CameoTabScope.isVisible(context);
  }

  static NavigatorState _root(BuildContext context) =>
      Navigator.of(context, rootNavigator: true);

  static Future<T?> push<T extends Object?>(
    BuildContext context,
    String location,
  ) {
    if (!isTop(context)) return Future<T?>.value();
    final spec = CameoRoutes.table[CameoLocation.parse(location).path];
    final tabs = AppTabs.maybeOf(context);
    if (spec != null &&
        spec.presentation == CameoPresentation.tab &&
        tabs != null) {
      if (!spec.nested) {
        tabs.select(spec.tab ?? CameoTabs.albums);
        return Future<T?>.value();
      }
      return tabs.pushAlbums<T>(
        cameoTabRouteFor<T>(RouteSettings(name: location)),
      );
    }
    return _root(context).pushNamed<T>(location);
  }

  static Future<T?> presentModal<T extends Object?>(
    BuildContext context,
    String location,
  ) {
    if (!isTop(context)) return Future<T?>.value();
    return _root(
      context,
    ).pushNamed<T>(location, arguments: CameoPresentation.modal);
  }

  ///

  static Future<CapturedPhoto?> presentCamera(BuildContext context) {
    if (!isTop(context)) return Future<CapturedPhoto?>.value();
    return _root(context).push<CapturedPhoto>(
      cameoRouteFor<CapturedPhoto>(
        const RouteSettings(name: CameoRoutes.camera),
      ),
    );
  }

  static bool dismissModalThen(BuildContext context, String location) {
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return false;
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return false;
    route.completed.then((_) {
      if (navigator.mounted) navigator.pushNamed<Object?>(location);
    });
    navigator.pop();
    return true;
  }

  ///

  static bool pop<T extends Object?>(BuildContext context, [T? result]) {
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return false;
    navigator.pop<T>(result);
    return true;
  }

  static Future<bool> maybePop<T extends Object?>(
    BuildContext context, [
    T? result,
  ]) {
    return Navigator.of(context).maybePop<T>(result);
  }

  static void popToRoot(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  static Future<T?> pushPage<T extends Object?>(
    BuildContext context,
    WidgetBuilder builder, {
    RouteSettings? settings,
  }) {
    return Navigator.of(
      context,
    ).push<T>(CameoPageRoute<T>(builder: builder, settings: settings));
  }

  static Future<T?> presentModalPage<T extends Object?>(
    BuildContext context,
    WidgetBuilder builder, {
    RouteSettings? settings,
  }) {
    return _root(
      context,
    ).push<T>(CameoModalRoute<T>(builder: builder, settings: settings));
  }

  /* ───────── v4 (docs/v4-plan.md §11.3) ───────── */

  static Future<void> openPhone(BuildContext context) =>
      push<void>(context, CameoRoutes.phone);

  static Future<void> openVerify(BuildContext context, String phone) =>
      push<void>(context, CameoRoutes.verify(phone: phone));

  static Future<void> openPartner(BuildContext context) =>
      push<void>(context, CameoRoutes.partner);

  static Future<void> openPermissions(BuildContext context) =>
      push<void>(context, CameoRoutes.permissions);

  static Future<void> openConnect(BuildContext context) =>
      push<void>(context, CameoRoutes.connect);

  static Future<void> openPayment(BuildContext context, {String? archiveId}) =>
      push<void>(
        context,
        CameoLocation(CameoRoutes.payment, {
          if (archiveId != null) 'recovery': archiveId,
        }).toString(),
      );

  static Future<void> openBreakup(BuildContext context) =>
      push<void>(context, CameoRoutes.breakup);

  static Future<void> openLab(BuildContext context) =>
      push<void>(context, CameoRoutes.lab);

  /* ───────── v5 (docs/v5-plan.md §3 · §9) ───────── */

  static Future<void> openCall(
    BuildContext context, {
    PhotoSheetVariant? sheet,
  }) {
    if (!isTop(context)) return Future<void>.value();
    final session = SessionScope.maybeRead(context);
    if (session?.usesBackend == true && session!.session.partner == null) {
      return openConnect(context);
    }
    if (session?.storage?.isFull == true &&
        session!.shouldOfferStorageUpgrade) {
      return openPayment(context);
    }
    return _root(context).pushNamed<void>(CameoRoutes.call(sheet: sheet));
  }

  static Future<CapturedPhoto?> openCameraFromCall(BuildContext context) =>
      presentCamera(context);

  static Future<void> openPhotoViewer(
    BuildContext context,
    String sectionId,
    int index,
    Rect rect,
  ) {
    if (!isTop(context)) return Future<void>.value();
    final key = AlbumScope.maybeRead(context)?.photoAt(sectionId, index)?.id;
    if (key != null) ViewerSource.set(key, rect);
    return _root(context).push<void>(
      cameoViewerRouteFor<void>(
        CameoRoutes.photo(sectionId: sectionId, index: index),
        source: rect,
        sourceKey: key,
      ),
    );
  }

  static Future<void> openInstant(
    BuildContext context, {
    Rect? rect,
    double sourceRadius = 0,
  }) {
    if (!isTop(context)) return Future<void>.value();
    return _root(context).push<void>(
      cameoViewerRouteFor<void>(
        CameoRoutes.instant,
        source: rect,
        sourceRadius: sourceRadius,
      ),
    );
  }

  static Future<void> openAlbumZoom(
    BuildContext context,
    ZoomTarget target,
    Rect rect,
  ) {
    if (!isTop(context)) return Future<void>.value();
    ZoomSource.set(target, rect);
    final route = cameoZoomRouteFor<void>(target, rect);
    final tabs = AppTabs.maybeOf(context);
    if (target == ZoomTarget.gangneung && tabs != null) {
      return tabs.pushAlbums<void>(route);
    }
    return _root(context).push<void>(route);
  }

  static bool selectTab(BuildContext context, int index) {
    final tabs = AppTabs.maybeOf(context);
    if (tabs == null) return false;
    tabs.select(index);
    return true;
  }

  static void openLocation(BuildContext context, String location) {
    final host = CameoLocationHostScope.maybeOf(context);
    if (host != null) {
      host.openLocation(location);
    } else {
      push<void>(context, location);
    }
  }
}
