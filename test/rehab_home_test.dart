import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/rehab_episode.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 「康复」模块独立化回归：档案为主、手册为次，入口/返回栈正确。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    setAppLanguage('zh');
    fit.resetAllData();
    fit.setUnits('kg');
    fit.onboarded = true;
  });

  testWidgets('康复模块首页：以档案为主，含新建入口与手册次级入口', (tester) async {
    fit.route = 'rehab';
    await tester.pumpWidget(const GymManeApp());
    await tester.pumpAndSettle();

    expect(find.text('康复'), findsWidgets);
    expect(find.text('新建康复档案'), findsOneWidget);
    expect(find.text('康复手册'), findsOneWidget); // 手册降级为模块内的次级入口
    expect(find.text('还没有档案。比如「腰疼」「肩痛」都可以开一个。'), findsOneWidget);
    fit.route = 'home';
  });

  testWidgets('点手册入口进入手册页，返回回到康复模块', (tester) async {
    fit.route = 'rehab';
    await tester.pumpWidget(const GymManeApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('康复手册'));
    await tester.pumpAndSettle();
    expect(fit.route, 'rehab-book');

    fit.backFromRehabBook();
    await tester.pumpAndSettle();
    expect(fit.route, 'rehab');
    fit.route = 'home';
  });

  testWidgets('档案列表出现在康复模块首页', (tester) async {
    fit.createEpisode(RehabEpisode(
      id: 're9', title: '腰部康复', createdAt: DateTime.now(),
      area: 'lowback', duration: 'sub', pain: 4,
      goals: const ['pain'], equipment: const ['Bodyweight'], daysPerWeek: 3,
    ));
    fit.route = 'rehab';
    await tester.pumpWidget(const GymManeApp());
    await tester.pumpAndSettle();

    expect(find.text('腰部康复'), findsOneWidget);
    expect(find.textContaining('腰部'), findsWidgets);
    fit.route = 'home';
  });
}
