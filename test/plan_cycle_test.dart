// 排期周期（Plan Cycle）回归：均摊/覆盖/周序/钉日/JSON/状态接线。
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/models/plan_cycle.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.setUnits('kg');
    fit.onboarded = true;
  });

  test('均摊：每周 N 次 → 均匀周几', () {
    expect(PlanCycle.evenlySpread(3), [1, 3, 5]);
    expect(PlanCycle.evenlySpread(2), [1, 4]);
    expect(PlanCycle.evenlySpread(1), [1]);
    expect(PlanCycle.evenlySpread(7), [1, 2, 3, 4, 5, 6, 7]);
  });

  test('覆盖范围与周序', () {
    final c = PlanCycle(start: DateTime(2026, 1, 5), weeks: 2, perWeek: 3); // 1/5 是周一
    expect(c.weekIndex(DateTime(2026, 1, 5)), 1);
    expect(c.weekIndex(DateTime(2026, 1, 12)), 2);
    expect(c.weekIndex(DateTime(2026, 1, 19)), isNull);
    expect(c.isTrainingDay(DateTime(2026, 1, 5)), isTrue);
    expect(c.isTrainingDay(DateTime(2026, 1, 6)), isFalse);
    expect(c.coversDay(DateTime(2026, 1, 18)), isTrue);
    expect(c.coversDay(DateTime(2026, 1, 19)), isFalse);
  });

  test('钉日优先于均摊', () {
    final c = PlanCycle(start: DateTime(2026, 1, 5), weeks: 4, perWeek: 3, pinnedDays: [2, 4]);
    expect(c.weekdays, [2, 4]);
    expect(c.isTrainingDay(DateTime(2026, 1, 6)), isTrue); // 周二
    expect(c.isTrainingDay(DateTime(2026, 1, 5)), isFalse); // 周一不在钉日
  });

  test('JSON 往返 + 续轮', () {
    final c = PlanCycle(
        start: DateTime(2026, 2, 3), weeks: 8, perWeek: 3, pinnedDays: [1, 3, 5], round: 2);
    final b = PlanCycle.fromJson(c.toJson());
    expect(b.start.day, 3);
    expect(b.weeks, 8);
    expect(b.perWeek, 3);
    expect(b.pinnedDays, [1, 3, 5]);
    expect(b.round, 2);
    final nr = c.nextRound();
    expect(nr.round, 3);
    expect(nr.start, c.endExclusive);
    expect(nr.weeks, 8);
  });

  test('状态接线：周期日命中排期；旧周计划仍生效；续轮/清除', () {
    final id = fit.createRoutine('Push');
    fit.togglePlanDay(DateTime.monday, id); // 旧：每周一
    final start = PlanCycle.dayOnly(DateTime.now());
    fit.setCycle(id,
        PlanCycle(start: start, weeks: 4, perWeek: 2, pinnedDays: [DateTime.tuesday]));

    var tue = start;
    while (tue.weekday != DateTime.tuesday) {
      tue = tue.add(const Duration(days: 1));
    }
    var wed = start;
    while (wed.weekday != DateTime.wednesday) {
      wed = wed.add(const Duration(days: 1));
    }
    expect(fit.routinesOn(tue).any((r) => r.id == id), isTrue); // 周期钉日
    expect(fit.routinesOn(wed).any((r) => r.id == id), isFalse);

    expect(fit.cycleExpected(id), 8);
    expect(fit.cycleDoneSessions(id), 0);

    fit.advanceCycle(id);
    expect(fit.cycleOf(id)!.round, 2);
    fit.clearCycle(id);
    expect(fit.cycleOf(id), isNull);
  });

  test('持久化：planCycles 进入 toJson 且可备份恢复', () {
    final id = fit.createRoutine('Legs');
    fit.setCycle(id, PlanCycle(start: DateTime(2026, 3, 2), weeks: 6, perWeek: 4));
    final backup = fit.toJson();
    expect((backup['planCycles'] as Map).containsKey(id), isTrue);

    fit.resetAllData();
    expect(fit.planCycles, isEmpty);
    fit.applyBackup(backup);
    expect(fit.cycleOf(id), isNotNull);
    expect(fit.cycleOf(id)!.weeks, 6);
    expect(fit.cycleOf(id)!.perWeek, 4);
  });
}
