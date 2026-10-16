// 自测基线页 widget 测试：渲染 / 安全闸 / 保存 / 超范围输入不崩（Infinity 回归）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/l10n/l10n.dart';
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
  });
  tearDown(() => fit.route = 'home');

  testWidgets('基线页渲染 6 项 + 安全闸', (tester) async {
    fit.route = 'baseline';
    await tester.pumpWidget(const GymManeApp());
    await tester.pumpAndSettle();

    expect(find.text('运动前安全自查'), findsOneWidget);
    expect(find.text('静息心率'), findsOneWidget);
    expect(find.text('30 秒坐站'), findsOneWidget);
    expect(find.text('腰围'), findsOneWidget);
    expect(find.text('保存基线'), findsOneWidget);
  });

  testWidgets('安全闸打勾 → 提示先咨询医生（不出自测）', (tester) async {
    fit.route = 'baseline';
    await tester.pumpWidget(const GymManeApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('运动时是否出现胸痛或胸闷？'));
    await tester.pumpAndSettle();

    expect(find.textContaining('请先咨询医生'), findsOneWidget);
    expect(find.text('保存基线'), findsNothing);
  });

  testWidgets('填一项保存 → 生成基线', (tester) async {
    fit.route = 'baseline';
    await tester.pumpWidget(const GymManeApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '62');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('保存基线'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存基线'));
    await tester.pumpAndSettle();

    expect(fit.baselines.length, 1);
    expect(fit.latestBaseline!.value('resting_hr'), 62);
  });

  testWidgets('超范围输入（1e999 → Infinity）不崩溃、不入库', (tester) async {
    fit.route = 'baseline';
    await tester.pumpWidget(const GymManeApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '1e999');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('保存基线'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存基线'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(fit.baselines.isEmpty, isTrue);
  });
}
