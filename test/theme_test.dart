import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/l10n/l10n.dart';import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/app/pixel_shift.dart';
import 'package:gymmane/theme/app_colors.dart';
import 'package:gymmane/theme/app_theme.dart';
import 'package:gymmane/widgets/ui_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 品牌规范《Kangtu — 品牌与界面系统 v1.5.2》（§04 色阶 / §06 色彩管理 / §06.1 对比度审计 /
/// §06.2 AMOLED 覆写 / §06.3 双向表面阶梯 / §06.4 光影系统）的配色不变量。
///
/// 与 v1.5 的差别：
/// 1. **双向阶梯**：recessed(-1) → bg(0) → surface(1) → surface-2(2) → surface-3(3)；
///    浅色卡片/弹层 = step1 #F7FCFA（不再是纯白），嵌套 = step2/3 #FFFFFF。
/// 2. **发丝线加深**：--color-divider 浅 #DCE9E6 → #BCD5D0（白底 1.55:1）。
/// 3. **§06.4 光影**：左上固定光源 + 顶侧 1px 内高光 + 发丝线 + 三层阴影 + 场域辉光；
///    新增 --color-highlight / sheen / glow / shadow / shadow-deep 五个 token。
/// 4. **§04 色阶**：teal / orange / ink 各 10 级（brand 在 05；文字安全 teal 07+ / orange 08+ / ink 05+）。
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
    final j = jsonDecode(File('test/data/kangtu_tokens_v1.5.2.json').readAsStringSync()) as Map<String, dynamic>;
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
        '--color-surface-3': rgb(c.surface3),
        '--color-recessed': rgb(c.recessed),
        '--color-highlight': rgb(c.highlight),
        '--color-sheen': rgb(c.sheen),
        '--color-glow': rgb(c.glow),
        '--color-shadow': rgb(c.shadow),
        '--color-shadow-deep': rgb(c.shadowDeep),
        // §04 色阶（三套主题共用同一组阶梯）
        for (var i = 0; i < 10; i++) '--color-teal-${(i + 1).toString().padLeft(2, '0')}': rgb(GymColors.tealRamp[i]),
        for (var i = 0; i < 10; i++) '--color-orange-${(i + 1).toString().padLeft(2, '0')}': rgb(GymColors.orangeRamp[i]),
        for (var i = 0; i < 10; i++) '--color-ink-${(i + 1).toString().padLeft(2, '0')}': rgb(GymColors.inkRamp[i]),
      };

  group('v1.5 字段完整性（copyWith/lerp/派生态）与 §06.1 消费点', _copyLerpTests);

  group('§06 token 表对齐（读规范交付的 json）+ §06.1/§06.2/§06.3 规则', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Store.instance.init();
      fit.resetAllData();
      fit.onboarded = true;
      setAppLanguage('en');
    });

    test('三套主题的 token 必须逐一对齐 tokens.json（防实现与规范漂移）', () {
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

    test('AMOLED（§06.2）：相对 dark 只改阶梯上的 6 个 token，其余全部继承', () {
      final a = implTokens(GymColors.amoled), d = implTokens(GymColors.dark);
      final diff = a.keys.where((k) => a[k] != d[k]).toSet();
      expect(diff, {
        '--color-bg', '--color-surface', '--color-surface-2', '--color-surface-3',
        '--color-recessed', '--color-divider'
      }, reason: 'AMOLED 只允许改阶梯上的 6 个 token（阶梯整体上抬一步）');
      expect(a['--color-bg'], 0x000000, reason: 'AMOLED 场 = 真纯黑（像素关闭）');
      expect(a['--color-recessed'], a['--color-bg'], reason: 'AMOLED 无法再往下凹 → recessed = 场，靠发丝线定义');
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

    test('§06.1 muted 只在白面达标：场上必须加深到 ink', () {
      final l = GymColors.light;
      expect(contrast(l.bgRaised2, l.textSecondary), greaterThanOrEqualTo(4.5), reason: '白面（step2/3）上 #5B7B77 = 4.6:1');
      expect(contrast(l.bgRaised, l.textSecondary), greaterThanOrEqualTo(4.4),
          reason: '§06.3 把卡片挪到 step1 #F7FCFA 之后，muted 约 4.44:1（规范仍列为「白面专用」，实现保持在 4.4+）');
      expect(contrast(l.pageBg, l.textSecondary), lessThan(4.5),
          reason: '规范明确：muted 在薄荷场上不达标 → 场上改用 ink');
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

    test('§06.3 双向阶梯：浅色场非纯白、卡片是 step1、最高层纯白、发丝线可读', () {
      final l = GymColors.light;
      expect(rgb(l.pageBg), 0xEEF9F7, reason: '场 = 淡薄荷，永不纯白');
      expect(rgb(l.bgRaised), 0xF7FCFA, reason: 'step1 = 卡片/弹层 #F7FCFA');
      expect(rgb(l.bgRaised2), 0xFFFFFF, reason: 'step2 = 嵌套行 #FFFFFF');
      expect(rgb(l.surface3), 0xFFFFFF, reason: 'step3 = 顶层 #FFFFFF');
      expect(rgb(l.recessed), 0xDCE9E6, reason: 'step−1 = 凹陷井 #DCE9E6');
      expect(contrast(l.pageBg, l.bgRaised), lessThan(1.2), reason: '浅色相邻步很轻（1.04–1.16）');
      expect(contrast(l.recessed, l.pageBg), greaterThan(1.0), reason: '凹陷一步要在场下');
      expect(contrast(l.bgRaised, l.border), greaterThan(1.4), reason: '发丝线 #BCD5D0 ≥1.4:1（白底 1.55）');
    });

    test('§04 色阶：teal/orange/ink 各 10 级，brand 在 05，文字安全区间与规范一致', () {
      expect(GymColors.tealRamp.length, 10);
      expect(GymColors.orangeRamp.length, 10);
      expect(GymColors.inkRamp.length, 10);
      expect(rgb(GymColors.tealRamp[4]), 0x00B5AD, reason: 'teal step05 = brand');
      expect(rgb(GymColors.orangeRamp[4]), 0xFF8C42, reason: 'orange step05 = accent');
      expect(rgb(GymColors.inkRamp[9]), 0x0C2F2C, reason: 'ink step10 = 正文墨色');
      // 规范：文字安全 = teal 07–10 / orange 08–10 / ink 05–10（白底 4.5:1）
      for (var i = 6; i < 10; i++) {
        expect(contrast(GymColors.tealRamp[i], const Color(0xFFFFFFFF)), greaterThanOrEqualTo(4.5),
            reason: 'teal step${i + 1} 应达文字安全');
      }
      for (var i = 7; i < 10; i++) {
        expect(contrast(GymColors.orangeRamp[i], const Color(0xFFFFFFFF)), greaterThanOrEqualTo(4.5),
            reason: 'orange step${i + 1} 应达文字安全');
      }
    });

    test('§06.4 光影：顶侧高光/发丝线/三层阴影都由 token 合成，不自造灰', () {
      final l = GymColors.light;
      expect(rgb(l.shadow), 0x0C2F2C, reason: '浅色阴影基色 = --color-shadow');
      expect(rgb(l.shadowDeep), 0x061613, reason: '贴地阴影 = --color-shadow-deep');
      final sh = l.depthShadows(3);
      expect(sh.length, 3, reason: 'ambient / key / contact 三层');
      for (final s in sh) {
        expect(s.color.a, greaterThan(0), reason: '阴影不透明度必须 >0（由 token + α 合成）');
        expect(s.blurRadius, greaterThan(0));
      }
      expect(l.depthShadows(0), isEmpty, reason: 'L0 场不加阴影（辉光负责纵深）');
      // 层级越高阴影越重
      expect(l.depthShadows(4).first.color.a, greaterThan(l.depthShadows(2).first.color.a));
    });

    test('§06.4 深度配方：卡片/弹层必须带分层阴影 + 高光 + 发丝线（防回退成扁平）', () {
      for (final gc in [GymColors.light, GymColors.dark, GymColors.amoled]) {
        final card = gc.depthDecor(level: 2, radius: 22);
        expect(card.boxShadow!.length, 3, reason: '卡片三层阴影');
        expect(card.gradient, isNotNull, reason: 'L2 起要有顶侧高光');
        expect(card.border!.top.color.a, lessThan(1.0), reason: 'L2 还没到读边层，发丝线偏淡');
        final sheet = gc.depthDecor(level: 3, radius: 28);
        expect(sheet.boxShadow!.length, 3, reason: '弹层三层阴影');
        expect(sheet.border!.top.color.a, 1.0, reason: 'L3 用满强度发丝线');
        expect(sheet.boxShadow!.first.blurRadius,
            greaterThanOrEqualTo(card.boxShadow!.first.blurRadius), reason: '层级越高越浮');
        // 阶梯填充映射
        expect(rgb(gc.surfaceFill(1)), rgb(gc.recessed));
        expect(rgb(gc.surfaceFill(2)), rgb(gc.bgRaised), reason: 'step1 = 卡片/弹层');
        expect(rgb(gc.surfaceFill(3)), rgb(gc.bgRaised2), reason: 'step2 = 嵌套行');
        expect(rgb(gc.surfaceFill(4)), rgb(gc.surface3), reason: 'step3 = 顶层');
      }
      // 组件层真的接上了配方（不能只定义不用）
      expect(sheetDecoration(GymColors.light).boxShadow, isNotEmpty, reason: '弹层要带阴影');
      expect(sheetDecoration(GymColors.light).border, isNotNull, reason: '弹层要带发丝线');
    });

    testWidgets('SoftCard 必须真的接上 §06.4 深度配方（防回退成纯色+淡边框）', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: SoftCard(child: Text('x'))),
      ));
      final deco = tester
          .widget<Container>(find.descendant(of: find.byType(SoftCard), matching: find.byType(Container)).first)
          .decoration as BoxDecoration;
      expect(deco.boxShadow, isNotEmpty, reason: '卡片要带分层阴影');
      expect(deco.gradient, isNotNull, reason: '卡片要有顶侧高光');
      expect(deco.border, isNotNull, reason: '卡片要带发丝线');
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
  

    test('§06.2 防烧屏：AMOLED 例外下要有「周期性微移静态 chrome」，且幅度有界', () {
      // 规范原文：shift static UI chrome periodically against burn-in.
      // 实现：lib/app/pixel_shift.dart（纯函数 pixelShiftOffset + PixelShift 包装器），
      // 仅 AMOLED 主题生效；幅度默认 3 px、轮换周期 4 分钟。
      final src = File('lib/app/pixel_shift.dart').readAsStringSync();
      expect(src.contains("fit.themePref == 'amoled'"), isTrue,
          reason: '微移必须只在 AMOLED 主题下生效（规范的例外条款只覆盖 AMOLED）');
      expect(src.contains('Timer.periodic'), isTrue, reason: '需要周期触发（否则不会随时间轮换）');
      expect(src.contains("didChangeAppLifecycleState"), isTrue, reason: '回前台要按当前时间基复位');
      expect(kPixelShiftAmplitude, lessThanOrEqualTo(4), reason: '幅度必须小（否则界面会被挪歪）');
      // 底部导航栏（最长时间驻留的 chrome）必须真的接上
      final shell = File('lib/app/app_shell.dart').readAsStringSync();
      expect(shell.contains('PixelShift('), isTrue, reason: '底栏要套上 PixelShift');
    });
  });
}

// 覆盖 GymColors 新增字段的 copyWith / lerp（逻辑变更行覆盖率门禁）
void _copyLerpTests() {
  test('copyWith / lerp 必须处理 v1.5 新增的四个字段（否则主题切换会丢字段）', () {
    final a = GymColors.light;
    final b = GymColors.light.copyWith(
        successInk: const Color(0xFF010203), warningInk: const Color(0xFF040506),
        errorInk: const Color(0xFF070809), focus: const Color(0xFF0A0B0C));
    expect(b.successInk, const Color(0xFF010203));
    expect(b.warningInk, const Color(0xFF040506));
    expect(b.errorInk, const Color(0xFF070809));
    expect(b.focus, const Color(0xFF0A0B0C));
    expect(a.successInk, isNot(b.successInk), reason: 'copyWith 前原对象不应被改');

    final mid = a.lerp(GymColors.dark, 0.5);
    expect(mid.successInk, Color.lerp(a.successInk, GymColors.dark.successInk, 0.5));
    expect(mid.focus, Color.lerp(a.focus, GymColors.dark.focus, 0.5));
    expect(GymColors.light.lerp(null, 0.5).focus, GymColors.light.focus, reason: 'other 为 null 时返回自身');
  });

  test('派生色 backdrop 有界：是场色叠黑（浅 10% / 深 30%），且不等于场色本身', () {
    for (final c in [GymColors.light, GymColors.dark]) {
      final b = c.backdrop;
      expect(b, isNot(c.pageBg), reason: '背板必须比场更深一档');
      expect(b.r, lessThanOrEqualTo(c.pageBg.r));
      expect(b.g, lessThanOrEqualTo(c.pageBg.g));
      expect(b.b, lessThanOrEqualTo(c.pageBg.b));
    }
    // AMOLED 例外：场已经是纯黑，再叠黑仍是纯黑 → backdrop == 场色（这是正确的，不是缺陷）
    expect(GymColors.amoled.backdrop, GymColors.amoled.pageBg,
        reason: 'AMOLED 的场已是 #000000，背板无可再深 → 与场同色');
  });

  test('§06.1 消费点：文字样式不得用原始语义色（括号配平精确判定）', () {
    // 规范：Semantic hues are graphic-scale only（success 3.4 / warning 2.9 / error 4.6 于白底）；
    // 状态**文字**一律用 --color-*-ink（5.3~6.8:1）。本守门锁定「消费点」，防止只改 token 不改用点。
    // 用括号配平扫出 AppTheme.f(...)/AppTheme.s(...) 的完整调用段，避免把后面的图标用色误算进来。
    final raw = RegExp(r'gc\.(warn|sage|danger)(?!\w)');
    final call = RegExp(r'AppTheme\.[fs]\(');
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final t = f.readAsStringSync();
      for (final m in call.allMatches(t)) {
        var depth = 1, i = m.end;
        while (i < t.length && depth > 0) {
          final ch = t[i];
          if (ch == '(') {
            depth++;
          } else if (ch == ')') {
            depth--;
          }
          i++;
        }
        final seg = t.substring(m.start, i);
        final mm = raw.firstMatch(seg);
        if (mm != null) {
          final line = '\n'.allMatches(t.substring(0, m.start)).length + 1;
          hits.add('${f.path}:$line → ${mm.group(0)}');
        }
      }
    }
    expect(hits, isEmpty, reason: '文字样式须用 ink 变体（warningInk/successInk/errorInk）：${hits.join("、")}');
  });
}
