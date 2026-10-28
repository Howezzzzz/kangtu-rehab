// RISK-058 回归：交织 UI（上游新功能 × 康途定制）的 widget 层守护。
// 覆盖例程编辑页：①prog 计划行渲染；②超级组链（上游）在康途编辑页里的导轨渲染。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/screens/routine_edit_screen.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/theme/app_colors.dart';
import 'package:gymmane/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RISK-058 例程编辑页 widget 守护', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Store.instance.init();
      fit.resetAllData();
      fit.onboarded = true;
      fit.setUnits('kg');
      setAppLanguage('zh');
    });

    Future<void> pumpEdit(WidgetTester tester, String routineId) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      fit.openRoutine(routineId);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: AnimatedBuilder(
          animation: fit,
          builder: (_, _) => const Scaffold(body: RoutineEditScreen()),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
    }

    Finder rails() => find.byWidgetPredicate((w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).color == GymColors.dark.brass);

    testWidgets('计划行渲染计划重量（prog 计划 × 编辑页）', (tester) async {
      final id = fit.createRoutine('W-plan');
      final a = fit.matchExerciseByName('Barbell Bench Press')!.id;
      fit.toggleRoutineExercise(id, a);
      fit.setPlannedSets(id, a, const [PlannedSet(reps: 5, weightKg: 137.5)]);
      await pumpEdit(tester, id);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('137.5'), findsWidgets, reason: '计划行应显示计划重量');
    });

    testWidgets('无链时无超级组导轨', (tester) async {
      final id = fit.createRoutine('W-nochain');
      final a = fit.matchExerciseByName('Barbell Bench Press')!.id;
      final b = fit.matchExerciseByName('Barbell Squat')!.id;
      fit.toggleRoutineExercise(id, a);
      fit.toggleRoutineExercise(id, b);
      await pumpEdit(tester, id);
      expect(tester.takeException(), isNull);
      expect(rails(), findsNothing);
    });

    testWidgets('链上超级组后出现导轨（上游新功能在康途编辑页渲染正常）', (tester) async {
      final id = fit.createRoutine('W-chain');
      final a = fit.matchExerciseByName('Barbell Bench Press')!.id;
      final b = fit.matchExerciseByName('Barbell Squat')!.id;
      fit.toggleRoutineExercise(id, a);
      fit.toggleRoutineExercise(id, b);
      fit.toggleChain(id, a);
      await pumpEdit(tester, id);
      expect(tester.takeException(), isNull);
      expect(rails(), findsWidgets, reason: '链上后应有导轨');
    });
  });
}
