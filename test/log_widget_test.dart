// 统一「日志」页 + 康复记录弹层（RehabPick）widget 测试：渲染 / 阶段说明 / 红绿灯说明 / 保存。
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/rehab_episode.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    setAppLanguage('zh');
    fit.resetAllData();
    fit.onboarded = true;
    fit.createEpisode(RehabEpisode(
        id: 'e1', title: '腰部康复', createdAt: DateTime.now(), area: 'lowback', status: 'active'));
  });
  tearDown(() => fit.route = 'home');

  testWidgets('日志页渲染：填写 + 趋势 + 历史', (tester) async {
    fit.route = 'log';
    await tester.pumpWidget(const GymManeApp());
    await tester.pumpAndSettle();

    expect(find.text('记录一次训练'), findsOneWidget);
    expect(find.text('记录康复'), findsOneWidget);
    expect(find.text('趋势报表'), findsOneWidget);
    expect(find.text('历史记录'), findsOneWidget);
  });

  testWidgets('打开记录康复弹层 → 选阶段/红绿灯显示说明 → 保存', (tester) async {
    fit.route = 'log';
    await tester.pumpWidget(const GymManeApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('记录康复').first);
    await tester.pumpAndSettle();

    // 阶段 + 红绿灯选项与说明
    expect(find.text('阶段1'), findsOneWidget);
    expect(find.text('维持期'), findsOneWidget);
    expect(find.text('绿灯'), findsOneWidget);

    await tester.tap(find.text('阶段2'));
    await tester.pumpAndSettle();
    expect(find.textContaining('稳定进阶'), findsOneWidget);

    await tester.tap(find.text('红灯'));
    await tester.pumpAndSettle();
    expect(find.textContaining('退回上一阶段'), findsOneWidget);

    await tester.tap(find.text('保存记录'));
    await tester.pumpAndSettle();

    expect(fit.rehabLog.length, 1);
    expect(fit.rehabLog.single.phase, 2);
    expect(fit.rehabLog.single.light, 'r');
  });

  // 回归（上游「按开始日计训练」语义合并，ISS-14x）：跨午夜训练在日志里必须按「开始日」打开日详情，
  // 否则点进去会落到结束日 → 显示「休息日」而看不到这次训练。
  testWidgets('跨午夜训练在日志中按「开始日」打开日详情', (tester) async {
    final start = DateTime(2026, 10, 12, 23, 30);
    fit.sessions.add(LoggedSession(start.add(const Duration(hours: 1)), 3600, [
      LoggedExercise('plank', 'Plank', 'abdomen', [LoggedSet(0, 0, sec: 60)]),
    ]));
    fit.route = 'log';
    await tester.pumpWidget(const GymManeApp());
    await tester.pumpAndSettle();

    final rowText = find.textContaining(t.longDate(start));
    expect(rowText, findsWidgets);
    await tester.tap(rowText.first);
    await tester.pumpAndSettle();

    expect(find.text(t.restDay), findsNothing);
  });
}
