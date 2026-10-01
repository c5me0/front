// Settings cards, section headings, action rows, and profile rows. Cards share the v6
// canvas and continuous rounded corners.

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import 'avatar_v6.dart';
import 'ios_switch.dart';

/// RN `SettingsCard`.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(CameoLayout.settingsV6CardRadius),
      child: ColoredBox(
        color: c.backgroundCanvasNeutralBase,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class SettingsSectionV6 extends StatelessWidget {
  const SettingsSectionV6({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  static const Key labelKey = ValueKey('settingsSectionV6.label');

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final title = this.title;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CameoLayout.settingsV6SectionLabelGap,
      children: [
        if (title != null)
          SizedBox(
            key: labelKey,
            height: CameoLayout.settingsV6SectionLabelHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CameoLayout.settingsV6SectionLabelPaddingX,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  header: true,
                  child: CameoText(
                    title,
                    style: CameoTextStyles.bodyMd,
                    color: c.foregroundNeutralMuted,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
          ),
        SettingsCard(children: children),
      ],
    );
  }
}

sealed class SettingsRowV6Trailing {
  const SettingsRowV6Trailing();

  const factory SettingsRowV6Trailing.toggle({
    required bool value,
    required ValueChanged<bool> onValueChange,
  }) = SettingsRowV6Switch;

  const factory SettingsRowV6Trailing.chevron() = SettingsRowV6Chevron;

  const factory SettingsRowV6Trailing.value(String value) = SettingsRowV6Value;
}

final class SettingsRowV6Switch extends SettingsRowV6Trailing {
  const SettingsRowV6Switch({required this.value, required this.onValueChange});

  final bool value;
  final ValueChanged<bool> onValueChange;
}

final class SettingsRowV6Chevron extends SettingsRowV6Trailing {
  const SettingsRowV6Chevron();
}

final class SettingsRowV6Value extends SettingsRowV6Trailing {
  const SettingsRowV6Value(this.value);

  final String value;
}

enum SettingsRowV6Tone { defaultTone, destructive }

class SettingsRowV6 extends StatefulWidget {
  const SettingsRowV6({
    super.key,
    required this.label,
    this.icon,
    this.tone = SettingsRowV6Tone.defaultTone,
    this.trailing,
    this.onPress,
  });

  final String label;
  final CameoIconName? icon;
  final SettingsRowV6Tone tone;
  final SettingsRowV6Trailing? trailing;
  final VoidCallback? onPress;

  static const Key pressedKey = ValueKey('settingsRowV6.pressed');
  static const Key switchKey = ValueKey('settingsRowV6.switch');
  static const Key chevronKey = ValueKey('settingsRowV6.chevron');
  static const Key valueKey = ValueKey('settingsRowV6.value');

  @override
  State<SettingsRowV6> createState() => SettingsRowV6State();
}

class SettingsRowV6State extends State<SettingsRowV6>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );
  bool _reduceMotion = false;

  double get pressProgress => _press.value;

  @override
  void initState() {
    super.initState();
    _press;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _down() => _reduceMotion
      ? _press.value = 1
      : _press.springTo(1, CameoMotion.settingsRowPressSpring);

  void _up() => _reduceMotion
      ? _press.value = 0
      : _press.springTo(
          0,
          CameoMotion.settingsRowReleaseSpring,
          velocity: _press.velocity,
        );

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final trailing = widget.trailing;
    final isSwitch = trailing is SettingsRowV6Switch;
    final height = isSwitch
        ? CameoLayout.settingsV6ToggleRowHeight
        : CameoLayout.settingsV6ChevronRowHeight;
    final content = widget.tone == SettingsRowV6Tone.destructive
        ? c.systemRed
        : c.foregroundNeutralBase;
    final icon = widget.icon;

    final row = SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            key: SettingsRowV6.pressedKey,
            animation: _press,
            builder: (context, _) => Opacity(
              opacity: _press.value.clamp(0.0, 1.0),
              child: ColoredBox(color: c.backgroundFillNeutralBase),
            ),
          ),
          Padding(
            key: const ValueKey('settingsRowV6.content'),
            padding: const EdgeInsets.symmetric(
              horizontal: CameoLayout.settingsV6CardPaddingX,
              vertical: CameoLayout.settingsV6CardPaddingY,
            ),
            child: Row(
              spacing: CameoLayout.settingsV6CardGap,
              children: [
                if (icon != null)
                  CameoIcon(
                    icon,
                    size: CameoLayout.settingsV6ActionRowIconSize,
                    color: content,
                  ),
                Expanded(
                  child: CameoText(
                    widget.label,
                    style: CameoTextStyles.bodyLgStrong,
                    color: content,
                    maxLines: 1,
                  ),
                ),
                ?switch (trailing) {
                  SettingsRowV6Switch(:final value, :final onValueChange) =>
                    IosSwitch(
                      key: SettingsRowV6.switchKey,
                      value: value,
                      onValueChange: onValueChange,
                      semanticLabel: widget.label,
                    ),
                  SettingsRowV6Chevron() => CameoIcon(
                    key: SettingsRowV6.chevronKey,
                    CameoIconName.chevronRight,
                    size: CameoLayout.settingsV6ChevronRowChevronSize,
                    color: c.foregroundNeutralSubtle,
                  ),
                  SettingsRowV6Value(:final value) => Flexible(
                    child: AnimatedSwitcher(
                      key: SettingsRowV6.valueKey,
                      duration: CameoMotion.durationBase,
                      switchInCurve: CameoMotion.easingStandard,
                      switchOutCurve: CameoMotion.easingStandard,
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.centerRight,
                        children: [...previous, ?current],
                      ),
                      child: CameoText(
                        value,
                        key: ValueKey(value),
                        style: CameoTextStyles.bodyMd,
                        color: c.foregroundNeutralMuted,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  null => null,
                },
              ],
            ),
          ),
        ],
      ),
    );

    final onPress = widget.onPress;
    if (isSwitch || onPress == null) return row;
    final label = trailing is SettingsRowV6Value
        ? '${widget.label}, ${trailing.value}'
        : widget.label;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPress,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _down(),
        onTapUp: (_) => _up(),
        onTapCancel: _up,
        onTap: onPress,
        child: row,
      ),
    );
  }
}

enum SettingsPersonKind { me, partner }

/// ([SettingsCard] · [SettingsSectionV6]). RN `<SettingsPersonRow kind name phone status>`.
class SettingsPersonRow extends StatelessWidget {
  const SettingsPersonRow({
    super.key,
    required this.kind,
    required this.name,
    required this.phone,
    this.status,
  });

  final SettingsPersonKind kind;
  final String name;
  final String phone;

  final String? status;

  static const Key avatarKey = ValueKey('settingsPersonRow.avatar');
  static const Key nameKey = ValueKey('settingsPersonRow.name');
  static const Key phoneKey = ValueKey('settingsPersonRow.phone');
  static const Key statusKey = ValueKey('settingsPersonRow.status');

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final me = kind == SettingsPersonKind.me;
    final height = me
        ? CameoLayout.settingsV6ProfileHeight
        : CameoLayout.settingsV6PartnerHeight;
    final avatar = me
        ? CameoLayout.settingsV6ProfileAvatarSize
        : CameoLayout.settingsV6PartnerAvatarSize;
    final textGap = me
        ? CameoLayout.settingsV6ProfileTextGap
        : CameoLayout.settingsV6PartnerTextGap;
    final status = this.status;
    return Semantics(
      container: true,
      label: [name, phone, ?status].where((s) => s.isNotEmpty).join(', '),
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CameoLayout.settingsV6CardPaddingX,
            vertical: CameoLayout.settingsV6CardPaddingY,
          ),
          child: Row(
            spacing: CameoLayout.settingsV6CardGap,
            children: [
              AvatarV6(
                key: avatarKey,
                size: avatar,
                name: name,
                initialStyle: CameoTextStyles.avatarInitialSm,
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: textGap,
                  children: [
                    CameoText(
                      name,
                      key: nameKey,
                      style: me
                          ? CameoTextStyles.headingSmStrong
                          : CameoTextStyles.bodyLgStrong,
                      color: c.foregroundNeutralBase,
                      maxLines: 1,
                    ),
                    CameoText(
                      phone,
                      key: phoneKey,
                      style: CameoTextStyles.bodyMd,
                      color: c.foregroundNeutralMuted,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              if (status != null)
                CameoText(
                  status,
                  key: statusKey,
                  style: CameoTextStyles.bodyMd,
                  color: c.systemGreen,
                  maxLines: 1,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
