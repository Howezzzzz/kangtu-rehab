import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 品牌规范《Kangtu Identity & Interface System v1.1》的配色不变量（§06 / §06.1）。
///
/// 三条容易搞错、但规范写得很死的规则：
/// 1. **对比度以「配对表面」测量** —— 浅色的文字配对 `--color-surface`（#FFFFFF），
///    而不是 mint 场（#EEF9F7）。上游那版测试是拿场去量的，改配色时它就会误报。
/// 2. **品牌色只做图形** —— 规范审计：teal #00B5AD 在白上 2.6:1、orange #FF8C42 在白上 2.3:1，
///    「Never body text」；正文/链接一律用 **brand-ink #007C76（5.1:1）/ accent-ink #A94B10（5.5:1）**。
/// 3. **暗底场是深青墨 #0B2321，不是纯黑**（规范原文：deep teal ink rather than pure black）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  double lin(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  double lum(Color c) => 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
  double contrast(Color a, Color b) {
    final la = lum(a), lb = lum(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  double warmth(Color c) => (c.r - c.b) * 255;
  int rgb(Color c) => (c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round();

  const mintField = 0xEEF9F7, white = 0xFFFFFF;
  const deepTealInk = 0x0B2321;

  group('§04/§06 配色的品牌不变量', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Store.instance.init();
      fit.resetAllData();
      fit.onboarded = true;
      setAppLanguage('en');
    });

    test('浅色：场是薄荷冷调，表面是纯白（规范：light surfaces step #EEF9F7 → #FFFFFF）', () {
      expect(rgb(GymColors.light.pageBg), mintField, reason: '浅色场应为 #EEF9F7');
      expect(warmth(GymColors.light.bg), lessThan(0), reason: '场应带青绿（冷）调');
      expect(rgb(GymColors.light.bgRaised), white, reason: '表面应为纯白 #FFFFFF');
    });

    test('浅色：文字在**表面**上达到 AA/AAA（规范审计以配对表面为准）', () {
      final surf = GymColors.light.bgRaised;
      expect(contrast(surf, GymColors.light.text), greaterThan(7), reason: '正文 AAA');
      expect(contrast(surf, GymColors.light.textSecondary), greaterThan(4.5), reason: '次要 AA（规范 #5B7B77 on #FFFFFF = 4.6）');
      expect(contrast(surf, GymColors.light.textTertiary), greaterThan(3), reason: '三级');
    });

    test('品牌色只做图形：teal/orange 在表面上的对比度**低于正文门槛**（所以不能当正文）', () {
      final surf = GymColors.light.bgRaised;
      final teal = contrast(surf, GymColors.light.accent);
      final orange = contrast(surf, GymColors.light.brass);
      expect(teal, greaterThan(2.0), reason: '图形用要看得见');
      expect(teal, lessThan(4.5), reason: '规范：#00B5AD on #FFFFFF = 2.6，Never body text');
      expect(orange, lessThan(4.5), reason: '规范：#FF8C42 on #FFFFFF = 2.3，Never as text');
    });

    test('正文级青绿/橙用 ink 变体且 ≥4.5（规范 #007C76 = 5.1:1 / #A94B10 = 5.5:1）', () {
      expect(contrast(GymColors.light.bgRaised, GymColors.light.emberDeep), greaterThanOrEqualTo(4.5));
      expect(contrast(GymColors.light.bgRaised, GymColors.light.accentInk), greaterThanOrEqualTo(4.5),
          reason: '橙色当文字必须用 --color-accent-ink，不是 #FF8C42');
    });

    test('暗底：场是深青墨而非纯黑；文字/品牌/橙都达标（规范 §04 dark surface）', () {
      expect(rgb(GymColors.dark.pageBg), deepTealInk, reason: '暗底场应为 #0B2321（规范：rather than pure black）');
      expect(rgb(GymColors.dark.pageBg), isNot(0x000000), reason: '禁止纯黑场');
      final bg = GymColors.dark.bg;
      expect(contrast(bg, GymColors.dark.text), greaterThan(7), reason: '暗底正文 AAA（规范 14.6:1）');
      expect(contrast(bg, GymColors.dark.textSecondary), greaterThan(4.5), reason: '暗底次要文字');
      expect(contrast(bg, GymColors.dark.accent), greaterThan(4.5), reason: '暗底品牌 #2CD4C9（规范 8.9:1）');
      expect(contrast(bg, GymColors.dark.brass), greaterThan(4.5), reason: '暗底橙 #FFA061（规范 8.2:1）');
    });

    test('CTA：填充与文字对比 ≥4.5（浅色 brand-ink 白字 / 深色 brand 配深青墨字）', () {
      expect(contrast(GymColors.light.ember, GymColors.light.onEmber), greaterThanOrEqualTo(4.5));
      expect(contrast(GymColors.dark.ember, GymColors.dark.onEmber), greaterThanOrEqualTo(4.5));
    });

    test('AMOLED 是规范外的扩展：**只把场换成纯黑**，其余 token 与 dark 一致', () {
      final a = GymColors.amoled, d = GymColors.dark;
      expect(rgb(a.pageBg), 0x000000, reason: 'AMOLED 场应为真纯黑（省电扩展）');
      expect(rgb(a.bg), 0x000000);
      expect(rgb(a.bgRaised), rgb(d.bgRaised), reason: '表面应沿用规范 dark token');
      expect(rgb(a.text), rgb(d.text));
      expect(rgb(a.accent), rgb(d.accent), reason: '品牌色应沿用规范 dark token');
      expect(rgb(a.brass), rgb(d.brass));
    });

    test('三态色（success/warning/error）齐全且互不相同；分隔线比场深一档', () {
      final l = GymColors.light;
      final set = {rgb(l.sage), rgb(l.warn), rgb(l.danger)};
      expect(set.length, 3, reason: 'success/warning/error 不能重色');
      expect(warmth(l.border), lessThan(0), reason: '分隔线也应带青绿调（规范 #DCE9E6）');
      expect(rgb(GymColors.dark.border), 0x21504A, reason: '暗底分隔线 = #21504A');
    });
  });
}
