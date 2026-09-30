// Development preview of shared typography, colors, spacing, and surface primitives.

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';

const _typeSamples = <String, String>{
  'headingLg': '성수 데이트 코스에 대한 대화',
  'headingSm': '00:04',
  'bodyLgStrong': '아침 인사',
  'bodyLg': '2026년 8월 20일',
  'bodyMd': '8월 20일, 12시 20분',
  'bodySm': '중요 내용 #1',
  'bodySmStrong': '12시 20분',
  'display': 'Yurim',
  'transcriptLine': '주영아 토요일에 성수 갈까?',
  'quote': '나 내일 수능이라 컴싸 꼭 필요해!',
  'headingSmStrong': '사진',
  'bodyMdMedium': '200일째',
  // v6 (tokens 0.6.0 — reference/figma-v6)
  'headingMd': '1',
  'headingMdStrong': '성공적으로 Yurim님과 연결됐어요!',
  'tabLabel': 'history',
  'wordmark': 'CAMEO',
  'tagline': '통화하고, 함께 찍고, 모든 기록을 앨범으로 남겨보세요.',
  'transcriptLineV6': '주영아 토요일에 성수 갈까?',
  'avatarInitialSm': '이',
};

const _iconSizes = <(String, double)>[
  ('md', CameoIconTokens.sizeMd),
  ('sm', CameoIconTokens.sizeSm),
  ('xs', CameoIconTokens.sizeXs),
  ('xxs', CameoIconTokens.sizeXxs),
];

String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : '$v';

String _weightName(TextStyle s) => switch (s.fontWeight) {
  CameoFontWeight.medium => 'medium',
  CameoFontWeight.semibold => 'semibold',
  _ => 'regular',
};

String _styleLabel(String name) {
  final s = CameoTextStyles.byName[name]!;
  final size = s.fontSize!;

  final lh = (size * s.height! * 1000).round() / 1000;
  return '$name · ${_fmt(size)}/${_fmt(lh)} · ${_weightName(s)}';
}

class FoundationPreview extends StatelessWidget {
  const FoundationPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final palette = CameoTheme.colorsOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/reference/transcript-bg.png', fit: BoxFit.cover),
        ListView(
          padding: EdgeInsets.only(
            top: insets.top,
            bottom: insets.bottom + CameoSpace.s48,
          ),
          children: [
            SizedBox(
              height: CameoLayout.navBarHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CameoLayout.navBarPaddingX,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    GlassIconButton(
                      icon: CameoIconName.chevronLeft,
                      accessibilityLabel: 'back',
                    ),
                    GlassIconButtonGroup(
                      items: [
                        GlassIconButtonGroupItem(icon: CameoIconName.heart),
                        GlassIconButtonGroupItem(icon: CameoIconName.history),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // layout.navBarCompact (2001:1174) · navBarV1 (2018:2077)
            SizedBox(
              height: CameoLayout.navBarV1Height,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CameoLayout.navBarPaddingX,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    GlassIconButton(
                      icon: CameoIconName.chevronLeft,
                      variant: GlassNavVariant.compact,
                    ),
                    GlassIconButtonGroup(
                      variant: GlassNavVariant.compact,
                      items: [
                        GlassIconButtonGroupItem(icon: CameoIconName.star),
                        GlassIconButtonGroupItem(icon: CameoIconName.dots),
                      ],
                    ),
                    GlassIconButton(
                      icon: CameoIconName.moon,
                      variant: GlassNavVariant.v1,
                    ),
                  ],
                ),
              ),
            ),
            _Section(
              label:
                  'Typography — Interlude Variable${kCameoColorConfirmed ? '' : ' · color placeholder'}',
              children: [
                for (final MapEntry(key: name, value: sample)
                    in _typeSamples.entries)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: CameoSpace.s4,
                    children: [
                      CameoText(
                        _styleLabel(name),
                        style: CameoTextStyles.bodySm,
                        color: palette.foregroundNeutralInverseMuted,
                      ),
                      CameoText(
                        sample,
                        style: CameoTextStyles.byName[name]!,
                        color: palette.foregroundNeutralInverseBase,
                      ),
                    ],
                  ),
              ],
            ),
            _Section(
              label: 'Icons — Tabler 24 grid · stroke 1.5 · md 22',
              children: [
                LayoutBuilder(
                  builder: (context, c) => Wrap(
                    runSpacing: CameoSpace.s16,
                    children: [
                      for (final icon in CameoIconName.values)
                        SizedBox(
                          width: c.maxWidth / 4,
                          child: Column(
                            spacing: CameoSpace.s6,
                            children: [
                              CameoIcon(icon, color: palette.iconOnDark),
                              CameoText(
                                icon.cameo ? '${icon.key} (cameo)' : icon.key,
                                style: CameoTextStyles.bodySm,
                                color: palette.foregroundNeutralInverseMuted,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final (name, size) in _iconSizes)
                      Column(
                        spacing: CameoSpace.s6,
                        children: [
                          CameoIcon(
                            CameoIconName.heartFilled,
                            size: size,
                            color: palette.iconOnDark,
                          ),
                          CameoText(
                            '$name ${_fmt(size)}',
                            style: CameoTextStyles.bodySm,
                            color: palette.foregroundNeutralInverseMuted,
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
            _Section(
              label:
                  'Surfaces — glass (glassBar) · blur (backgroundBlur) · shadow',
              children: [
                SizedBox(
                  height: CameoLayout.playerPillHeight,
                  child: GlassSurface(
                    blur: CameoBlur.glassBar,
                    tint: palette.glassTintBar,
                    border: palette.glassBorder,
                    borderWidth: CameoLayout.playerPillBorderWidth,
                    child: Center(
                      child: CameoText(
                        'effect glass · blur glassBar',
                        style: CameoTextStyles.bodyMd,
                        color: palette.foregroundNeutralInverseBase,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: CameoLayout.callCardHeight,
                  child: BlurSurface(
                    tint: palette.albumCardTranslucent,
                    radius: CameoLayout.callCardRadius,
                    padding: const EdgeInsets.symmetric(
                      horizontal: CameoLayout.callCardPaddingX,
                      vertical: CameoLayout.callCardPaddingY,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: CameoLayout.callCardGap,
                      children: [
                        CameoText(
                          'BlurSurface · backgroundBlur',
                          style: CameoTextStyles.bodyLgStrong,
                          color: palette.foregroundNeutralInverseBase,
                        ),
                        CameoText(
                          'callCard r14 · h76',
                          style: CameoTextStyles.bodySm,
                          color: palette.foregroundNeutralInverseMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            _Section(
              label: 'Motion — physics springs (tap)',
              children: [
                for (final MapEntry(key: name, value: spring)
                    in CameoSprings.byName.entries)
                  _SpringRow(name: name, spring: spring),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = CameoTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.all(CameoLayout.highlightCardWrapperPadding),
      child: BlurSurface(
        tint: palette.transcriptDarkCard,
        border: palette.transcriptDarkCardBorder,
        borderWidth: CameoLayout.highlightCardBorderWidth,
        radius: CameoLayout.highlightCardRadius,
        padding: const EdgeInsets.symmetric(
          horizontal: CameoLayout.highlightCardPaddingX,
          vertical: CameoLayout.highlightCardPaddingY,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: CameoLayout.highlightCardGap,
          children: [
            CameoText(
              label,
              style: CameoTextStyles.bodySm,
              color: palette.foregroundNeutralInverseMuted,
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SpringRow extends StatefulWidget {
  const _SpringRow({required this.name, required this.spring});

  final String name;
  final SpringDescription spring;

  @override
  State<_SpringRow> createState() => _SpringRowState();
}

class _SpringRowState extends State<_SpringRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _on = AnimationController.unbounded(
    vsync: this,
  );

  @override
  void dispose() {
    _on.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const thumb = CameoLayout.playerThumbSize;
    final palette = CameoTheme.colorsOf(context);
    final s = widget.spring;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final to = _on.value > 0.5 ? 0.0 : 1.0;

        if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
          _on.value = to;
        } else {
          _on.springTo(to, widget.spring);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CameoSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: CameoSpace.s8,
          children: [
            CameoText(
              '${widget.name}  m${_fmt(s.mass)} k${_fmt(s.stiffness)} c${_fmt(s.damping)}',
              style: CameoTextStyles.bodyMd,
              color: palette.foregroundNeutralInverseMuted,
            ),
            SizedBox(
              height: thumb,
              child: LayoutBuilder(
                builder: (context, c) => AnimatedBuilder(
                  animation: _on,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(_on.value * (c.maxWidth - thumb), 0),
                    child: child,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: thumb,
                      height: thumb,
                      decoration: BoxDecoration(
                        color: palette.surfaceBackgroundNormal,
                        shape: BoxShape.circle,
                        boxShadow: [palette.shadows.shadow],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
