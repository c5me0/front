// Request microphone, camera, and notification permission in order, then complete
// onboarding. Flow playback substitutes simulated permission services.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../components/auth_scaffold.dart';
import '../../components/permission_card.dart';
import '../../components/solid_cta.dart';
import '../../content/app.g.dart';
import '../../content/lab.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/navigation.dart';
import '../../state/permissions.dart';
import '../../state/session.dart';

enum _Run { ready, requesting, done }

/// RN `permissionRowStatus`.
PermissionCardStatus permissionCardStatusOf(
  PermissionKind kind,
  PermissionState state,
  PermissionKind? requesting,
) {
  if (requesting == kind) return PermissionCardStatus.requesting;
  return switch (state) {
    PermissionState.undetermined => PermissionCardStatus.pending,
    PermissionState.granted => PermissionCardStatus.granted,
    PermissionState.denied => PermissionCardStatus.denied,
  };
}

/// permission.gapMs 250. RN `permissionRequestPlan`.
List<({PermissionKind kind, Duration delay})> permissionRequestPlan(
  List<PermissionKind> order,
  PermissionState Function(PermissionKind kind) stateOf, {
  Duration gap = CameoMotion.permissionGap,
}) {
  final plan = <({PermissionKind kind, Duration delay})>[];
  for (final kind in order) {
    if (stateOf(kind) != PermissionState.undetermined) continue;
    plan.add((kind: kind, delay: plan.isEmpty ? Duration.zero : gap));
  }
  return plan;
}

CameoIconName _iconOf(String key) => CameoIconName.values.firstWhere(
  (n) => n.key == key,
  orElse: () => CameoIconName.borderNone,
);

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  static Key cardKey(PermissionKind kind) =>
      ValueKey('permissions.card.${kind.name}');
  static const Key ctaKey = ValueKey('permissions.cta');

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  PermissionKind? _requesting;
  _Run _run = _Run.ready;
  Timer? _enter;
  late final VoidCallback _unregisterFlow;

  @override
  void initState() {
    super.initState();
    _unregisterFlow = FlowDemo.register(
      FlowDemoAction.permissionsAllow,
      _allowFromDemo,
    );
  }

  @override
  void dispose() {
    _unregisterFlow();
    _enter?.cancel();
    super.dispose();
  }

  Future<void> _allow() async {
    if (_run != _Run.ready || !CameoNav.isTop(context)) return;
    final session = SessionScope.read(context);
    final service = PermissionServiceScope.of(context);
    setState(() => _run = _Run.requesting);
    final plan = permissionRequestPlan(
      PermissionKind.values,
      session.session.permissionOf,
    );
    for (final step in plan) {
      if (step.delay > Duration.zero) await Future<void>.delayed(step.delay);
      if (!mounted) return;
      setState(() => _requesting = step.kind);
      final state = await service.request(step.kind);
      if (!mounted) return;
      session.setPermission(step.kind, state);
      setState(() => _requesting = null);
    }
    if (!mounted) return;
    setState(() => _run = _Run.done);
    _enter = Timer(CameoMotion.authEnterAppDelay, _enterApp);
  }

  void _enterApp() {
    _enter?.cancel();
    _enter = null;
    if (!mounted) return;
    SessionScope.read(context).completeOnboarding();
  }

  bool _allowFromDemo() {
    if (!mounted || _run != _Run.ready || !CameoNav.isTop(context)) {
      return false;
    }
    _allow();
    return true;
  }

  void _skip() {
    if (_run == _Run.requesting || !CameoNav.isTop(context)) return;
    _enterApp();
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context).session;
    final content = labV6.permissions;
    return AuthScaffold(
      title: content.title,
      subtitle: content.subtitle,
      onBack: () => CameoNav.pop(context),
      trailingLabel: content.skip,
      onTrailing: _skip,
      footer: SolidCta(
        key: PermissionsScreen.ctaKey,
        label: _run == _Run.done
            ? appContent.v6.permissions.ctaDone
            : content.cta,
        busy: _run == _Run.requesting,
        onPress: _run == _Run.done ? _enterApp : _allow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CameoLayout.permissionCardV6Gap,
        children: [
          for (final item in content.items)
            PermissionCard(
              key: PermissionsScreen.cardKey(
                PermissionKind.values.byName(item.id),
              ),
              icon: _iconOf(item.icon),
              title: item.title,
              description: item.description,
              status: permissionCardStatusOf(
                PermissionKind.values.byName(item.id),
                session.permissionOf(PermissionKind.values.byName(item.id)),
                _requesting,
              ),
            ),
        ],
      ),
    );
  }
}
