// Regression coverage for design system. Preserve behavior, layout, and interaction
// expectations.

import 'dart:convert';
import 'dart:io';
import 'dart:math' show sqrt;

import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readJson(String relativeToRepo) =>
    jsonDecode(File('../../$relativeToRepo').readAsStringSync())
        as Map<String, dynamic>;

double _num(Object? v) => (v as num).toDouble();

double _lineHeightPx(TextStyle s) => s.fontSize! * s.height!;

Iterable<MapEntry<String, dynamic>> _entries(Map<String, dynamic> m) =>
    m.entries.where((e) => !e.key.startsWith(r'$'));

Color _hex(String value) {
  final hex = value.substring(1);
  final rgb = hex.substring(0, 6);
  final a = hex.length == 8 ? hex.substring(6, 8) : 'FF';
  return Color(int.parse('$a$rgb', radix: 16));
}

Color _roleValue(Map<String, dynamic> role, String mode) {
  final v = role[r'$value'];
  return _hex(v is String ? v : (v as Map<String, dynamic>)[mode] as String);
}

void main() {
  final tokens = _readJson('design-system/tokens.json');

  group('glassStretch — RN 과 공유하는 교차 검증 벡터', () {
    final vectors = _readJson('design-system/tests/glass-stretch.vectors.json');
    final tol = _num(vectors['tolerance']);

    test('벡터 기준 파라미터가 생성 토큰과 같다', () {
      final g = vectors['glass'] as Map<String, dynamic>;
      expect(g['resistance'], CameoMotion.glassResistance);
      expect(g['stretch'], CameoMotion.glassStretch);
      expect(g['stretchMax'], CameoMotion.glassStretchMax);
      expect(g['pressScale'], CameoMotion.glassPressScale);
    });

    for (final c in (vectors['cases'] as List).cast<Map<String, dynamic>>()) {
      final i = c['input'] as Map<String, dynamic>;
      final e = c['expected'] as Map<String, dynamic>;
      test('dx=${i['dx']} dy=${i['dy']} ${i['width']}x${i['height']}', () {
        final s = glassStretch(
          _num(i['dx']),
          _num(i['dy']),
          _num(i['width']),
          _num(i['height']),
        );
        expect(s.tx, closeTo(_num(e['tx']), tol));
        expect(s.ty, closeTo(_num(e['ty']), tol));
        expect(s.sx, closeTo(_num(e['sx']), tol));
        expect(s.sy, closeTo(_num(e['sy']), tol));
      });
    }
  });

  group('색 — Figma 변수 값 (알파·모드)', () {
    final color = tokens['color'] as Map<String, dynamic>;
    final roles = color['roles'] as Map<String, dynamic>;
    const modes = {'light': CameoColors.byRole, 'dark': CameoColorsDark.byRole};

    test('팔레트 확정 — 모든 역할에 값이 있고 placeholder 는 없다', () {
      expect(kCameoColorConfirmed, isTrue);
      expect((color[r'$modes'] as Map).keys, ['light', 'dark']);
      expect(CameoColorMode.values.map((m) => m.name), ['light', 'dark']);
      for (final MapEntry(:key, :value) in roles.entries) {
        final role = value as Map<String, dynamic>;
        expect(role[r'$value'], isNotNull, reason: key);
        expect(role.containsKey(r'$placeholder'), isFalse, reason: key);
      }
    });

    test('CameoColors(light) · CameoColorsDark 는 tokens.json 모드 값과 같다', () {
      for (final MapEntry(key: mode, value: byRole) in modes.entries) {
        expect(byRole.keys.toSet(), roles.keys.toSet(), reason: mode);
        for (final MapEntry(:key, :value) in roles.entries) {
          expect(
            byRole[key],
            _roleValue(value as Map<String, dynamic>, mode),
            reason: '$mode $key',
          );
        }
      }
    });

    test('Figma 값 — light (v5 E2 · v3 이름 역할은 v3 값, v3-plan Q9)', () {
      expect(CameoColors.backgroundCanvasBase, const Color(0xFFF7F7FB));
      expect(CameoColors.backgroundCanvasMuted, const Color(0xFFF6F0EE));
      expect(CameoColors.foregroundNeutralBase, const Color(0xFF030305));
      expect(CameoColors.foregroundNeutralMuted, const Color(0x99030305));
      expect(CameoColors.foregroundNeutralSubtle, const Color(0x4D030305));
      expect(CameoColors.backgroundNeutralBase, const Color(0x0A111621));

      expect(CameoColors.strokeBase, const Color(0x1F121221));
      expect(CameoColors.effectShadow, const Color(0x1F030305));
      expect(CameoColors.effectShadowLegacy, const Color(0x3D121221));

      expect(CameoColors.foregroundInvertedBase, const Color(0xFFF7F7FB));
      expect(CameoColorsDark.foregroundInvertedBase, const Color(0xFF030305));

      expect(CameoColors.foregroundNeutralInverseBase, const Color(0xFFF8F4F2));
      expect(
        CameoColors.foregroundNeutralInverseMuted,
        const Color(0x99F8F4F2),
      );
      expect(CameoColors.strokeNeutralBase, const Color(0x1F957A62));
      expect(CameoColors.backgroundCriticalBase, const Color(0xFFCE3D4A));
      expect(CameoColors.effectShadowBase, const Color(0x2E957A62));
    });

    test('Figma 값 — dark (v5 2176:9241 · 2232:2165 · 기본 세트, E1 · E2)', () {
      expect(CameoColorsDark.backgroundCanvasBase, const Color(0xFF030305));
      expect(CameoColorsDark.foregroundNeutralBase, const Color(0xFFF7F7FB));
      expect(CameoColorsDark.foregroundNeutralMuted, const Color(0x99F7F7FB));
      expect(CameoColorsDark.foregroundNeutralSubtle, const Color(0x4DF7F7FB));
      expect(CameoColorsDark.backgroundNeutralBase, const Color(0x0FF7F7FB));
      expect(CameoColorsDark.backgroundNeutralStrong, const Color(0x1FF7F7FB));
      expect(
        CameoColorsDark.backgroundNeutralInteractive,
        const Color(0x0FF7F7FB),
      );
      expect(
        CameoColorsDark.backgroundSystemCriticalMuted,
        const Color(0x2ECE3D4A),
      );
      expect(CameoColorsDark.strokeBase, const Color(0x1FF7F7FB));

      expect(CameoColorsDark.effectShadow, const Color(0x0AF7F7FB));
      expect(CameoColorsDark.effectShadowLegacy, const Color(0x1FF7F7FB));
      expect(CameoColorsDark.backgroundCanvasDim, const Color(0x99111113));
      expect(
        CameoColorsDark.backgroundNeutralInverted,
        const Color(0xFFF7F7FB),
      );
    });

    test('v5 static/* = 모드 무관 단일 값 (E2)', () {
      const statics = {
        'static/white/base': Color(0xFFF7F7FB),
        'static/white/muted': Color(0x99F7F7FB),
        'static/white/subtle': Color(0x4DF7F7FB),
        'static/black/base': Color(0xFF030305),
      };
      for (final MapEntry(:key, :value) in statics.entries) {
        expect(CameoColors.byRole[key], value, reason: key);
        expect(CameoColorsDark.byRole[key], value, reason: key);
        expect((roles[key] as Map)[r'$value'], isA<String>(), reason: key);
      }
    });

    test('raw 역할 = Figma rgba 그대로 (모드 무관)', () {
      const raw = {
        'glass/tint': Color(0x4D52535D), // rgba(82,83,93,0.3)
        'glass/border': Color(0x26FFFFFF), // rgba(255,255,255,0.15)
        'glass/border-bar': Color(0x1FFFFFFF), // rgba(255,255,255,0.12)
        'album/section-1': Color(0xFF696367),
        'album/section-3': Color(0xFF575A5E),
        'album/hero-fade-start': Color(0x00000000), // rgba(0,0,0,0)
        'media/card': Color(0x66FFFFFF),
        'player/track': Color(0x1A000000),
        'camera/shutter': Color(0x8052535D), // #52535D @ 50%
        'camera/shutter-disc': Color(0xFFD9D9D9),
        'camera/shutter-stroke': Color(0x1F957A62),
        // v5 raw (tokens 0.5.0)
        'album/section-1-clear': Color(0x00696367), // rgba(105,99,103,0)
        'album/section-3-clear': Color(0x00575A5E),
        'control/heart-shadow': Color(0x3D121221), // v6 rgba(18,18,33,0.24)
      };
      for (final MapEntry(:key, :value) in raw.entries) {
        expect(CameoColors.byRole[key], value, reason: key);
        expect(CameoColorsDark.byRole[key], value, reason: key);
        expect((roles[key] as Map)[r'$value'], isA<String>(), reason: key);
      }
    });

    test(r'$modeFallback — 복사된 모드는 원본 모드와 같은 값', () {
      var fallbacks = 0;
      for (final MapEntry(:key, :value) in roles.entries) {
        final fb = (value as Map<String, dynamic>)[r'$modeFallback'] as Map?;
        if (fb == null) continue;
        for (final MapEntry(key: to, value: from) in fb.entries) {
          expect(
            modes[to]![key],
            modes[from]![key],
            reason: '$key $to ← $from',
          );
          fallbacks++;
        }
      }

      for (final r in [
        'background/neutral/strong',
        'background/neutral/interactive',
        'background/system/critical/muted',
        'background/canvas/dim',
        'background/neutral/inverted',
      ]) {
        expect((roles[r] as Map)[r'$modeFallback'], {
          'light': 'dark',
        }, reason: r);
      }

      expect((roles['background/canvas/muted'] as Map)[r'$modeFallback'], {
        'dark': 'light',
      });

      expect(
        (roles['background/neutral/base'] as Map).containsKey(r'$modeFallback'),
        isFalse,
      );
      expect(
        CameoColors.backgroundNeutralBase,
        isNot(CameoColorsDark.backgroundNeutralBase),
      );
      expect(fallbacks, greaterThan(8));
    });

    test('Interactive 코드 키 — Figma 이름은 대문자 I', () {
      final r = roles['background/neutral/interactive'] as Map<String, dynamic>;
      expect(r[r'$figmaVariable'], 'background/neutral/Interactive');
      expect(roles.containsKey('background/neutral/Interactive'), isFalse);
      expect(
        CameoColorsDark.byRole['background/neutral/interactive'],
        CameoColorsDark.backgroundNeutralInteractive,
      );
    });

    test('CameoPalette.of(mode) = 모드별 상수 · 그라데이션 · 그림자', () {
      expect(CameoPalette.of(CameoColorMode.light), same(CameoPalette.light));
      expect(CameoPalette.of(CameoColorMode.dark), same(CameoPalette.dark));
      expect(CameoPalette.light.mode, CameoColorMode.light);
      expect(CameoPalette.dark.mode, CameoColorMode.dark);
      expect(CameoPalette.light.byRole, same(CameoColors.byRole));
      expect(CameoPalette.dark.byRole, same(CameoColorsDark.byRole));
      expect(
        CameoPalette.light.backgroundCanvasBase,
        CameoColors.backgroundCanvasBase,
      );
      expect(
        CameoPalette.dark.backgroundCanvasBase,
        CameoColorsDark.backgroundCanvasBase,
      );
      expect(CameoPalette.dark.foregroundNeutralBase, const Color(0xFFF7F7FB));
      expect(
        CameoPalette.dark.gradients.karaokeV5,
        CameoGradientsDark.karaokeV5,
      );
      expect(CameoPalette.light.shadows.shadowV5, CameoShadows.shadowV5);
      expect(CameoPalette.dark.shadows.shadowV5, CameoShadowsDark.shadowV5);
      expect(CameoPalette.light.gradients.albumHero, CameoGradients.albumHero);
      expect(
        CameoPalette.dark.gradients.karaokeDarkToken,
        CameoGradientsDark.karaokeDarkToken,
      );
      expect(
        CameoPalette.dark.shadows.toastShadow,
        CameoShadowsDark.toastShadow,
      );
      expect(CameoPalette.light.shadows.shadow, CameoShadows.shadow);
    });
  });

  group('타이포그래피', () {
    final typo = tokens['typography'] as Map<String, dynamic>;
    final styles = typo['styles'] as Map<String, dynamic>;
    final weights = typo['fontWeight'] as Map<String, dynamic>;

    test('스타일 키가 정확히 일치한다', () {
      expect(CameoTextStyles.byName.keys.toSet(), styles.keys.toSet());
      expect(
        styles.keys.toSet(),
        containsAll(<String>[
          'headingLg',
          'headingSm',
          'bodyLgStrong',
          'bodyLg',
          'bodyMd',
          'bodySm',
          'bodySmStrong',
          'display',
          'transcriptLine',
          'quote',
          'headingSmStrong',
          'bodyMdMedium',
        ]),
      );
    });

    test('px 행간·자간·weight 가 Figma 값과 일치', () {
      for (final MapEntry(:key, value: s) in styles.entries) {
        final style = CameoTextStyles.byName[key]!;
        final size = _num(s['fontSize']);
        final lh = _num(s['lineHeight']);
        final lineHeightPx = s['lineHeightUnit'] == 'multiplier'
            ? size * lh
            : lh;
        final w = _num((weights[s['fontWeight']] as Map)[r'$value']);
        expect(style.fontSize, size, reason: key);
        expect(
          style.fontSize! * style.height!,
          closeTo(lineHeightPx, 1e-4),
          reason: key,
        );
        expect(
          style.letterSpacing,
          closeTo(size * _num(s['letterSpacingPercent']) / 100, 1e-9),
          reason: key,
        );
        expect(style.fontWeight!.value, w.toInt(), reason: key);

        expect(style.fontVariations, [
          FontVariation('wght', w),
          FontVariation('opsz', size),
        ], reason: key);
        expect(style.leadingDistribution, TextLeadingDistribution.even);
      }
    });

    test(
      'Interlude 가 먼저, 없는 글리프만 weight 별 시스템 폴백 (tokens fontFallback.flutter)',
      () {
        final families = typo['fontFamily'] as Map<String, dynamic>;
        final group = (typo['fontFallback'] as Map)['flutter'] as Map;

        final entryOf = <String, Map>{};
        for (final MapEntry(:key, :value) in group.entries) {
          if ((key as String).startsWith(r'$')) continue;
          for (final w
              in ((value as Map)[r'$weights'] as List).cast<String>()) {
            expect(entryOf.containsKey(w), isFalse, reason: 'weight $w 중복');
            entryOf[w] = value;
          }
        }
        expect(
          entryOf.keys.toSet(),
          weights.keys.where((k) => !k.startsWith(r'$')).toSet(),
        );
        expect(CameoFontFamily.fallbackText, ['CupertinoSystemText']);
        expect(CameoFontFamily.fallbackDisplay, ['CupertinoSystemDisplay']);
        for (final MapEntry(:key, value: s) in styles.entries) {
          final style = CameoTextStyles.byName[key]!;
          final family = (families[s['fontFamily']] as Map)[r'$value'];
          final entry = entryOf[s['fontWeight']]!;
          final fallback = (entry[r'$value'] as List).cast<String>();
          expect(style.fontFamily, family, reason: key);
          expect(style.fontFamilyFallback, fallback, reason: key);
          expect(
            fallback,
            isNot(contains(CameoFontFamily.defaultFamily)),
            reason: key,
          );

          if (s['fontWeight'] == 'regular') {
            expect(
              fallback,
              isNot(contains('CupertinoSystemDisplay')),
              reason: key,
            );
          }
          final below = entry[r'$fontSizeBelow'] as num?;
          if (below != null) {
            expect(style.fontSize, lessThan(below), reason: key);
          }

          final strut = cameoStrutOf(style);
          expect(strut.fontFamily, family, reason: key);
          expect(strut.fontFamilyFallback, fallback, reason: key);
          expect(strut.forceStrutHeight, isTrue, reason: key);
          expect(
            strut.fontSize! * strut.height!,
            closeTo(style.fontSize! * style.height!, 1e-9),
            reason: key,
          );
        }
      },
    );

    test(
      'SF 트래킹 = tokens systemTracking(trak 표)을 스타일 크기로 보간 — units × 크기 / unitsPerEm',
      () {
        final raw = (typo['fontFallback'] as Map)['systemTracking'] as Map?;
        if (raw == null) {
          expect(CameoTextStyles.systemTracking, isEmpty);
          return;
        }
        final upm = _num(raw[r'$unitsPerEm']);
        final points = (raw[r'$value'] as Map).entries
            .map((e) => (double.parse(e.key as String), _num(e.value)))
            .toList();
        double at(double size) {
          if (size <= points.first.$1) return points.first.$2 * size / upm;
          for (var i = 1; i < points.length; i++) {
            final (s1, u1) = points[i];
            if (size > s1) continue;
            final (s0, u0) = points[i - 1];
            return (u0 + (u1 - u0) * (size - s0) / (s1 - s0)) * size / upm;
          }
          return points.last.$2 * size / upm;
        }

        final sizes = CameoTextStyles.byName.values
            .map((s) => s.fontSize!)
            .toSet();
        expect(CameoTextStyles.systemTracking.keys.toSet(), sizes);
        for (final size in sizes) {
          expect(
            CameoTextStyles.systemTracking[size],
            closeTo(at(size), 1e-6),
            reason: '$size',
          );
        }

        expect(CameoTextStyles.systemTracking[12], 0);
        expect(
          CameoTextStyles.systemTracking[14],
          closeTo(-22 * 14 / 2048, 1e-6),
        );
        expect(
          CameoTextStyles.systemTracking[16],
          closeTo(-40 * 16 / 2048, 1e-6),
        );
      },
    );

    group(
      'cameoTextSpan — SF 로 그려지는 글자 run 에만 SF 트래킹',
      () {
        const style = CameoTextStyles.transcriptLine;
        final tracked =
            style.letterSpacing! +
            (CameoTextStyles.systemTracking[style.fontSize] ?? 0);
        double width(InlineSpan s) {
          final p = TextPainter(text: s, textDirection: TextDirection.ltr)
            ..layout();
          final w = p.width;
          p.dispose();
          return w;
        }

        test('한글뿐이면 토큰 스타일 그대로 (CoreText 도 Apple SD Gothic Neo 에 트래킹 없음)', () {
          final span = cameoTextSpan('가나다', style);
          expect(span.children, isNull);
          expect(span.style, style);
        });

        test('라틴·숫자·공백뿐이면 letterSpacing = 토큰 자간 + 트래킹', () {
          final span = cameoTextSpan('Yurim 12:20', style);
          expect(span.children, isNull);
          expect(span.style!.letterSpacing, closeTo(tracked, 1e-9));
          expect(span.style!.fontSize, style.fontSize);

          expect(width(span), closeTo(11 * (style.fontSize! + tracked), 1e-3));
        });

        test('섞이면 run 을 나눈다 — 폭 = 한글 × 토큰 자간 + SF 글자 × (토큰 자간 + 트래킹)', () {
          final span = cameoTextSpan('1시에 서울숲역 4번', style);
          expect(span.style, style);
          expect(span.children!.map((c) => (c as TextSpan).text), [
            '1',
            '시에',
            ' ',
            '서울숲역',
            ' 4',
            '번',
          ]);
          expect(span.children!.map((c) => c.style?.letterSpacing), [
            tracked,
            null,
            tracked,
            null,
            tracked,
            null,
          ]);
          expect(
            width(span),
            closeTo(
              7 * (style.fontSize! + style.letterSpacing!) +
                  4 * (style.fontSize! + tracked),
              1e-3,
            ),
          );
        });

        test('트래킹 0 인 크기(12pt)는 나누지 않는다', () {
          final span = cameoTextSpan('12시 20분', CameoTextStyles.bodySm);
          expect(span.children, isNull);
          expect(span.style, CameoTextStyles.bodySm);
        });
      },

      skip: CameoTextStyles.systemTracking.isEmpty,
    );

    test('Figma weight 3종 (weight/bold = 600 = SemiBold)', () {
      expect(CameoFontWeight.regular, FontWeight.w400);
      expect(CameoFontWeight.medium, FontWeight.w500);
      expect(CameoFontWeight.semibold, FontWeight.w600);
    });
  });

  group('아이콘', () {
    final manifest = _readJson('design-system/icons/manifest.json');
    final icons = (manifest['icons'] as List).cast<Map<String, dynamic>>();

    test('CameoIconName ↔ manifest ↔ 에셋 파일', () {
      expect(
        CameoIconName.values.map((e) => e.key).toSet(),
        icons.map((e) => e['key']).toSet(),
      );
      for (final icon in CameoIconName.values) {
        expect(File(icon.asset).existsSync(), isTrue, reason: icon.asset);
        final m = icons.firstWhere((e) => e['key'] == icon.key);
        expect(icon.cameo, m['provenance'] == 'cameo', reason: icon.key);
      }
    });

    test('cameo 추가 아이콘 = tokens icon.used.\$cameoAdditions', () {
      final used =
          (tokens['icon'] as Map<String, dynamic>)['used']
              as Map<String, dynamic>;
      final additions = (used[r'$cameoAdditions'] as List).cast<String>().map((
        a,
      ) {
        final [variant, slug] = a.split('/');
        return variant == 'filled' ? '$slug-filled' : slug;
      }).toSet();
      expect(
        CameoIconName.values.where((e) => e.cameo).map((e) => e.key).toSet(),
        additions,
      );
      expect(
        additions,
        containsAll(['player-play-filled', 'circle-check-filled']),
      );

      expect(
        additions.intersection({'backspace', 'copy', 'check', 'chevron-right'}),
        isEmpty,
      );
    });

    test('크기 22 / 18 / 14 / 12', () {
      expect(CameoIconTokens.sizeMd, 22);
      expect(CameoIconTokens.sizeSm, 18);
      expect(CameoIconTokens.sizeXs, 14);
      expect(CameoIconTokens.sizeXxs, 12);
      expect(CameoIconTokens.strokeWidth, 1.5);
    });
  });

  group('이펙트', () {
    final effect = tokens['effect'] as Map<String, dynamic>;

    test('블러 σ = Figma radius / 2', () {
      for (final b in CameoBlur.values) {
        final e = effect[b.name] as Map<String, dynamic>;
        expect(b.sigma, _num(e['blurRadius']) / 2, reason: b.name);
      }
      expect(CameoBlur.backgroundBlur.sigma, 2.5);
      expect(CameoBlur.backgroundBlurStrong.sigma, 10);
      expect(CameoBlur.pauseButtonBlur.sigma, 10);
      expect(CameoBlur.glassNav.sigma, 6);
      expect(CameoBlur.glassBar.sigma, 10);
      expect(CameoBlur.glassTabBar.sigma, 10);
      // v5: background-blur r5 (call-list) · v6 scrim · blur r12
      expect(CameoBlur.backgroundBlurV5Card.sigma, 2.5);
      expect(CameoBlur.scrim.sigma, 6);
      expect(CameoBlur.blur.sigma, 6);
      expect(CameoBlur.shadowV5.sigma, 10);
    });

    test(
      '블러 렌더 재질 = tokens.json material — v3-plan G1 (떠 있는 컨트롤 glass · 카드/안쪽 요소 blur)',
      () {
        for (final b in CameoBlur.values) {
          final e = effect[b.name] as Map<String, dynamic>;
          expect(b.material.name, e['material'], reason: b.name);
          final figmaGlass = RegExp(
            r'\bGLASS\b',
          ).hasMatch('${e[r'$figmaEffects'] ?? ''}');
          final g1 = RegExp(
            r'\bG1\b',
          ).hasMatch('${e[r'$materialDecision'] ?? ''}');

          if (figmaGlass) {
            expect(b.material, CameoBlurMaterial.glass, reason: b.name);
          }
          if (b.material == CameoBlurMaterial.glass && !figmaGlass) {
            expect(g1, isTrue, reason: b.name);
          }
        }

        for (final b in [
          CameoBlur.glassNav,
          CameoBlur.glassBar,
          CameoBlur.glassTabBar,
          CameoBlur.glassFigma,
          CameoBlur.scrim,
        ]) {
          expect(b.material, CameoBlurMaterial.glass, reason: b.name);
        }

        for (final b in [
          CameoBlur.backgroundBlur,
          CameoBlur.backgroundBlurStrong,
          CameoBlur.pauseButtonBlur,
          CameoBlur.overlay,

          CameoBlur.backgroundBlurV5Card,
          CameoBlur.shadowV5,
          CameoBlur.blur,
        ]) {
          expect(b.material, CameoBlurMaterial.blur, reason: b.name);
        }
      },
    );

    test('Liquid Glass 파라미터 = tokens.json effect.liquidGlass', () {
      final lg = effect['liquidGlass'] as Map<String, dynamic>;
      final r = lg['renderer'] as Map<String, dynamic>;
      expect(CameoEffects.liquidGlassRendererThickness, _num(r['thickness']));
      expect(
        CameoEffects.liquidGlassRendererBlurSigmaScale,
        _num(r['blurSigmaScale']),
      );
      expect(
        CameoEffects.liquidGlassRendererLightIntensityDarkBackdrop,
        _num(r['lightIntensityDarkBackdrop']),
      );
      final n = lg['native'] as Map<String, dynamic>;

      for (final role in [
        n['compensationRole'] as String,
        n['compensationDarkBackdropRole'] as String,
      ]) {
        expect(CameoColors.byRole[role], isNotNull, reason: role);
        expect(CameoColorsDark.byRole[role], CameoColors.byRole[role]);
      }
      expect(
        GlassBackdropTone.fromToken(
          CameoEffects.liquidGlassBackdropCameraScreen,
        ),
        GlassBackdropTone.dark,
      );
    });

    test('Flutter BoxShadow σ 가 Figma/CSS 그림자 σ(= radius / 2)와 같다', () {
      final cases = <String, (BoxShadow, Map<String, dynamic>)>{
        'shadow': (CameoShadows.shadow, effect['shadow']),
        'toastShadow': (CameoShadows.toastShadow, effect['toastShadow']),
        'overlay': (
          CameoShadows.overlay,
          (effect['overlay'] as Map<String, dynamic>)['shadow'],
        ),
        'shadowV5': (
          CameoShadows.shadowV5,
          (effect['shadowV5'] as Map<String, dynamic>)['shadow'],
        ),
        'heartShadow': (CameoShadows.heartShadow, effect['heartShadow']),
      };
      for (final MapEntry(:key, value: (shadow, spec)) in cases.entries) {
        expect(
          shadow.blurSigma,
          closeTo(_num(spec['blurRadius']) / 2, 1e-4),
          reason: key,
        );
        expect(shadow.offset.dx, _num(spec['offsetX']), reason: key);
        expect(shadow.offset.dy, _num(spec['offsetY']), reason: key);
        expect(shadow.spreadRadius, _num(spec['spread']), reason: key);
      }
    });
  });

  group('그라데이션', () {
    final gradients = tokens['gradient'] as Map<String, dynamic>;
    final generated = <String, LinearGradient>{
      'albumHero': CameoGradients.albumHero,
      'albumHeroSection3': CameoGradients.albumHeroSection3,
      'albumHeroGangneung': CameoGradients.albumHeroGangneung,
      'callBackground': CameoGradients.callBackground,
      'transcriptDarkBackground': CameoGradients.transcriptDarkBackground,
      'scrollEdgeTop': CameoGradients.scrollEdgeTop,
      'albumHeroV5': CameoGradients.albumHeroV5,
      'albumHeroV5Section2': CameoGradients.albumHeroV5Section2,
      // v6 (tokens 0.6.0)
      'topLinear': CameoGradients.topLinear,
      'bottomLinear': CameoGradients.bottomLinear,
      'sectionFadeTopV6': CameoGradients.sectionFadeTopV6,
      'sectionFadeBottomV6': CameoGradients.sectionFadeBottomV6,
      'albumHeroV6': CameoGradients.albumHeroV6,
      'callBackgroundV6': CameoGradients.callBackgroundV6,
      'cameraNavFadeV6': CameoGradients.cameraNavFadeV6,
      'welcomeFadeV6': CameoGradients.welcomeFadeV6,
    };

    final generatedDark = <String, LinearGradient>{
      'albumHero': CameoGradientsDark.albumHero,
      'albumHeroSection3': CameoGradientsDark.albumHeroSection3,
      'albumHeroGangneung': CameoGradientsDark.albumHeroGangneung,
      'callBackground': CameoGradientsDark.callBackground,
      'transcriptDarkBackground': CameoGradientsDark.transcriptDarkBackground,
      'scrollEdgeTop': CameoGradientsDark.scrollEdgeTop,
      'albumHeroV5': CameoGradientsDark.albumHeroV5,
      'albumHeroV5Section2': CameoGradientsDark.albumHeroV5Section2,
      // v6 (tokens 0.6.0)
      'topLinear': CameoGradientsDark.topLinear,
      'bottomLinear': CameoGradientsDark.bottomLinear,
      'sectionFadeTopV6': CameoGradientsDark.sectionFadeTopV6,
      'sectionFadeBottomV6': CameoGradientsDark.sectionFadeBottomV6,
      'albumHeroV6': CameoGradientsDark.albumHeroV6,
      'callBackgroundV6': CameoGradientsDark.callBackgroundV6,
      'cameraNavFadeV6': CameoGradientsDark.cameraNavFadeV6,
      'welcomeFadeV6': CameoGradientsDark.welcomeFadeV6,
    };

    test('stop 위치는 Figma 값, 색은 역할 (모드별)', () {
      final fills = _entries(
        gradients,
      ).where((e) => (e.value as Map).containsKey('stops'));
      expect(generated.keys.toSet(), fills.map((e) => e.key).toSet());
      for (final MapEntry(:key, value: g) in fills) {
        final stops = (g['stops'] as List).cast<Map<String, dynamic>>();
        for (final (lg, byRole) in [
          (generated[key]!, CameoColors.byRole),
          (generatedDark[key]!, CameoColorsDark.byRole),
        ]) {
          expect(lg.stops, stops.map((s) => _num(s['position'])), reason: key);
          expect(lg.colors, stops.map((s) => byRole[s['color']]), reason: key);
        }
      }

      expect(CameoGradients.albumHero.colors.first, const Color(0x00000000));
      expect(
        CameoGradients.callBackground.colors.first,
        const Color(0x00FFFFFF),
      );
    });

    test('카라오케 fadeStart · karaokeDarkToken (v3-plan Q5)', () {
      expect(CameoGradients.karaokeLight.fadeStart, 0.60577);
      expect(CameoGradients.karaokeDark.fadeStart, 0.60577);
      expect(CameoGradients.karaokeQuote.fadeStart, 0.46635);
      const k = CameoGradientsDark.karaokeDarkToken;
      expect(k.fadeStart, 0.60577);
      expect(k.fadeEnd, 1);
      expect(k.ink, CameoColorsDark.foregroundNeutralBase);
      expect(k.base, CameoColorsDark.foregroundNeutralSubtle);

      const v5 = CameoGradientsDark.karaokeV5;
      expect(v5.fadeStart, 0);
      expect(v5.fadeEnd, 1);
      expect(v5.ink, CameoColorsDark.foregroundNeutralBase);
      expect(v5.base, CameoColorsDark.foregroundNeutralSubtle);
    });
  });

  group('레이아웃 — Figma border-box 합계 검증', () {
    test('내비 56 / 46 / 50', () {
      expect(
        CameoLayout.navBarCircleButtonSize,
        CameoLayout.navBarCircleButtonBorderWidth * 2 +
            CameoLayout.navBarCircleButtonPadding * 2 +
            CameoLayout.navBarCircleButtonIconSize,
      );
      expect(
        CameoLayout.navBarActionPillWidth,
        CameoLayout.navBarActionPillBorderWidth * 2 +
            CameoLayout.navBarActionPillPadding * 2 +
            CameoLayout.navBarActionItemSize * 2 +
            CameoLayout.navBarActionPillGap,
      );
      expect(
        CameoLayout.navBarActionPillHeight,
        CameoLayout.navBarActionPillBorderWidth * 2 +
            CameoLayout.navBarActionPillPadding * 2 +
            CameoLayout.navBarActionItemSize,
      );
      expect(
        CameoLayout.navBarActionItemSize,
        CameoLayout.navBarActionItemPadding * 2 +
            CameoLayout.navBarActionItemIconSize,
      );
      expect(
        CameoLayout.navBarCompactActionPillWidth,
        CameoLayout.navBarCompactActionItemSize * 2,
      );
      expect(
        CameoLayout.navBarV1Height,
        CameoLayout.navBarV1PaddingY * 2 + CameoLayout.navBarV1CircleButtonSize,
      );
      expect(
        CameoLayout.screenTopAreaHeight,
        CameoLayout.screenStatusBarHeight + CameoLayout.navBarHeight,
      );
    });

    test('v3 테두리 없는 내비 54 / 104 · 상단 영역 116', () {
      expect(
        CameoLayout.navBarBorderlessCircleButtonSize,
        CameoLayout.navBarBorderlessCircleButtonPadding * 2 +
            CameoLayout.navBarBorderlessCircleButtonIconSize,
      );
      expect(CameoLayout.navBarBorderlessCircleButtonBorderWidth, 0);
      expect(
        CameoLayout.navBarBorderlessActionPillWidth,
        CameoLayout.navBarBorderlessActionPillPadding * 2 +
            CameoLayout.navBarBorderlessActionItemSize * 2 +
            CameoLayout.navBarBorderlessActionPillGap,
      );
      expect(
        CameoLayout.navBarBorderlessActionPillHeight,
        CameoLayout.navBarBorderlessActionPillPadding * 2 +
            CameoLayout.navBarBorderlessActionItemSize,
      );
      expect(
        CameoLayout.navBarBorderlessTopAreaHeight,
        CameoLayout.screenStatusBarHeight + CameoLayout.navBarBorderlessHeight,
      );
      expect(CameoLayout.navBarBorderlessTopAreaHeight, 116);
    });

    test('v3 플레이어 58 / 110 · 하이라이트 카드 377 x 272', () {
      expect(
        CameoLayout.playerV3PillHeight,
        CameoLayout.playerV3PillPadding * 2 + CameoLayout.playerV3ButtonHeight,
      );
      expect(
        CameoLayout.playerV3ContainerHeight,
        CameoLayout.playerV3ContainerPaddingTop +
            CameoLayout.playerV3PillHeight +
            CameoLayout.playerV3ContainerPaddingBottom,
      );
      const pillWidth =
          CameoLayout.screenWidth - CameoLayout.playerV3ContainerPaddingX * 2;
      expect(
        CameoLayout.playerV3ScrubberWidth,
        pillWidth -
            CameoLayout.playerV3PillPadding * 2 -
            CameoLayout.playerV3ButtonWidth,
      );
      expect(
        CameoLayout.playerV3ButtonLeft,
        CameoLayout.playerV3ScrubberLeft + CameoLayout.playerV3ScrubberWidth,
      );
      expect(
        CameoLayout.playerV3ScrubberTop,
        (CameoLayout.playerV3PillHeight - CameoLayout.playerV3ScrubberHeight) /
            2,
      );
      expect(CameoLayout.playerV3TrackWidth, 157);
      expect(
        CameoLayout.highlightCardV3WrapperHeight,
        CameoLayout.highlightCardV3WrapperPadding * 2 +
            CameoLayout.highlightCardV3Height,
      );
      expect(
        CameoLayout.highlightCardV3Width,
        CameoLayout.screenWidth - CameoLayout.highlightCardV3WrapperPadding * 2,
      );
      expect(
        CameoLayout.highlightCardV3TextWidth,
        CameoLayout.highlightCardV3Width -
            CameoLayout.highlightCardV3PaddingX * 2,
      );
      expect(CameoLayout.highlightCardV3BorderWidth, 0);
    });

    test('카메라 16-14 · 세그먼트 컨트롤', () {
      expect(
        CameoLayout.cameraScreenViewfinderWrapperHeight,
        CameoLayout.cameraScreenViewfinderPaddingY * 2 +
            CameoLayout.cameraScreenViewfinderHeight,
      );
      expect(
        CameoLayout.cameraScreenViewfinderWidth /
            CameoLayout.cameraScreenViewfinderHeight,
        CameoLayout.cameraScreenViewfinderAspectRatio,
      );
      expect(
        CameoLayout.cameraScreenViewfinderTop +
            CameoLayout.cameraScreenViewfinderWrapperHeight,
        CameoLayout.cameraScreenShutterRowTop,
      );
      expect(
        CameoLayout.cameraScreenShutterRowTop +
            CameoLayout.cameraScreenShutterRowHeight,
        CameoLayout.cameraScreenBottomBarTop,
      );
      expect(
        CameoLayout.cameraScreenBottomBarTop +
            CameoLayout.cameraScreenBottomBarHeight,
        CameoLayout.screenHeight,
      );
      expect(
        CameoLayout.cameraScreenBottomBarHeight,
        CameoLayout.cameraScreenBottomBarPaddingTop +
            CameoLayout.cameraScreenGlassButtonSize +
            CameoLayout.cameraScreenBottomBarPaddingBottom,
      );
      expect(
        CameoLayout.cameraScreenShutterSize,
        CameoLayout.cameraScreenShutterDiscSize +
            CameoLayout.cameraScreenShutterDiscInset * 2,
      );
      expect(
        CameoLayout.cameraScreenGlassButtonSize,
        CameoLayout.cameraScreenGlassButtonBorderWidth * 2 +
            CameoLayout.cameraScreenGlassButtonPadding * 2 +
            CameoLayout.cameraScreenGlassButtonIconSize,
      );
      expect(
        CameoLayout.segmentedControlWidth,
        CameoLayout.segmentedControlBorderWidth * 2 +
            CameoLayout.segmentedControlPadding * 2 +
            CameoLayout.segmentedControlSegmentWidth * 2 +
            CameoLayout.segmentedControlGap,
      );
      expect(
        CameoLayout.segmentedControlHeight,
        CameoLayout.segmentedControlBorderWidth * 2 +
            CameoLayout.segmentedControlPadding * 2 +
            CameoLayout.segmentedControlSegmentHeight,
      );
      expect(
        CameoLayout.segmentedControlSegmentHeight,
        CameoLayout.segmentedControlSegmentPadding * 2 +
            CameoLayout.segmentedControlLabelHeight,
      );

      expect(
        (CameoLayout.screenWidth - CameoLayout.segmentedControlWidth) / 2 +
            CameoLayout.segmentedControlOffsetX,
        117,
      );
    });

    test('플레이어 · 통화 컨트롤 바 · 토스트', () {
      expect(
        CameoLayout.playerPillHeight,
        CameoLayout.playerPillBorderWidth * 2 +
            CameoLayout.playerPillPadding * 2 +
            CameoLayout.playerButtonHeight,
      );
      expect(
        CameoLayout.playerContainerHeight,
        CameoLayout.playerContainerPaddingTop +
            CameoLayout.playerPillHeight +
            CameoLayout.playerContainerPaddingBottom,
      );
      expect(
        CameoLayout.callControlBarBarHeight,
        CameoLayout.callControlBarBarBorderWidth * 2 +
            CameoLayout.callControlBarBarPadding * 2 +
            CameoLayout.callControlBarButtonHeight,
      );
      expect(
        CameoLayout.callControlBarV1ContainerHeight,
        CameoLayout.callControlBarV1ContainerPaddingTop +
            CameoLayout.callControlBarV1BarHeight +
            CameoLayout.callControlBarV1ContainerPaddingBottom,
      );
      expect(
        CameoLayout.toastPillHeight,
        closeTo(
          CameoLayout.toastPillBorderWidth * 2 +
              CameoLayout.toastPillPaddingY * 2 +
              _lineHeightPx(CameoTextStyles.bodyMd),
          1e-4,
        ),
      );

      expect(
        CameoLayout.toastFigmaTop + CameoLayout.toastContainerHeight,
        CameoLayout.screenHeight - CameoLayout.callControlBarContainerHeight,
      );
    });

    test('발신자 블록은 상단 영역 바로 아래', () {
      final top =
          CameoLayout.screenHeight -
          CameoLayout.callerBlockFigmaBottom -
          CameoLayout.callerBlockHeight;
      expect(top, closeTo(CameoLayout.screenTopAreaHeight, 0.5));
    });

    test('미디어 카드 디텐트 16:9 · 4:3 · 1:1, 컨트롤 바 위에 하단 고정', () {
      expect(CameoLayout.mediaCardAspectDetents, [16 / 9, 4 / 3, 1]);
      const width =
          CameoLayout.screenWidth - CameoLayout.mediaCardContainerPadding * 2;
      for (var i = 0; i < 3; i++) {
        final bottom =
            CameoLayout.mediaCardSampleContainerTops[i] +
            CameoLayout.mediaCardContainerPadding * 2 +
            width / CameoLayout.mediaCardAspectDetents[i];
        expect(
          bottom,
          closeTo(
            CameoLayout.screenHeight -
                CameoLayout.callControlBarContainerHeight,
            0.5,
          ),
        );
      }
    });

    test('통화 카드 · 사진 그리드 · 텍스트 헤더', () {
      expect(
        CameoLayout.callCardHeight,
        CameoLayout.callCardPaddingY * 2 +
            CameoLayout.callCardHeaderHeight +
            CameoLayout.callCardGap +
            CameoLayout.callCardSubtitleHeight,
      );
      expect(
        CameoLayout.photoGridCellSize,
        closeTo(
          (CameoLayout.screenWidth -
                  CameoLayout.photoGridPadding * 2 -
                  CameoLayout.photoGridGap *
                      (CameoLayout.photoGridColumns - 1)) /
              CameoLayout.photoGridColumns,
          1e-9,
        ),
      );
      expect(
        CameoLayout.photoGridGangneungCellSize,
        closeTo(
          (CameoLayout.screenWidth -
                  CameoLayout.photoGridGangneungPadding * 2 -
                  CameoLayout.photoGridGangneungGap *
                      (CameoLayout.photoGridColumns - 1)) /
              CameoLayout.photoGridColumns,
          1e-9,
        ),
      );
      expect(
        CameoLayout.spacerHeight,
        closeTo(
          CameoLayout.photoGridPadding * 2 + CameoLayout.photoGridCellSize,
          1e-9,
        ),
      );
      expect(
        CameoLayout.textHeaderHeight,
        closeTo(
          CameoLayout.textHeaderPaddingTop +
              _lineHeightPx(CameoTextStyles.headingLg) +
              CameoLayout.textHeaderGap +
              CameoLayout.metaRowHeight +
              CameoLayout.textHeaderPaddingBottom,
          1e-4,
        ),
      );
      expect(
        CameoLayout.tabBarContainerHeight,
        CameoLayout.tabBarContainerPaddingTop +
            CameoLayout.tabBarPillHeight +
            CameoLayout.tabBarContainerPaddingBottom,
      );
    });
  });

  group('레이아웃 v5 — Figma 합계 검증 (reference/figma-v5 spec)', () {
    test('header 92', () {
      expect(
        CameoLayout.sectionHeaderHeight,
        closeTo(
          CameoLayout.sectionHeaderPadding * 2 +
              _lineHeightPx(CameoTextStyles.headingLg) +
              CameoLayout.sectionHeaderGap +
              _lineHeightPx(CameoTextStyles.bodyMd),
          1e-4,
        ),
      );
    });

    test('통화 · 카메라 · 보기 기하', () {
      expect(
        CameoLayout.callV5TopAreaHeight,
        CameoLayout.screenStatusBarHeight + CameoLayout.callV5NavHeight,
      );
      expect(
        CameoLayout.callV5NavHeight,
        CameoLayout.callV5NavPadding * 2 + CameoLayout.callV5NavButtonSize,
      );
      expect(
        CameoLayout.callV5CallerBottom,
        closeTo(
          CameoLayout.callV5CallerTop +
              CameoLayout.callV5CallerNameHeight +
              CameoLayout.callV5CallerTimerHeight,
          1e-9,
        ),
      );
      expect(
        CameoLayout.callV5CallerNameHeight,
        closeTo(_lineHeightPx(CameoTextStyles.display), 1e-4),
      );

      expect(
        CameoLayout.cameraV5ViewfinderWidth,
        CameoLayout.screenWidth - CameoLayout.cameraV5PaddingX * 2,
      );
      expect(
        CameoLayout.cameraV5ViewfinderHeight,
        closeTo(CameoLayout.cameraV5ViewfinderWidth * 16 / 9, 0.01),
      );
      expect(
        CameoLayout.cameraV5ViewfinderTop,
        closeTo(
          CameoLayout.cameraV5RowTop +
              (CameoLayout.cameraV5RowHeight -
                      CameoLayout.cameraV5ViewfinderHeight) /
                  2,
          0.01,
        ),
      );
      expect(
        CameoLayout.cameraV5RowTop + CameoLayout.cameraV5RowHeight,
        CameoLayout.callV5MediaBottom,
      );
      expect(
        CameoLayout.viewerCardHeight,
        CameoLayout.cameraV5ViewfinderHeight,
      );
      expect(CameoLayout.viewerCardTop, CameoLayout.cameraV5ViewfinderTop);
    });

    test('앨범 v5 셀 73.8 · 2×2 · 통화만 헤더 124', () {
      expect(
        CameoLayout.albumV5GridCellSize,
        closeTo(
          (CameoLayout.screenWidth -
                  CameoLayout.albumV5GridPadding * 2 -
                  CameoLayout.albumV5GridGap *
                      (CameoLayout.albumV5GridColumns - 1)) /
              CameoLayout.albumV5GridColumns,
          1e-9,
        ),
      );
      expect(
        CameoLayout.albumV5FeaturedWidth,
        closeTo(
          CameoLayout.albumV5GridCellSize * 2 + CameoLayout.albumV5GridGap,
          1e-9,
        ),
      );
      expect(
        CameoLayout.albumV5CallsOnlyHeaderHeight,
        closeTo(
          CameoLayout.albumV5CallsOnlyHeaderPaddingTop +
              _lineHeightPx(CameoTextStyles.headingLg) +
              CameoLayout.albumV5CallsOnlyHeaderGap +
              CameoLayout.albumV5MetaHeight +
              CameoLayout.albumV5CallsOnlyHeaderPaddingBottom,
          1e-4,
        ),
      );
      expect(
        CameoLayout.albumV5NavPillLeft + CameoLayout.albumV5NavPillWidth,
        CameoLayout.screenWidth - CameoLayout.albumV5NavPadding,
      );
      expect(
        CameoLayout.albumV5SampleContentHeight,
        closeTo(
          CameoLayout.albumV5SampleSection1Height +
              CameoLayout.albumV5SampleCallsOnlyHeight +
              CameoLayout.albumV5SampleSection2Height,
          1e-9,
        ),
      );

      expect(
        CameoLayout.albumV5SampleSection2Height,
        closeTo(
          CameoLayout.albumV5HeroSize +
              CameoLayout.albumV5PhotosOnlyFewPaddingTop +
              CameoLayout.albumV5GridCellSize +
              CameoLayout.albumV5PhotosOnlyFewPaddingBottom,
          1e-9,
        ),
      );
    });
  });

  group('모션', () {
    final motion = tokens['motion'] as Map<String, dynamic>;
    final springs = motion['spring'] as Map<String, dynamic>;

    test('스프링: 물리 파라미터와 감쇠비', () {
      expect(CameoSprings.byName.keys.toSet(), springs.keys.toSet());
      for (final MapEntry(:key, value: s) in springs.entries) {
        final d = CameoSprings.byName[key]!;
        expect(d.mass, s['mass'], reason: key);
        expect(d.stiffness, s['stiffness'], reason: key);
        expect(d.damping, s['damping'], reason: key);
        expect(
          d.damping / (2 * sqrt(d.stiffness * d.mass)),
          closeTo(_num(s['dampingRatio']), 1e-3),
          reason: '$key dampingRatio',
        );
      }
    });

    test('스프링은 유한 시간 안에 정지한다 (tolerance 기준)', () {
      for (final d in CameoSprings.byName.values) {
        final sim = SpringSimulation(
          d,
          0,
          1,
          0,
          tolerance: cameoSpringTolerance,
        );
        expect(sim.isDone(3), isTrue);
      }
    });

    test('cameo 모션 값 (plan §4)', () {
      expect(CameoMotion.transitionPushParallax, 0.3);
      expect(CameoMotion.transitionPushSpring, CameoSprings.smooth);
      expect(CameoMotion.toastVisible, const Duration(milliseconds: 2400));
      expect(CameoMotion.heroParallax, 0.5);
      expect(CameoMotion.scrubberThumbGrabScale, 1.15);
      expect(CameoMotion.staggerItem, const Duration(milliseconds: 40));
    });

    test('v5 cameo 모션 (docs/v5-plan.md E6 · E7 · E10 · E11 · E13)', () {
      final m = motion;
      int ms(String group, String key) =>
          ((m[group] as Map)[key] as num).toInt();
      expect(
        CameoMotion.sleepVolumeFade,
        Duration(milliseconds: ms('sleep', 'volumeFadeMs')),
      );
      expect(
        CameoMotion.sleepAod,
        Duration(milliseconds: ms('sleep', 'aodMs')),
      );
      expect(
        CameoMotion.sliderIdleHide,
        Duration(milliseconds: ms('slider', 'idleHideMs')),
      );
      expect(
        CameoMotion.shotHold,
        Duration(milliseconds: ms('shot', 'holdMs')),
      );
      expect(
        CameoMotion.shotMaxRecord,
        Duration(milliseconds: ms('shot', 'maxRecordMs')),
      );
      expect(
        CameoMotion.instantPartnerDelay,
        Duration(milliseconds: ms('instant', 'partnerDelayMs')),
      );
      expect(CameoMotion.capturedCardEnterSpring, CameoSprings.chewy);
      expect(CameoMotion.albumHeroEnterDim, CameoColors.staticBlackBase);
      expect(CameoMotion.albumHeroEnterScale, greaterThan(1));
      expect(CameoMotion.viewerZoomSpring, CameoSprings.smooth);
      expect(
        CameoMotion.photoSheetDismissProgress,
        CameoMotion.sheetDismissProgress,
      );
      for (final g in [
        'sleep',
        'slider',
        'shot',
        'instant',
        'capturedCard',
        'album',
        'viewer',
        'selectMode',
        'photoSheet',
        'emptyAlbum',
      ]) {
        expect((m[g] as Map)[r'$provenance'], 'cameo', reason: g);
        expect((m[g] as Map)[r'$note'], isA<String>(), reason: g);
      }
    });

    test('tabIndicatorStretch — 면적 보존, 최대 stretchMax', () {
      expect(tabIndicatorStretch(0), (sx: 1.0, sy: 1.0));
      final s = tabIndicatorStretch(-500);
      expect(s.sx * s.sy, closeTo(1, 1e-12));
      expect(
        s.sx,
        closeTo(1 + 500 * CameoMotion.tabIndicatorStretchPerVelocity, 1e-12),
      );
      expect(tabIndicatorStretch(1e9).sx, CameoMotion.tabIndicatorStretchMax);
    });
  });
}
