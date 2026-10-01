// Choose initial routes from authentication state. Protected routes redirect to the
// appropriate session entry screen; account flows retain a settings back stack.

import 'package:flutter/widgets.dart';

import '../state/session.dart';
import 'cameo_location.dart';
import 'cameo_page_route.dart';
import 'cameo_routes.dart';

List<String> entryLocationsFor(Session session) {
  switch (session.status) {
    case SessionStatus.signedOut:
      return const [CameoRoutes.welcome];
    case SessionStatus.onboarding:
      final step = onboardingStepOf(session);
      return [
        CameoRoutes.profile,
        if (step.index >= OnboardingStep.partner.index) CameoRoutes.partner,
        if (step == OnboardingStep.permissions) CameoRoutes.permissions,
      ];
    case SessionStatus.member:
      return const [CameoRoutes.home];
  }
}

List<String> initialLocationsFor(
  CameoLocation location,
  Session session, {
  SessionController? controller,
}) {
  if (controller?.usesBackend == true) {
    final redirect = liveRouteRedirect(controller!, location.path);
    if (redirect != null) return [redirect];
    // No app tabs or unpaid back stack underneath the required account flow.
    final required = requiredLiveLocation(controller);
    if (required != null && required != CameoRoutes.welcome) {
      return [location.toString()];
    }
  }
  final entry = entryLocationsFor(session);
  final spec = CameoRoutes.table[location.path];
  if (spec == null) return entry;
  final name = location.toString();
  final guard = spec.guard;
  if (guard == null) return [...entry, name];
  if (guard != session.status) {
    debugPrint(
      '[cameo] "$name" needs session ${guard.name} '
      '(now ${session.status.name}) → ${entry.last}',
    );
    return entry;
  }
  return switch (location.path) {
    CameoRoutes.welcome => const [CameoRoutes.welcome],
    CameoRoutes.phone => const [CameoRoutes.welcome, CameoRoutes.phone],
    CameoRoutes.verifyPath => [CameoRoutes.welcome, CameoRoutes.phone, name],
    CameoRoutes.profile => const [CameoRoutes.profile],

    CameoRoutes.partner => [CameoRoutes.profile, name],
    CameoRoutes.permissions => const [
      CameoRoutes.profile,
      CameoRoutes.partner,
      CameoRoutes.permissions,
    ],
    CameoRoutes.connect => [CameoRoutes.home, name],
    CameoRoutes.payment || CameoRoutes.breakup => [CameoRoutes.settings, name],
    _ => [name],
  };
}

List<Route<dynamic>> cameoInitialRoutes(
  CameoLocation location,
  Session session, {
  SessionController? controller,
}) => [
  for (final name in initialLocationsFor(
    location,
    session,
    controller: controller,
  ))
    onGenerateCameoRoute(RouteSettings(name: name)),
];

Route<dynamic> cameoSessionEntryRoute(
  Session session, {
  String? location,
  SessionController? controller,
}) {
  final name =
      location ??
      (controller == null ? null : requiredLiveLocation(controller)) ??
      entryLocationsFor(session).last;
  final signedOut = session.status == SessionStatus.signedOut;
  final guarded =
      CameoRoutes.table[CameoLocation.parse(name).path]?.guard != null;
  return cameoRouteFor<dynamic>(
    RouteSettings(name: name),
    entry: signedOut && guarded ? CameoPageEntry.fade : CameoPageEntry.slide,
  );
}
