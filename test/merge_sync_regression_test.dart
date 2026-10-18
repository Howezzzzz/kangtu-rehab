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
import 'package:gymmane/models/plan_cycle.dart';
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
}
