// Regression coverage for cameo theme. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/call_history_card.dart';
import 'package:cameo/components/title_block.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(Widget child, {CameoColorMode? mode}) {
  final body = MediaQuery(
    data: const MediaQueryData(size: Size(393, 852)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 393, child: child),
      ),
    ),
  );
  return mode == null ? body : CameoTheme(mode: mode, child: body);
}

class _Probe extends StatelessWidget {
  const _Probe(this.onBuild);

  final void Function(CameoPalette palette, CameoColorMode mode) onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild(CameoTheme.colorsOf(context), CameoTheme.modeOf(context));
    return const SizedBox.shrink();
  }
}

Color? _renderedTextColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  group('CameoPalette', () {
    test('light 팔레트 == CameoColors (기존 상수) · dark == CameoColorsDark', () {
      expect(CameoPalette.light.byRole, CameoColors.byRole);
      expect(CameoPalette.dark.byRole, CameoColorsDark.byRole);
      expect(CameoPalette.of(CameoColorMode.light), same(CameoPalette.light));
      expect(CameoPalette.of(CameoColorMode.dark), same(CameoPalette.dark));
      expect(
        CameoPalette.light.foregroundNeutralBase,
        CameoColors.foregroundNeutralBase,
      );
      expect(
        CameoPalette.dark.foregroundNeutralBase,
        CameoColorsDark.foregroundNeutralBase,
      );
      expect(CameoPalette.light.gradients, same(CameoGradientSet.light));
      expect(CameoPalette.dark.shadows, same(CameoShadowSet.dark));
    });
  });

  group('CameoTheme', () {
    testWidgets('CameoTheme 가 없으면 light', (tester) async {
      late CameoPalette palette;
      late CameoColorMode mode;
      await tester.pumpWidget(
        _harness(
          _Probe((p, m) {
            palette = p;
            mode = m;
          }),
        ),
      );
      expect(mode, CameoColorMode.light);
      expect(palette, same(CameoPalette.light));
    });

    testWidgets('가장 가까운 CameoTheme 가 이긴다 (중첩)', (tester) async {
      final seen = <CameoColorMode>[];
      await tester.pumpWidget(
        _harness(
          mode: CameoColorMode.light,
          Column(
            children: [
              _Probe((_, m) => seen.add(m)),
              CameoTheme(
                mode: CameoColorMode.dark,
                child: _Probe((_, m) => seen.add(m)),
              ),
            ],
          ),
        ),
      );
      expect(seen, [CameoColorMode.light, CameoColorMode.dark]);
    });

    testWidgets('모드가 바뀌면 의존 위젯이 다시 빌드된다', (tester) async {
      final seen = <CameoColorMode>[];
      Widget app(CameoColorMode mode) =>
          _harness(mode: mode, _Probe((_, m) => seen.add(m)));
      await tester.pumpWidget(app(CameoColorMode.light));
      await tester.pumpWidget(app(CameoColorMode.dark));
      expect(seen, [CameoColorMode.light, CameoColorMode.dark]);
    });
  });

  group('프리미티브·컴포넌트는 현재 모드로 색을 해석한다', () {
    testWidgets('CameoText 기본색 = 현재 모드의 foreground/neutral/base', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const CameoText('라이트', style: CameoTextStyles.bodyMd)),
      );
      expect(
        _renderedTextColor(tester, '라이트'),
        CameoColors.foregroundNeutralBase,
      );

      await tester.pumpWidget(
        _harness(
          mode: CameoColorMode.dark,
          const CameoText('다크', style: CameoTextStyles.bodyMd),
        ),
      );
      expect(
        _renderedTextColor(tester, '다크'),
        CameoColorsDark.foregroundNeutralBase,
      );
    });

    testWidgets('TitleBlock(light 톤) — dark 모드에서 제목/날짜 = dark 값', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          mode: CameoColorMode.dark,
          const TitleBlock(title: '제목', subtitle: '날짜'),
        ),
      );
      final title = tester.widget<Text>(find.byType(Text).at(0));
      final date = tester.widget<Text>(find.byType(Text).at(1));
      expect(title.style?.color, CameoColorsDark.foregroundNeutralBase);
      expect(date.style?.color, CameoColorsDark.foregroundNeutralMuted);
    });

    testWidgets('CallHistoryCard(light 톤) — light 모드 값은 기존 상수와 같다', (
      tester,
    ) async {
      final card = labAlbumDay.sections
          .expand((s) => s.callCards)
          .firstWhere((c) => c.direction != CallDirection.missed);
      await tester.pumpWidget(
        _harness(CallHistoryCard(card: card, tone: CallHistoryCardTone.light)),
      );
      final surface = tester.widget<GlassSurface>(find.byType(GlassSurface));
      expect(surface.tint, CameoColors.backgroundNeutralSubtle);
    });
  });
}
