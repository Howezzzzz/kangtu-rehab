// ISS-024 回归：上游同步（并集合并半成品）触及的两处数据模型一致性
//   ① LoggedSession：上游新增 name / durationSec 可写，须与我方康复反馈字段（feel/pain/note）
//      共存于同一份 JSON，且旧版存档（无这些键）仍可安全读回
//   ② LibraryState.allExercises：须同时覆盖 kExercises / kExercisesExt / kExercisesRep 三源，
//      且上游的副肌群覆写（secondaryOverride）在结果里生效、resetSecondary 可还原
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/catalog/exercise_catalog.dart';
import 'package:gymmane/catalog/exercises_ext.dart';
import 'package:gymmane/catalog/exercises_rep.dart';
import 'package:gymmane/models/exercise.dart';
import 'package:gymmane/models/nutrition.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/plan_cycle.dart';
import 'package:gymmane/models/progression.dart';
import 'package:gymmane/models/workout.dart';
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
  });

  group('ISS-024 LoggedSession 模型（上游 name + 我方反馈字段共存）', () {
    test('name 与 feel/pain/note 同时写进 JSON 并能读回', () {
      final s = LoggedSession(DateTime(2026, 1, 2, 12), 600, const [],
          name: '晨练', feel: 1, painArea: 'lowback', painLevel: 3, note: '还行');
      final j = s.toJson();
      expect(j['n'], '晨练');
      expect(j['feel'], 1);
      expect(j['pa'], 'lowback');
      expect(j['pl'], 3);
      expect(j['note'], '还行');

      final back =
          LoggedSession.fromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>);
      expect(back.name, '晨练');
      expect(back.durationSec, 600);
      expect(back.feel, 1);
      expect(back.painArea, 'lowback');
      expect(back.painLevel, 3);
      expect(back.note, '还行');
    });

    test('没有 name / 没有反馈时不写多余键', () {
      final j = LoggedSession(DateTime(2026, 1, 2, 12), 0, const []).toJson();
      expect(j.containsKey('n'), isFalse);
      expect(j.containsKey('feel'), isFalse);
      expect(j.containsKey('pa'), isFalse);
      expect(j.containsKey('pl'), isFalse);
      expect(j.containsKey('note'), isFalse);
    });

    test('旧版存档（无 n / feel 等键）仍可安全读回', () {
      final legacy = LoggedSession.fromJson({
        'd': '2026-01-02T12:00:00.000',
        'dur': 120,
        'ex': <dynamic>[],
      });
      expect(legacy.name, isNull);
      expect(legacy.durationSec, 120);
      expect(legacy.feel, isNull);
      expect(legacy.painArea, '');
      expect(legacy.painLevel, 0);
      expect(legacy.note, '');
    });

    test('durationSec 可写；非法值被忽略', () {
      final s = LoggedSession(DateTime(2026, 1, 3, 12), 100, const []);
      fit.sessions.add(s);
      fit.setSessionDuration(s, 750);
      expect(s.durationSec, 750);
      fit.setSessionDuration(s, -5);
      expect(s.durationSec, 750);
    });

    test('renameSession 改名（trim）；空名还原为 null', () {
      final s = LoggedSession(DateTime(2026, 1, 3, 12), 100, const []);
      fit.sessions.add(s);
      fit.renameSession(s, '  腿部日  ');
      expect(s.name, '腿部日');
      fit.renameSession(s, '   ');
      expect(s.name, isNull);
    });
  });

  group('ISS-024 动作库 allExercises 三源 + 副肌群覆写', () {
    test('三源（kExercises / Ext / Rep）都在结果里', () {
      final ids = fit.allExercises.map((e) => e.id).toSet();
      expect(ids.contains(kExercises.first.id), isTrue);
      expect(ids.contains(kExercisesExt.first.id), isTrue);
      expect(ids.contains(kExercisesRep.first.id), isTrue);
    });

    test('setSecondary 覆写已在 allExercises 生效，resetSecondary 还原', () {
      final base = kExercises.first;
      final extra = kMuscles
          .firstWhere((m) => m.id != base.primary && !base.secondary.contains(m.id));

      final before =
          fit.allExercises.firstWhere((e) => e.id == base.id).secondary;
      expect(before, base.secondary);

      fit.setSecondary(base.id, [extra.id]);
      expect(fit.hasSecondaryOverride(base.id), isTrue);
      expect(
          fit.allExercises.firstWhere((e) => e.id == base.id).secondary,
          contains(extra.id));

      fit.resetSecondary(base.id);
      expect(fit.hasSecondaryOverride(base.id), isFalse);
      expect(fit.allExercises.firstWhere((e) => e.id == base.id).secondary,
          base.secondary);
    });
  });

  // ISS-126 回归：上游本批把「训练日期」语义改为「按开始日计」
  //   （LoggedSession.day = date - durationSec，date 为结束时刻）。
  //   跨午夜训练必须归到「开始日」，且定制模块（日志/日详情/Plan Cycle 计数）与新语义一致。
  group('ISS-126 上游 date→day 语义迁移（按开始日计训练）', () {
    test('day = date - durationSec（跨午夜落到开始日）', () {
      final end = DateTime(2026, 10, 13, 0, 30); // 10/12 23:30 开始
      final s = LoggedSession(end, 3600, const []);
      expect(s.day, DateTime(2026, 10, 12, 23, 30));
    });

    test('日详情按开始日归组（跨午夜训练算在开始日）', () {
      fit.sessions.add(LoggedSession(DateTime(2026, 10, 13, 0, 30), 3600, const []));
      expect(fit.daySummary(DateTime(2026, 10, 12)), isNotNull); // 开始日有训练
      expect(fit.daySummary(DateTime(2026, 10, 13)), isNull); // 结束日为空
    });

    test('周期已完成计数按开始日（cycleDoneSessions）', () {
      final id = fit.createRoutine('回归-周期');
      fit.setCycle(id, PlanCycle(start: DateTime(2026, 10, 1), weeks: 4, perWeek: 3));
      fit.sessions.add(
          LoggedSession(DateTime(2026, 10, 13, 0, 30), 3600, const [], routineId: id));
      expect(fit.cycleDoneSessions(id), 1);
    });
  });

  // ISS-151 回归：归档带「排期周期(Plan Cycle)」的例程须从 routinesOn 摘除
  //   上游新增的 archiveRoutine 只清 weeklyPlan/planExtras/rotation，未清我方 planCycles
  //   → 归档后仍被 planCycles 补入、永久占位，叠加「一天全部完成才打勾」新语义则该天永远打不了勾。
  group('ISS-151 归档 × 周期引擎交互', () {
    test('归档带 cycle 的例程后不再出现在 routinesOn；取消归档后恢复', () {
      final id = fit.createRoutine('归档-周期');
      final start = PlanCycle.dayOnly(DateTime.now());
      fit.setCycle(id, PlanCycle(start: start, weeks: 4, perWeek: 7)); // 每天都是训练日
      expect(fit.routinesOn(start).any((r) => r.id == id), isTrue);
      fit.archiveRoutine(id, true);
      expect(fit.routinesOn(start).any((r) => r.id == id), isFalse); // 不再占位
      fit.archiveRoutine(id, false);
      expect(fit.routinesOn(start).any((r) => r.id == id), isTrue); // 取消归档恢复
    });

    test('删除带 cycle 的例程会清掉 planCycles 僵尸键', () {
      final id = fit.createRoutine('删除-周期');
      fit.setCycle(id, PlanCycle(start: DateTime(2026, 10, 1), weeks: 4, perWeek: 3));
      expect(fit.cycleOf(id), isNotNull);
      fit.deleteRoutine(id);
      expect(fit.cycleOf(id), isNull);
    });
  });

  // ISS-152 回归：计划周期(prog)驱动的动作，nextWhy 不得再落进「保持」误导文案
  //   （nextTargetLabel 已显示正确重量×次数，只有「为什么」文案在说谎）
  group('ISS-152 prog 驱动动作的 nextWhy 文案', () {
    test('带 prog 的例程开练后 nextWhy 返回「按计划执行」而非「保持」', () {
      final id = fit.createRoutine('prog-回归');
      final exId = fit.matchExerciseByName('Barbell Bench Press')!.id;
      fit.toggleRoutineExercise(id, exId);
      final r = fit.routines.firstWhere((x) => x.id == id);
      r.prog[exId] = const ProgSpec(kind: ProgKind.linear, sets: 3, reps: 5, stepKg: 2.5);
      fit.startRoutine(r);
      expect(fit.nextWhy(exId), t.nextByPlan);
      expect(fit.nextWhy(exId), isNot(t.nextHold));
      fit.saveAndExit();
    });
  });

  // ISS-153 回归：从例程移除动作时须清掉其 ProgSpec
  //   （否则孤儿 spec 会被周期重建循环继续写 plan）
  group('ISS-153 移除动作清 ProgSpec', () {
    test('toggleRoutineExercise 移除后 routine.prog 不再含该动作', () {
      final id = fit.createRoutine('孤儿-回归');
      final exId = fit.matchExerciseByName('Barbell Bench Press')!.id;
      fit.toggleRoutineExercise(id, exId);
      final r = fit.routines.firstWhere((x) => x.id == id);
      r.prog[exId] = const ProgSpec(kind: ProgKind.linear, sets: 3, reps: 5);
      expect(r.prog.containsKey(exId), isTrue);
      fit.toggleRoutineExercise(id, exId); // 移除
      expect(r.prog.containsKey(exId), isFalse);
    });
  });

  // ISS-154 回归：prog 计划驱动的动作，开场组不得被上游 ProgressRule 改写
  //   （旧实现 _beginSession 先建开场组后挂 session，且 _drivesReps 无 prog 例外）
  group('ISS-154 prog 计划优先于上游规则（开场组）', () {
    test('带 prog + 开启上游规则的例程，开场组沿用计划重量×次数', () {
      final id = fit.createRoutine('P');
      final exId = fit.matchExerciseByName('Barbell Bench Press')!.id;
      fit.toggleRoutineExercise(id, exId);
      final r = fit.routines.firstWhere((x) => x.id == id);
      r.prog[exId] = const ProgSpec(kind: ProgKind.linear, sets: 3, reps: 5, stepKg: 2.5);
      fit.setPlannedSets(
          id, exId, [for (var i = 0; i < 3; i++) const PlannedSet(reps: 5, weightKg: 100)]);
      // 同时开启上游规则（若无 prog 例外，会改写为规则算出的值）
      fit.setProgressRule(exId, const ProgressRule(kind: ProgressKind.double, low: 8, high: 12));
      expect(fit.hasProgress(exId), isTrue);
      fit.startRoutine(r);
      final sets = fit.session!.exercises
          .firstWhere((e) => e.id == exId)
          .sets
          .where((s) => s.kind != SetKind.warmup)
          .toList();
      expect(sets.length, 3);
      expect(sets.every((s) => s.reps == 5 && s.weight == 100), isTrue,
          reason: '开场组应沿用 prog 计划值 5×100，而非上游规则值');
      fit.saveAndExit();
    });
  });

  // ISS-155：prog 计划引擎与上游 ProgressRule 解耦（不再共享 progressStep）+ 遗留修复
  group('ISS-155 prog 与上游解耦', () {
    test('replaceRoutineExercise 迁移 prog，不留孤儿 spec', () {
      final id = fit.createRoutine('S');
      final a = fit.matchExerciseByName('Barbell Bench Press')!.id;
      final b = fit.matchExerciseByName('Barbell Full Squat')!.id;
      expect(a, isNot(b));
      fit.toggleRoutineExercise(id, a);
      final r = fit.routines.firstWhere((x) => x.id == id);
      r.prog[a] = const ProgSpec(kind: ProgKind.linear, sets: 3, reps: 5);
      fit.replaceRoutineExercise(id, a, b);
      expect(r.prog.containsKey(a), isFalse);
      expect(r.prog[b]?.reps, 5);
    });

    test('bumpProgStep 只改 spec.stepKg，不动上游 progressStep', () {
      final id = fit.createRoutine('T');
      final exId = fit.matchExerciseByName('Barbell Bench Press')!.id;
      fit.toggleRoutineExercise(id, exId);
      final r = fit.routines.firstWhere((x) => x.id == id);
      r.prog[exId] = const ProgSpec(kind: ProgKind.linear, sets: 3, reps: 5, stepKg: 2.5);
      fit.setProgressRule(exId, const ProgressRule(kind: ProgressKind.double, low: 8, high: 12));
      final upstream = fit.progressStep[exId];
      fit.bumpProgStep(exId, 1);
      expect(fit.progStepOf(exId), closeTo(3.75, 1e-9));
      expect(fit.progressStep[exId], upstream);
    });

    test('启动冻结迁移：共享 step 固化进 spec.stepKg 且只跑一次', () {
      final id = fit.createRoutine('F');
      final exId = fit.matchExerciseByName('Barbell Bench Press')!.id;
      fit.toggleRoutineExercise(id, exId);
      var r = fit.routines.firstWhere((x) => x.id == id);
      r.prog[exId] = const ProgSpec(kind: ProgKind.linear, sets: 3, reps: 5);
      fit.setProgressRule(exId, const ProgressRule(kind: ProgressKind.double, low: 8, high: 12));
      fit.bumpProgressStep(exId, 1); // 2.5 → 3.75
      expect(fit.progressStep[exId], closeTo(3.75, 1e-9));
      fit.saveAndExit();
      fit.loadFromStore();
      r = fit.routines.firstWhere((x) => x.id == id);
      expect(r.prog[exId]!.stepKg, closeTo(3.75, 1e-9));
      r.prog[exId] = r.prog[exId]!.copyWith(stepKg: 1.0);
      fit.saveAndExit();
      fit.loadFromStore();
      r = fit.routines.firstWhere((x) => x.id == id);
      expect(r.prog[exId]!.stepKg, closeTo(1.0, 1e-9)); // 二次启动不再被 progressStep 覆盖
    });

    test('计划非首组重量缺省沿用首组，不再变 0', () {
      final id = fit.createRoutine('W');
      final exId = fit.matchExerciseByName('Barbell Bench Press')!.id;
      fit.toggleRoutineExercise(id, exId);
      final r = fit.routines.firstWhere((x) => x.id == id);
      r.prog[exId] = const ProgSpec(kind: ProgKind.linear, sets: 3, reps: 5, stepKg: 2.5);
      fit.setPlannedSets(id, exId, const [
        PlannedSet(reps: 5, weightKg: 100),
        PlannedSet(reps: 5),
        PlannedSet(reps: 5),
      ]);
      // 造历史（未设 progInst → runProgression 早退，plan 的混合重量得以保留）
      fit.startRoutine(r);
      for (final e in fit.session!.exercises) {
        for (final st in e.sets) {
          st.done = true;
        }
      }
      fit.finishSession();
      fit.saveAndExit();
      // 自由训练：prog 驱动 + 开了上游规则 → 走 _nextPlan 的 prog 分支
      fit.setProgressRule(exId, const ProgressRule(kind: ProgressKind.double, low: 8, high: 12));
      expect(fit.hasProgress(exId), isTrue);
      fit.sessionPicks.add(exId);
      fit.startSession();
      final sets = fit.session!.exercises
          .firstWhere((e) => e.id == exId)
          .sets
          .where((s) => s.kind != SetKind.warmup)
          .toList();
      expect(sets.length, 3);
      expect(sets.every((s) => s.weight == 100), isTrue,
          reason: '缺省重量应沿用首组 100，而不是 0');
      fit.saveAndExit();
    });

    test('removeRoutineExercise 撤销一并恢复 prog', () {
      final id = fit.createRoutine('U');
      final exId = fit.matchExerciseByName('Barbell Bench Press')!.id;
      fit.toggleRoutineExercise(id, exId);
      final r = fit.routines.firstWhere((x) => x.id == id);
      r.prog[exId] = const ProgSpec(kind: ProgKind.linear, sets: 3, reps: 5);
      final undo = fit.removeRoutineExercise(id, exId);
      expect(undo, isNotNull);
      expect(r.prog.containsKey(exId), isFalse);
      undo!();
      expect(r.prog[exId]?.reps, 5);
    });
  });

  // ISS-155 双引擎收尾（RISK-043/045/047/049/050/051）回归
  group('ISS-155 双引擎收尾', () {
    test('duplicateRoutine 复制计划配置并建独立实例（进度克隆）', () {
      final id = fit.createRoutine('D');
      final exId = fit.matchExerciseByName('Barbell Bench Press')!.id;
      fit.toggleRoutineExercise(id, exId);
      final src = fit.routines.firstWhere((x) => x.id == id);
      src.prog[exId] = const ProgSpec(kind: ProgKind.linear, sets: 3, reps: 5);
      src.progInst = 'piSrc';
      fit.programStates['piSrc'] = ProgState(tpl: 'tpl')..w[exId] = 80;
      final copyId = fit.duplicateRoutine(id);
      final cp = fit.routines.firstWhere((x) => x.id == copyId);
      expect(cp.prog.containsKey(exId), isTrue);
      expect(cp.progInst, isNotNull);
      expect(cp.progInst, isNot('piSrc'));
      expect(fit.programStates[cp.progInst!]!.w[exId], 80);
    });

    test('prog 动作改组数写入 spec.sets（不被 rebuild 抹掉）', () {
      final id = fit.createRoutine('B');
      final exId = fit.matchExerciseByName('Barbell Bench Press')!.id;
      fit.toggleRoutineExercise(id, exId);
      final r = fit.routines.firstWhere((x) => x.id == id);
      r.prog[exId] = const ProgSpec(kind: ProgKind.linear, sets: 3, reps: 5);
      fit.bumpRoutineSets(id, exId, 1);
      expect(r.prog[exId]!.sets, 4);
      expect(r.sets[exId], 4);
      expect(r.plan[exId]?.length, 4); // 立刻重建，改了即生效（勿留到下次开练）
    });

    test('重建计划保留用户手加的热身组', () {
      final id = fit.createRoutine('W2');
      final exId = fit.matchExerciseByName('Barbell Bench Press')!.id;
      fit.toggleRoutineExercise(id, exId);
      final r = fit.routines.firstWhere((x) => x.id == id);
      r.plan[exId] = const [
        PlannedSet(kind: SetKind.warmup, reps: 10, weightKg: 40),
        PlannedSet(reps: 5, weightKg: 100),
      ];
      rebuildSimplePlan(r, exId, const ProgSpec(kind: ProgKind.linear, sets: 3, reps: 5),
          weight: 100);
      final plan = r.plan[exId]!;
      expect(plan.where((p) => p.kind == SetKind.warmup).length, 1);
      expect(plan.where((p) => p.kind != SetKind.warmup).length, 3);
    });

    test('prog 驱动且计划暂无重量时，不回落到上游规则', () {
      final id = fit.createRoutine('N');
      final exId = fit.matchExerciseByName('Barbell Bench Press')!.id;
      fit.toggleRoutineExercise(id, exId);
      final r = fit.routines.firstWhere((x) => x.id == id);
      r.prog[exId] = const ProgSpec(kind: ProgKind.linear, sets: 3, reps: 5);
      fit.setPlannedSets(
          id, exId, const [PlannedSet(reps: 5), PlannedSet(reps: 5), PlannedSet(reps: 5)]);
      fit.startRoutine(r);
      for (final e in fit.session!.exercises) {
        for (final st in e.sets) {
          st.done = true;
        }
      }
      fit.finishSession();
      fit.saveAndExit();
      fit.setProgressRule(exId, const ProgressRule(kind: ProgressKind.double, low: 8, high: 12));
      expect(fit.nextTarget(exId), isNull);
    });

    test('周期动作 TM：手调写回实例并重建 plan，未确认提示随之消失', () {
      final id = fit.createRoutine('C');
      final exId = fit.matchExerciseByName('Barbell Front Squat')!.id;
      fit.toggleRoutineExercise(id, exId);
      final r = fit.routines.firstWhere((x) => x.id == id);
      r.prog[exId] = const ProgSpec(
        kind: ProgKind.cycle,
        sets: 3,
        reps: 5,
        weeks: [
          [CycleSet(5, 0.65), CycleSet(5, 0.75), CycleSet(5, 0.85)],
        ],
      );
      r.progInst = 'piC';
      fit.programStates['piC'] = ProgState(tpl: 't');
      expect(fit.progTmUnconfirmed(exId), isTrue); // 还是默认 40 → 提示未确认
      fit.bumpProgTm(exId, 1);
      expect(fit.programStates['piC']!.tm[exId], greaterThan(40));
      expect(fit.progTmUnconfirmed(exId), isFalse);
      final plan = r.plan[exId]!;
      expect(plan.length, 3);
      expect(plan.first.weightKg, greaterThan(0));
    });

    test('换动作时把渐进状态迁到新动作（cycle TM 不回落 40）', () {
      final id = fit.createRoutine('X');
      final a = fit.matchExerciseByName('Barbell Bench Press')!.id;
      final b = fit.matchExerciseByName('Barbell Full Squat')!.id;
      fit.toggleRoutineExercise(id, a);
      final r = fit.routines.firstWhere((x) => x.id == id);
      r.prog[a] =
          const ProgSpec(kind: ProgKind.cycle, sets: 3, reps: 5, weeks: [
        [CycleSet(5, 0.65)],
      ]);
      r.progInst = 'piX';
      fit.programStates['piX'] = ProgState(tpl: 't')..tm[a] = 120;
      fit.replaceRoutineExercise(id, a, b);
      expect(fit.programStates['piX']!.tm[b], 120);
      expect(fit.progTmOf(b), 120);
    });

    test('复制例程后会话外仍识别为计划驱动（不回落到上游）', () {
      final id = fit.createRoutine('Y');
      final exId = fit.matchExerciseByName('Barbell Bench Press')!.id;
      fit.toggleRoutineExercise(id, exId);
      final r = fit.routines.firstWhere((x) => x.id == id);
      r.prog[exId] = const ProgSpec(kind: ProgKind.linear, sets: 3, reps: 5);
      fit.setPlannedSets(id, exId,
          const [PlannedSet(reps: 5, weightKg: 100), PlannedSet(reps: 5, weightKg: 100)]);
      fit.duplicateRoutine(id); // 现在两个例程都带 prog
      fit.setProgressRule(exId, const ProgressRule(kind: ProgressKind.linear, low: 8, high: 12));
      final t = fit.nextTarget(exId);
      expect(t, isNotNull);
      expect(t!.weightKg, 100);
    });

    test('TM 手调后不再显示“未确认”（即使值恰为 40）', () {
      final id = fit.createRoutine('TC');
      final exId = fit.matchExerciseByName('Barbell Front Squat')!.id;
      fit.toggleRoutineExercise(id, exId);
      final r = fit.routines.firstWhere((x) => x.id == id);
      r.prog[exId] = const ProgSpec(kind: ProgKind.cycle, sets: 3, reps: 5, weeks: [
        [CycleSet(5, 0.65)],
      ]);
      r.progInst = 'piTC';
      fit.programStates['piTC'] = ProgState(tpl: 't');
      expect(fit.progTmUnconfirmed(exId), isTrue);
      fit.bumpProgTm(exId, 1);
      fit.programStates['piTC']!.tm[exId] = 40; // 手调恰为 40 也不应误报
      expect(fit.progTmUnconfirmed(exId), isFalse);
    });

    test('周期动作的组数编辑被忽略（组数由周表决定）', () {
      final id = fit.createRoutine('CS');
      final exId = fit.matchExerciseByName('Barbell Front Squat')!.id;
      fit.toggleRoutineExercise(id, exId);
      final r = fit.routines.firstWhere((x) => x.id == id);
      r.prog[exId] = const ProgSpec(kind: ProgKind.cycle, sets: 3, reps: 5, weeks: [
        [CycleSet(5, 0.65)],
      ]);
      r.progInst = 'piCS';
      fit.programStates['piCS'] = ProgState(tpl: 't');
      final before = r.prog[exId]!.sets;
      fit.bumpRoutineSets(id, exId, 1);
      fit.setRoutineSetCount(id, exId, 8);
      expect(r.prog[exId]!.sets, before);
    });

    test('断训补账：间隔 3 个周期一次补 3 周', () {
      final id = fit.createRoutine('CW');
      final exId = fit.matchExerciseByName('Barbell Full Squat')!.id;
      fit.toggleRoutineExercise(id, exId);
      final r = fit.routines.firstWhere((x) => x.id == id);
      r.prog[exId] = const ProgSpec(kind: ProgKind.cycle, sets: 3, reps: 5, weeks: [
        [CycleSet(5, 0.65)],
        [CycleSet(3, 0.75)],
        [CycleSet(1, 0.85)],
      ]);
      r.progInst = 'piCW';
      final inst = ProgState(tpl: 't')..tm[exId] = 100;
      inst.tmSet.add(exId); // 已确认（未确认的自动值不累积跨轮加量）
      inst.lastAdv = DateTime.now().millisecondsSinceEpoch - 21 * 24 * 3600 * 1000;
      fit.programStates['piCW'] = inst;
      fit.startRoutine(r);
      for (final e in fit.session!.exercises) {
        for (final st in e.sets) {
          st.done = true;
        }
      }
      fit.finishSession();
      expect(inst.week, greaterThanOrEqualTo(3));
      expect(inst.tm[exId], greaterThan(100));
      fit.saveAndExit();
    });

    test('周期家族：完训 A 例程时 B 例程的周期动作也结算 TM', () {
      final a = fit.createRoutine('FA');
      final b = fit.createRoutine('FB');
      final exA = fit.matchExerciseByName('Barbell Bench Press')!.id;
      final exB = fit.matchExerciseByName('Barbell Full Squat')!.id;
      fit.toggleRoutineExercise(a, exA);
      fit.toggleRoutineExercise(b, exB);
      final ra = fit.routines.firstWhere((x) => x.id == a);
      final rb = fit.routines.firstWhere((x) => x.id == b);
      const spec = ProgSpec(kind: ProgKind.cycle, sets: 3, reps: 5, weeks: [
        [CycleSet(5, 0.65)],
        [CycleSet(3, 0.75)],
        [CycleSet(1, 0.85)],
      ]);
      ra.prog[exA] = spec;
      rb.prog[exB] = spec;
      ra.progInst = 'piF';
      rb.progInst = 'piF';
      final inst = ProgState(tpl: 't')
        ..tm[exA] = 100
        ..tm[exB] = 100;
      inst.tmSet
        ..add(exA)
        ..add(exB);
      inst.lastAdv = DateTime.now().millisecondsSinceEpoch - 21 * 24 * 3600 * 1000;
      fit.programStates['piF'] = inst;
      fit.startRoutine(ra);
      for (final e in fit.session!.exercises) {
        for (final st in e.sets) {
          st.done = true;
        }
      }
      fit.finishSession();
      expect(inst.tm[exB], greaterThan(100)); // B 不在本次完训例程，也应结算
      expect(inst.tm[exA], greaterThan(100));
      fit.saveAndExit();
    });

    test('老数据（无 tmSet）按旧启发式判定，不误报未确认', () {
      final id = fit.createRoutine('LG');
      final exId = fit.matchExerciseByName('Barbell Front Squat')!.id;
      fit.toggleRoutineExercise(id, exId);
      final r = fit.routines.firstWhere((x) => x.id == id);
      r.prog[exId] = const ProgSpec(kind: ProgKind.cycle, sets: 3, reps: 5, weeks: [
        [CycleSet(5, 0.65)],
      ]);
      r.progInst = 'piLG';
      fit.programStates['piLG'] = ProgState(tpl: 't')..tm[exId] = 120; // 无 tmSet = 老数据
      expect(fit.progTmUnconfirmed(exId), isFalse);
    });

    test('未确认的自动 TM 不累积跨轮加量', () {
      final id = fit.createRoutine('UC');
      final exId = fit.matchExerciseByName('Barbell Full Squat')!.id;
      fit.toggleRoutineExercise(id, exId);
      final r = fit.routines.firstWhere((x) => x.id == id);
      r.prog[exId] = const ProgSpec(kind: ProgKind.cycle, sets: 3, reps: 5, weeks: [
        [CycleSet(5, 0.65)],
        [CycleSet(3, 0.75)],
        [CycleSet(1, 0.85)],
      ]);
      r.progInst = 'piUC';
      final inst = ProgState(tpl: 't'); // tm 未设、tmSet 空 = 未确认
      inst.lastAdv = DateTime.now().millisecondsSinceEpoch - 21 * 24 * 3600 * 1000;
      fit.programStates['piUC'] = inst;
      fit.startRoutine(r);
      for (final e in fit.session!.exercises) {
        for (final st in e.sets) {
          st.done = true;
        }
      }
      fit.finishSession();
      expect(inst.week, greaterThanOrEqualTo(3));
      expect(inst.tm[exId], estimateTrainingMax(fit, exId) ?? 40); // 只落基值，不因跨轮而连加
      fit.saveAndExit();
    });
  });

  // RISK-040 回归：prog 计划注入时，非首组「留空重量」须沿用计划重量
  //   （旧实现 _workingOpeners 只在有历史时走计划，无历史落到硬编码 20kg）
  group('RISK-040 计划非首组缺省重量', () {
    test('计划只标首组重量 → 其余组沿用首组，不再落到默认 20', () {
      final id = fit.createRoutine('R040');
      final exId = fit.matchExerciseByName('Barbell Bench Press')!.id;
      fit.toggleRoutineExercise(id, exId);
      final r = fit.routines.firstWhere((x) => x.id == id);
      r.prog[exId] = const ProgSpec(kind: ProgKind.linear, sets: 3, reps: 5, stepKg: 2.5);
      fit.setPlannedSets(id, exId, const [
        PlannedSet(reps: 5, weightKg: 100),
        PlannedSet(reps: 5),
        PlannedSet(reps: 5),
      ]);
      fit.startRoutine(r);
      final sets = fit.session!.exercises
          .firstWhere((e) => e.id == exId)
          .sets
          .where((s) => s.kind != SetKind.warmup)
          .toList();
      expect(sets.map((s) => s.weight).toList(), [100.0, 100.0, 100.0]);
      expect(sets.every((s) => s.reps == 5), isTrue);
      fit.saveAndExit();
    });
  });

  // RISK-055 回归：换/删动作时须清掉该动作在渐进实例里的残留状态
  //   （否则换回来会带着过期 TM/重量/失败数复活，残留 tmSet 还会压掉校准提示）
  group('RISK-055 换/删动作清实例残留', () {
    test('换动作后旧动作的实例状态被清，状态播种给新动作', () {
      final id = fit.createRoutine('S055');
      final a = fit.matchExerciseByName('Barbell Bench Press')!.id;
      final b = fit.matchExerciseByName('Barbell Squat')!.id;
      fit.toggleRoutineExercise(id, a);
      final r = fit.routines.firstWhere((x) => x.id == id);
      r.prog[a] = const ProgSpec(kind: ProgKind.linear, sets: 3, reps: 5);
      r.progInst = 'piT055';
      final inst = ProgState(tpl: 't');
      inst.w[a] = 77.5;
      inst.fails[a] = 2;
      inst.tmSet.add(a);
      fit.programStates['piT055'] = inst;

      fit.replaceRoutineExercise(id, a, b);

      expect(inst.w.containsKey(a), isFalse, reason: '换走的旧动作残留工作重量');
      expect(inst.fails.containsKey(a), isFalse, reason: '换走的旧动作残留失败数');
      expect(inst.tmSet.contains(a), isFalse, reason: '残留 tmSet 会压掉「TM 偏低」校准提示');
      expect(inst.w.containsKey(b) || inst.tm.containsKey(b), isTrue, reason: '新动作应被播种状态');
      fit.saveAndExit();
    });

    test('同实例还有别的例程在用该动作 → 不误清', () {
      final a = fit.matchExerciseByName('Barbell Bench Press')!.id;
      final b = fit.matchExerciseByName('Barbell Squat')!.id;
      final id1 = fit.createRoutine('S1');
      final id2 = fit.createRoutine('S2');
      fit.toggleRoutineExercise(id1, a);
      fit.toggleRoutineExercise(id2, a);
      final r1 = fit.routines.firstWhere((x) => x.id == id1);
      final r2 = fit.routines.firstWhere((x) => x.id == id2);
      r1.prog[a] = const ProgSpec(kind: ProgKind.linear, sets: 3, reps: 5);
      r1.progInst = 'piShare';
      r2.progInst = 'piShare';
      final inst = ProgState(tpl: 't');
      inst.w[a] = 80;
      fit.programStates['piShare'] = inst;

      fit.replaceRoutineExercise(id1, a, b);

      expect(inst.w[a], 80, reason: '另一个例程仍在用该动作，不该清');
      fit.saveAndExit();
    });

    test('移除动作后撤销 → 实例状态完整还原', () {
      final id = fit.createRoutine('S2u');
      final a = fit.matchExerciseByName('Barbell Bench Press')!.id;
      fit.toggleRoutineExercise(id, a);
      final r = fit.routines.firstWhere((x) => x.id == id);
      r.prog[a] = const ProgSpec(kind: ProgKind.linear, sets: 3, reps: 5);
      r.progInst = 'piU';
      final inst = ProgState(tpl: 't');
      inst.w[a] = 90;
      inst.tm[a] = 100;
      inst.fails[a] = 1;
      inst.reps[a] = 6;
      inst.tmSet.add(a);
      fit.programStates['piU'] = inst;

      final undo = fit.removeRoutineExercise(id, a);
      expect(undo, isNotNull);
      expect(inst.w.containsKey(a), isFalse, reason: '移除后应清残留');

      undo!();
      expect(inst.w[a], 90);
      expect(inst.tm[a], 100);
      expect(inst.fails[a], 1);
      expect(inst.reps[a], 6);
      expect(inst.tmSet.contains(a), isTrue);
      fit.saveAndExit();
    });
  });

  // RISK-064 回归：渐进实例按「实例」隔离——清一个实例的残留不得跨实例误伤
  group('RISK-064 渐进实例隔离', () {
    test('同一动作挂在不同实例上 → 清 piA 不影响 piB', () {
      final a = fit.matchExerciseByName('Barbell Bench Press')!.id;
      final b = fit.matchExerciseByName('Barbell Squat')!.id;
      final id1 = fit.createRoutine('X1');
      final id2 = fit.createRoutine('X2');
      fit.toggleRoutineExercise(id1, a);
      fit.toggleRoutineExercise(id2, a);
      final r1 = fit.routines.firstWhere((x) => x.id == id1);
      final r2 = fit.routines.firstWhere((x) => x.id == id2);
      r1.prog[a] = const ProgSpec(kind: ProgKind.linear, sets: 3, reps: 5);
      r1.progInst = 'piA';
      r2.progInst = 'piB';
      final i1 = ProgState(tpl: 't')..w[a] = 70;
      final i2 = ProgState(tpl: 't')..w[a] = 85;
      fit.programStates['piA'] = i1;
      fit.programStates['piB'] = i2;

      fit.replaceRoutineExercise(id1, a, b); // 只该清 piA 里的 a

      expect(i1.w.containsKey(a), isFalse, reason: 'piA 里的 a 该清');
      expect(i2.w[a], 85, reason: 'piB 里的 a 不该被跨实例误清');
      fit.saveAndExit();
    });
  });

  // RISK-065 回归：开场组解析改动的「其它路径」行为护栏
  //   （本次只让 prog 驱动无历史也走计划，不得波及非计划/纯次数等旧行为）
  group('RISK-065 开场组非计划路径保持', () {
    test('普通例程（无计划无历史）→ 默认 20kg', () {
      final id = fit.createRoutine('O1');
      final exId = fit.matchExerciseByName('Barbell Bench Press')!.id;
      fit.toggleRoutineExercise(id, exId);
      final r = fit.routines.firstWhere((x) => x.id == id);
      fit.startRoutine(r);
      final sets = fit.session!.exercises.firstWhere((e) => e.id == exId).sets;
      expect(sets.isNotEmpty, isTrue);
      expect(sets.every((s) => s.weight == 20.0), isTrue, reason: '无计划无历史应保持默认 20kg');
      fit.saveAndExit();
    });

    test('prog 计划重量全为空 → 回落默认 20kg（不显示 0）', () {
      final id = fit.createRoutine('O2');
      final exId = fit.matchExerciseByName('Barbell Bench Press')!.id;
      fit.toggleRoutineExercise(id, exId);
      final r = fit.routines.firstWhere((x) => x.id == id);
      r.prog[exId] = const ProgSpec(kind: ProgKind.linear, sets: 3, reps: 5);
      fit.setPlannedSets(id, exId, const [PlannedSet(reps: 5), PlannedSet(reps: 5), PlannedSet(reps: 5)]);
      fit.startRoutine(r);
      final sets = fit.session!.exercises
          .firstWhere((e) => e.id == exId)
          .sets
          .where((s) => s.kind != SetKind.warmup)
          .toList();
      expect(sets.every((s) => s.weight == 20.0), isTrue, reason: '计划无重量应回落默认，而非 0');
      fit.saveAndExit();
    });

    test('纯次数动作（无历史无计划）→ 0kg 自重', () {
      final id = fit.createRoutine('O3');
      final exId = fit.matchExerciseByName('Barbell Bench Press')!.id;
      fit.toggleRoutineExercise(id, exId);
      fit.repsOnly.add(exId);
      final r = fit.routines.firstWhere((x) => x.id == id);
      fit.startRoutine(r);
      final sets = fit.session!.exercises.firstWhere((e) => e.id == exId).sets;
      expect(sets.every((s) => s.weight == 0.0), isTrue, reason: '纯次数动作应 0kg 自重');
      fit.saveAndExit();
    });
  });

  // RISK-060 审出的小卫生问题：切数据源（清除数据/恢复备份）须重置「选中的餐」
  group('RISK-060 审出项：选中餐随数据源重置', () {
    test('loadNutrition 后 pickedMeal 归零', () {
      fit.pickMeal(Meal.lunch);
      expect(fit.pickedMeal, Meal.lunch);
      fit.loadNutrition(null);
      expect(fit.pickedMeal, isNull, reason: '切数据源后应清掉选中餐');
    });
  });
}
