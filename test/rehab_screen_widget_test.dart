import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/rehab_episode.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 覆盖康复档案页「导入智能建议」的结果展示分支（V5 §2.4 覆盖率补口）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    setAppLanguage('zh');
    fit.resetAllData();
    fit.setUnits('kg');
  });

  testWidgets('导入回复后显示结果，含「调整 N 处」计数', (tester) async {
    fit.onboarded = true;
    fit.createEpisode(RehabEpisode(
      id: 're1',
      title: '腰部康复',
      createdAt: DateTime.now(),
      area: 'lowback',
      duration: 'sub',
      pain: 4,
      goals: const ['pain'],
      equipment: const ['Bodyweight'],
      daysPerWeek: 3,
    ));
    fit.activeEpisodeId = 're1';
    fit.route = 'rehab-episode';

    await tester.pumpWidget(const GymManeApp());
    await tester.pumpAndSettle();

    // 回复框是页面里第一个 TextField（AI 建议卡在备注卡之前）
    await tester.enterText(
      find.byType(TextField).first,
      '{"advice":"疼就停", "routines":[{"name":"康复 A","exercises":['
      '{"name":"Barbell Bench Press","sets":3,"reps":10}]}]}',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('导入智能建议'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入智能建议'));
    await tester.pumpAndSettle();

    expect(find.textContaining('已生成'), findsOneWidget);
    expect(find.textContaining('调整'), findsOneWidget);
    expect(fit.episodeById('re1')!.advice, contains('疼就停'));

    fit.route = 'home';
  });

  testWidgets('贴了读不懂的内容时提示（_unreadable 分支）', (tester) async {
    fit.onboarded = true;
    fit.createEpisode(RehabEpisode(
      id: 're2',
      title: '膝部康复',
      createdAt: DateTime.now(),
      area: 'knee',
      duration: 'sub',
      pain: 3,
      daysPerWeek: 3,
    ));
    fit.activeEpisodeId = 're2';
    fit.route = 'rehab-episode';

    await tester.pumpWidget(const GymManeApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '多喝热水，注意休息。');
    await tester.pump();
    await tester.ensureVisible(find.text('导入智能建议'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入智能建议'));
    await tester.pumpAndSettle();

    expect(find.textContaining('没读懂'), findsOneWidget);

    fit.route = 'home';
  });
}
