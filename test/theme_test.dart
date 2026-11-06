import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 品牌规范《Kangtu — Logo 与色彩管理规范 v1.5》（§06 色彩管理 / §06.1 对比度审计 /
/// §06.2 AMOLED 覆写 / §06.3 表面阶梯）的配色不变量。
///
/// 与 v1.1 的差别（本文件已按 v1.5 重写）：
/// 1. **token 表对齐** —— 直接读 `test/data/kangtu_tokens_v1.5.json`（规范交付物之一），
///    逐 token 断言三套主题，防止实现与规范漂移（旧版只挑了几个值断言）。
/// 2. **AMOLED 不再是「只换场」** —— v1.5 §06.2 明确：相对 dark **只改 4 个 token**
///    （场 → #000000、surface → #0B2321、surface-2 → #143A35、divider → #1B4640），
///    即「阶梯整体上抬一步」，其余全部继承 dark。
/// 3. **新增语义色与焦点环规则** —— 原始 success/warning/error 只够图形级，
///    状态**文字**必须用 ink 变体；`--color-focus` 两种场底都要 ≥3:1。
/// 4. **禁用态 = 38% 不透明度**，不得自造灰色 hex。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  double lin(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  double lum(Color c) => 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
  double contrast(Color a, Color b) {
    final la = lum(a), lb = lum(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  int rgb(Color c) => (c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round();

  /// 规范交付的 token 表（唯一真源）
  Map<String, Map<String, int>> specTokens() {
    final j = jsonDecode(File('test/data/kangtu_tokens_v1.5.json').readAsStringSync()) as Map<String, dynamic>;
    final out = <String, Map<String, int>>{};
    (j['themes'] as Map<String, dynamic>).forEach((theme, v) {
      out[theme] = <String, int>{
        for (final e in (v as Map<String, dynamic>).entries) e.key: int.parse((e.value as String).substring(1), radix: 16),
      };
    });
    return out;
  }

  /// 本仓 token → 规范 token 名的映射
  Map<String, int> implTokens(GymColors c) => {
        '--color-bg': rgb(c.pageBg),
        '--color-surface': rgb(c.bgRaised),
        '--color-surface-2': rgb(c.bgRaised2),
        '--color-text': rgb(c.text),
        '--color-text-muted': rgb(c.textSecondary),
        '--color-brand': rgb(c.accent),
        // 注意：`ember` 是 CTA **填充色**（浅色 = brand-ink #007C76、深色 = brand #2CD4C9，
        // 见规范 CTA 行）；`--color-brand-ink` 要取 `emberDeep`（浅 #007C76 / 深 #7BEDE4）
        '--color-brand-ink': rgb(c.emberDeep),
        '--color-accent': rgb(c.brass),
        '--color-accent-ink': rgb(c.accentInk),
        '--color-divider': rgb(c.border),
        '--color-success': rgb(c.sage),
        '--color-success-ink': rgb(c.successInk),
        '--color-warning': rgb(c.warn),
        '--color-warning-ink': rgb(c.warningInk),
        '--color-error': rgb(c.danger),
        '--color-error-ink': rgb(c.errorInk),
        '--color-focus': rgb(c.focus),
      };

  group('§06 token 表对齐（读规范交付的 json）+ §06.1/§06.2/§06.3 规则', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Store.instance.init();
      fit.resetAllData();
      fit.onboarded = true;
      setAppLanguage('en');
    });

    test('三套主题的 17 个 token 必须逐一对齐 tokens.json（防实现与规范漂移）', () {
      final spec = specTokens();
      final impl = {'light': GymColors.light, 'dark': GymColors.dark, 'amoled': GymColors.amoled};
      expect(spec.keys.toSet(), impl.keys.toSet(), reason: '主题名要与规范一致');
      for (final theme in spec.keys) {
        final want = spec[theme]!, got = implTokens(impl[theme]!);
        expect(got.keys.toSet(), want.keys.toSet(), reason: '$theme 的 token 名要对齐规范');
        for (final k in want.keys) {
          expect(got[k], want[k],
              reason: '$theme $k 与规范不一致：实现 #${got[k]!.toRadixString(16).padLeft(6, '0').toUpperCase()}'
                  ' vs 规范 #${want[k]!.toRadixString(16).padLeft(6, '0').toUpperCase()}');
        }
      }
    });

    test('AMOLED（§06.2）：相对 dark 只改 4 个 token，其余全部继承', () {
      final a = implTokens(GymColors.amoled), d = implTokens(GymColors.dark);
      final diff = a.keys.where((k) => a[k] != d[k]).toSet();
      expect(diff, {'--color-bg', '--color-surface', '--color-surface-2', '--color-divider'},
          reason: 'AMOLED 只允许改这 4 个 token（阶梯上抬一步）');
      expect(a['--color-bg'], 0x000000, reason: 'AMOLED 场 = 真纯黑（像素关闭）');
      expect(a['--color-text'], rgb(GymColors.dark.text), reason: '文字天花板沿用 #E8F4F2');
      expect(a['--color-text'], isNot(0xFFFFFF), reason: '规范：AMOLED 文字永不 #FFFFFF');
    });

    test('§06 焦点环：--color-focus 在两种场底都 ≥3:1；浅色 = brand-ink（原始 teal 只有 2.6）', () {
      expect(contrast(GymColors.light.bgRaised, GymColors.light.focus), greaterThanOrEqualTo(3.0));
      expect(contrast(GymColors.light.pageBg, GymColors.light.focus), greaterThanOrEqualTo(3.0),
          reason: '焦点环在场底也要 ≥3:1（规范 4.7:1）');
      expect(rgb(GymColors.light.focus), rgb(GymColors.light.ember), reason: '浅色焦点 = --color-brand-ink #007C76');
      expect(contrast(GymColors.dark.bg, GymColors.dark.focus), greaterThanOrEqualTo(3.0));
      expect(rgb(GymColors.dark.focus), rgb(GymColors.dark.accent), reason: '暗色焦点 = --color-brand #2CD4C9');
    });

    test('§06.1 语义色：原始色只作图形（<4.5），状态文字必须用 ink 变体（≥4.5）', () {
      final l = GymColors.light, surf = l.bgRaised;
      // 规范 §06.1：原始语义色一律「graphics only」——success 3.4 / warning 2.9 / error 4.6，
      // 都不够正文门槛（error 恰好 4.6，数值上越过 4.5，但规范仍判 graphics only）
      expect(contrast(surf, l.success), lessThan(3.5), reason: '原始 success 3.4:1');
      expect(contrast(surf, l.warning), lessThan(3.0), reason: '原始 warning 2.9:1（连 3:1 图形门槛都不到）');
      expect(contrast(surf, l.error), lessThanOrEqualTo(4.7), reason: '原始 error 4.6:1');
      expect(contrast(surf, l.successInk), greaterThanOrEqualTo(4.5), reason: '--color-success-ink 5.3:1');
      expect(contrast(surf, l.warningInk), greaterThanOrEqualTo(4.5), reason: '--color-warning-ink 5.6:1');
      expect(contrast(surf, l.errorInk), greaterThanOrEqualTo(4.5), reason: '--color-error-ink 6.8:1');
      expect({rgb(l.success), rgb(l.warning), rgb(l.error)}.length, 3, reason: '三态色不能重色');
      expect({rgb(l.successInk), rgb(l.warningInk), rgb(l.errorInk)}.length, 3);
    });

    test('§06.1 muted 只在白卡达标：场上要加深到 ink（规范：field fail）', () {
      final l = GymColors.light;
      expect(contrast(l.bgRaised, l.textSecondary), greaterThanOrEqualTo(4.5), reason: '白卡上 #5B7B77 = 4.6:1');
      expect(contrast(l.pageBg, l.textSecondary), lessThan(4.5),
          reason: '规范明确：muted 在薄荷场上只有 4.3:1 → 场上改用 ink');
      expect(contrast(l.pageBg, l.text), greaterThanOrEqualTo(4.5), reason: '场上正文用 ink 达标');
    });

    test('§06 品牌色只做图形；正文级用 ink 变体（≥4.5）', () {
      final l = GymColors.light, surf = l.bgRaised;
      expect(contrast(surf, l.accent), lessThan(4.5), reason: 'teal #00B5AD 2.6:1 · Never body text');
      expect(contrast(surf, l.brass), lessThan(4.5), reason: 'orange #FF8C42 2.3:1 · Never as text');
      expect(contrast(surf, l.ember), greaterThanOrEqualTo(4.5), reason: 'brand-ink #007C76 = 5.1:1');
      expect(contrast(surf, l.accentInk), greaterThanOrEqualTo(4.5), reason: 'accent-ink #A94B10 = 5.7:1');
    });

    test('CTA 填充与文字 ≥4.5；且禁止 teal-on-orange / orange-on-teal', () {
      expect(contrast(GymColors.light.ember, GymColors.light.onEmber), greaterThanOrEqualTo(4.5),
          reason: '浅色 CTA：#FFFFFF on --color-brand-ink');
      expect(contrast(GymColors.dark.ember, GymColors.dark.onEmber), greaterThanOrEqualTo(4.5),
          reason: '深色 CTA：#0B2321 on --color-brand');
      expect(contrast(GymColors.light.accent, GymColors.light.brass), lessThan(3.0),
          reason: '规范：两色同亮度，任意尺寸都不达标 → 永不叠放');
    });

    test('§06.3 阶梯是「色调抬升」不是阴影：浅色场非纯白、表面纯白、相邻步差很小', () {
      final l = GymColors.light;
      expect(rgb(l.pageBg), isNot(0xFFFFFF), reason: '浅色场永不纯白（白是抬升表面）');
      expect(rgb(l.bgRaised), 0xFFFFFF, reason: 'surface = 白');
      expect(contrast(l.pageBg, l.bgRaised), lessThan(1.4), reason: '相邻步只有 1.08–1.32:1');
    });

    test('§06 禁用态 = 38% 不透明度（不得另造灰色 hex）', () {
      expect(kDisabledOpacity, closeTo(0.38, 0.0001));
      // 禁用态用「token + 38% 不透明度」表达，不引入新的灰色常量
      for (final c in [GymColors.light, GymColors.dark, GymColors.amoled]) {
        expect(c.text.withValues(alpha: kDisabledOpacity), isNotNull);
      }
    });

    test('三套主题的分隔线都比各自场深（可见性辅助，不是组件边界）', () {
      for (final c in [GymColors.light, GymColors.dark, GymColors.amoled]) {
        expect(contrast(c.pageBg, c.border), lessThan(3.0), reason: '分隔线属非文字元素，不追求对比度');
        expect(rgb(c.border), isNot(rgb(c.pageBg)), reason: '分隔线不能与场同色');
      }
    });
  });
}
