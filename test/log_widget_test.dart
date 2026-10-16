// 统一「日志」页 + 康复记录弹层（RehabPick）widget 测试：渲染 / 阶段说明 / 红绿灯说明 / 保存。
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/rehab_episode.dart';
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
}
