import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/rehab_episode.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// RISK-100：康复提示词的 i18n 不变量。
///
/// 提示词是**用户可见**的导出内容（复制到剪贴板交给外部 AI），而且里面写着安全规则。
/// 抽取到 arb 之后必须保证：
///  ① 8 条输出规则在任何语言下都齐全（尤其规则 6 的强度上限、规则 7 的叫停规则、规则 8 的安全门行为）；
///  ② 英文提示词里不得再混入汉字 —— 这同时证明抽取彻底、且非中文用户不会再拿到中文提示；
///  ③ 安全门提示与训练反馈行同样本地化；
///  ④ 品牌名走 arb（中文「康途」/ 其他语言「Kangtu」）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.setUnits('kg');
  });

  bool hasHan(String s) => RegExp(r'[\u4e00-\u9fff]').hasMatch(s);

  RehabEpisode ep({bool doctor = false}) {
    final e = RehabEpisode(
      id: 'r1',
      title: 't',
      createdAt: DateTime(2026, 10, 18),
      area: 'lowback',
      duration: 'sub',
      pain: 4,
      redFlags: const ['bladder'],
      factors: 'long sitting',
      goals: const ['pain'],
      equipment: const ['Bodyweight'],
      daysPerWeek: 3,
    );
    if (doctor) {
      e
        ..doctorDx = 'L5-S1 disc protrusion'
        ..icdCode = 'M51.1'
        ..visitDate = DateTime(2026, 11, 1)
        ..ordersText = 'Avoid lifting; core stability first'
        ..advisedCare = 'Core stability'
        ..restrictions = 'No heavy squat or deadlift'
        ..imaging = 'MRI: mild bulge'
        ..followUpAt = DateTime(2026, 12, 1);
    }
    return e;
  }

  test('8 条输出规则在任何语言下都齐全（安全语义一条都不许漏）', () {
    for (final lang in ['zh', 'zh_Hant', 'en']) {
      setAppLanguage(lang);
      for (final withDoctor in [false, true]) {
        final txt = fit.rehabPromptText(ep(doctor: withDoctor));
        final rules = [
          t.rehabPromptRule1,
          t.rehabPromptRule2,
          t.rehabPromptRule3,
          t.rehabPromptRule4,
          t.rehabPromptRule5,
          t.rehabPromptRule6,
          t.rehabPromptRule7(t.rehabStopRules),
          withDoctor ? t.rehabPromptRule8Doctor : t.rehabPromptRule8Gate,
        ];
        for (final r in rules) {
          expect(txt, contains(r), reason: '$lang / doctor=$withDoctor 缺规则：${r.split('\n').first}');
        }
        expect(txt, contains('3/10'), reason: '$lang 丢了强度上限（规则 6）');
        expect(txt, contains(t.rehabStopRules), reason: '$lang 丢了叫停规则（规则 7）');
      }
    }
  });

  test('分节标题在任何语言下都齐全', () {
    for (final lang in ['zh', 'en']) {
      setAppLanguage(lang);
      final txt = fit.rehabPromptText(ep(doctor: true));
      for (final h in [
        t.rehabPromptSecProfile,
        t.rehabPromptSecIssue,
        t.rehabPromptSecDoctor,
        t.rehabPromptSecPlan,
        t.rehabPromptSecFeedback,
        t.rehabPromptSecOutput,
        t.rehabPromptSecLibrary,
      ]) {
        expect(txt, contains(h), reason: '$lang 缺分节：$h');
      }
    }
  });

  test('英文提示词里不残留汉字（抽取彻底）', () {
    setAppLanguage('en');
    expect(hasHan(fit.rehabPromptText(ep(doctor: true))), isFalse,
        reason: '英文提示词里还有中文 → 非中文用户会拿到中文提示，抽取没做干净');
  });

  test('zh 文案与原硬编码逐字一致（零行为变化回归）', () {
    setAppLanguage('zh');
    expect(t.rehabPromptSecProfile, '【我的情况】');
    expect(t.rehabPromptRule6, '6. 强度保守：以不加重症状为前提，训练中疼痛不超过 3/10；先活动度、再稳定性、最后力量。');
    expect(t.rehabPromptSecLibrary, '【动作库清单】英文名 (中文名) | 肌群 | 器材 | 难度 | 模式');
    expect(t.rehabMissGateAdjust, '未通过安全门，已忽略全部计划调整');
    expect(t.rehabMissNoSuchPlan('X'), '计划「X」不存在');
    expect(t.rehabFbNote('n'), '备注：n');
    final txt = fit.rehabPromptText(ep());
    expect(txt, contains('【本次困扰】'));
    expect(txt, contains('- 当前不适程度：4/10'));
    expect(txt, contains('- 可用器材：Bodyweight'));
    expect(txt, contains('- 每周可训练天数：3 天'));
  });

  test('安全门提示与反馈行已本地化（英文无汉字）', () {
    setAppLanguage('en');
    final s = [
      t.rehabMissGateAdjust,
      t.rehabMissNoLinkedPlan,
      t.rehabMissNoSuchPlan('X'),
      t.rehabMissGateReply,
      t.rehabFbDefaultArea,
      t.rehabFbPainWithArea('knee', '3'),
      t.rehabFbNote('n'),
      t.rehabFbNoDetail,
      t.rehabFbLine('11/04', 'b'),
    ].join(' | ');
    expect(s, isNot(contains('未通过安全门')));
    expect(hasHan(s), isFalse, reason: '这些提示会直接显示在界面里，英文下不该有汉字');
  });

  test('品牌名走 arb：中文「康途」/ 其他语言「Kangtu」', () {
    setAppLanguage('zh');
    expect(fit.planRequestText(), contains('康途 · '));
    setAppLanguage('en');
    final en = fit.planRequestText();
    expect(en, contains('Kangtu'));
    expect(en, isNot(contains('康途')), reason: '训练计划提示词里曾硬编码「康途」，非中文用户会看到中文品牌');
  });
}
