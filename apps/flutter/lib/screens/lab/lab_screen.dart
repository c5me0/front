// Development screen index. Route navigation preserves explicit session and preview
// parameters.

import 'package:flutter/widgets.dart';

import '../../design_system/design_system.dart';
import '../../navigation/cameo_location.dart';
import '../../navigation/cameo_nav.dart';
import '../../navigation/cameo_routes.dart';
import 'lab_entries.dart';

class LabScreen extends StatelessWidget {
  const LabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final c = CameoTheme.colorsOf(context);
    return ColoredBox(
      color: c.backgroundCanvasBase,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          insets.left + CameoLayout.screenGutter,
          insets.top + CameoSpace.s16,
          insets.right + CameoLayout.screenGutter,
          insets.bottom + CameoSpace.s48,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: CameoSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: CameoSpace.s4,
              children: [
                const CameoText('cameo lab', style: CameoTextStyles.headingLg),
                CameoText(
                  'Figma lab 0:1 · 개발용 화면 목록',
                  style: CameoTextStyles.bodyMd,
                  color: c.foregroundNeutralMuted,
                ),
              ],
            ),
          ),
          for (final section in labSections)
            Padding(
              padding: const EdgeInsets.only(top: CameoSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: CameoSpace.s4),
                    child: CameoText(
                      section.title,
                      style: CameoTextStyles.bodySmStrong,
                      color: c.foregroundNeutralMuted,
                    ),
                  ),
                  for (final entry in section.entries) _LabRow(entry: entry),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LabRow extends StatelessWidget {
  const _LabRow({required this.entry});

  final LabEntry entry;

  @override
  Widget build(BuildContext context) {
    final location = entry.location;
    final enabled = location != null;
    final presentation = enabled
        ? CameoRoutes.table[CameoLocation.parse(location).path]?.presentation
        : null;
    final suffix = entry.resetsStack
        ? ' · 스택 교체'
        : switch (presentation) {
            CameoPresentation.modal => ' · 모달',
            CameoPresentation.tab => ' · 탭',
            _ => '',
          };
    final route = location == null ? '라우트 없음' : '$location$suffix';
    final c = CameoTheme.colorsOf(context);
    return _PressableRow(
      onTap: !enabled
          ? null
          : entry.resetsStack
          ? () => CameoNav.openLocation(context, location)
          : () => CameoNav.push(context, location),
      label: '${entry.frame} ${entry.description}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: c.strokeNeutralBase,
              width: CameoBorderWidth.hairline,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: CameoSpace.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: CameoSpace.s4,
            children: [
              CameoText(
                entry.frame,
                style: CameoTextStyles.bodyLgStrong,
                color: enabled
                    ? c.foregroundNeutralBase
                    : c.foregroundNeutralSubtle,
              ),
              CameoText(
                entry.description,
                style: CameoTextStyles.bodyMd,
                color: enabled
                    ? c.foregroundNeutralMuted
                    : c.foregroundNeutralSubtle,
              ),
              CameoText(
                '${entry.nodes} · $route',
                style: CameoTextStyles.bodySm,
                color: c.foregroundNeutralSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PressableRow extends StatefulWidget {
  const _PressableRow({
    required this.onTap,
    required this.label,
    required this.child,
  });

  final VoidCallback? onTap;
  final String label;
  final Widget child;

  @override
  State<_PressableRow> createState() => _PressableRowState();
}

class _PressableRowState extends State<_PressableRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _down() => _reduceMotion
      ? _scale.value = CameoMotion.pressScale
      : _scale.springTo(CameoMotion.pressScale, CameoSprings.press);

  void _release() =>
      _reduceMotion ? _scale.value = 1 : _scale.springTo(1, CameoSprings.chewy);

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _down() : null,
        onTapUp: enabled ? (_) => _release() : null,
        onTapCancel: enabled ? _release : null,
        onTap: widget.onTap,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}
