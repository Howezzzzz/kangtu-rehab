// 康途定制 · 融合批次三（2.5 康复入口皮肤统一 / 2.7 自评文案）的回归锁
//
// 锁三件事：
// ① 首页康复入口的副标题走 arb —— 曾把 '${ep.title} · 计划 N 个' 写死在代码里，
//    非中文用户会看到中文；上游 i18n_test 的硬编码扫描跳过带 $ 的插值串，抓不到这类漏。
// ② 首页两个入口与「我的」页三个入口共用 EntryRow 一套规格，且「我的」页挂在分区标题下
//    （此前是三张手搓卡裸挂页面尾部，与上游「每个分区都有标题」的节奏不一致）。
// ③ 首次自评文案说明「可留空」（2.7：自测基线 → 康复自评）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/rehab_episode.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/services/progress_reminder.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/widgets/entry_row.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    ProgressReminder.instance.enabled = false;
    fit.onboarded = true;
    fit.session = null;
    fit.sessions.clear();
    fit.awards.clear();
    fit.awardsSeen.clear();
    fit.pendingAwards.clear();
    fit.rehabEpisodes.clear();
    fit.resetRoute('home');
  });

  testWidgets('首页康复入口的副标题走 arb（不再硬编码中文「计划 N 个」）', (tester) async {
    setAppLanguage('en');
    fit.createEpisode(RehabEpisode(
      id: 'epUi',
      title: 'Lower back',
      createdAt: DateTime(2026, 11, 1),
      routineIds: const ['r1', 'r2'],
    ));
    await tester.pumpWidget(const GymManeApp());
    await tester.pumpAndSettle();

    final detail = find.text('Lower back · 2 programmes');
    await tester.scrollUntilVisible(detail, 300, scrollable: find.byType(Scrollable).first);
    expect(detail, findsOneWidget, reason: '副标题 = 档案名 + t.rehabPlanCount');
    expect(find.textContaining('计划'), findsNothing,
        reason: '中文曾写死在插值串里，英文用户会看到中文');
  });

  testWidgets('首页康复 + 日志两个入口共用 EntryRow', (tester) async {
    setAppLanguage('en');
    await tester.pumpWidget(const GymManeApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text(t.rehabTabLog), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.byType(EntryRow), findsNWidgets(2), reason: '康复入口 + 日志入口');
  });

  testWidgets('「我的」页三个康复入口挂在分区标题下', (tester) async {
    setAppLanguage('en');
    fit.resetRoute('settings');
    await tester.pumpWidget(const GymManeApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Rehab case files'), 400,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('REHAB'), findsWidgets, reason: '_heading 会把分区标题转大写');
    expect(find.byType(EntryRow), findsNWidgets(3), reason: '档案 / 手册 / 自评');
    expect(find.text('Rehab self-check'), findsOneWidget, reason: '2.7：自测基线 → 康复自评');
  });

  test('首次自评文案说明可留空（2.7）', () {
    setAppLanguage('zh');
    expect(t.baselineTitle, '康复自评');
    expect(t.baselineSubtitle, contains('可留空'));
    expect(t.baselineInputHint, contains('可留空'));
    expect(t.baselineSave, '保存自评');

    setAppLanguage('zh_Hant');
    expect(t.baselineTitle, '康復自評', reason: 'zh_Hant 不能留简体');
    expect(t.baselineSubtitle, contains('可留空'));
    expect(t.rehabTitle, '康復', reason: '康复模块的键曾整片抄简体，zh_hant_fix.py 已修');

    setAppLanguage('en');
    expect(t.baselineTitle, 'Rehab self-check');
    expect(t.baselineInputHint, contains('optional'));
    expect(t.rehabPlanCount(2), '2 programmes');
  });
}
