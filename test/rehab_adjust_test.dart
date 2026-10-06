import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/rehab_episode.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/services/rehab_intake.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    setAppLanguage('zh');
    fit.resetAllData();
    fit.setUnits('kg');
  });

  RehabEpisode episode({List<String> flags = const []}) => RehabEpisode(
        id: 're1',
        title: '腰部康复',
        createdAt: DateTime.now(),
        area: 'lowback',
        duration: 'sub',
        pain: 4,
        redFlags: flags,
        factors: '久坐加重',
        goals: const ['pain'],
        equipment: const ['Bodyweight'],
        daysPerWeek: 3,
      );

  String benchId() => fit.matchExerciseByName('Barbell Bench Press')!.id;
  String bridgeId() => fit.matchExerciseByName('Glute Bridge')!.id;

  String makeRoutine(String name, {bool withPlan = false}) {
    final id = fit.createRoutine(name);
    fit.toggleRoutineExercise(id, benchId());
    if (withPlan) {
      fit.setPlannedSets(id, benchId(), const [
        PlannedSet(reps: 10, weightKg: 60),
        PlannedSet(kind: SetKind.warmup, reps: 12, weightKg: 20),
        PlannedSet(reps: 8, weightKg: 60),
      ]);
    }
    return id;
  }

  void logSession({
    required int daysAgo,
    int? feel,
    String painArea = '',
    int painLevel = 0,
    String note = '',
  }) {
    fit.sessions.add(LoggedSession(
      DateTime.now().subtract(Duration(days: daysAgo)),
      1800,
      [LoggedExercise(benchId(), 'Barbell Bench Press', 'chest', [LoggedSet(8, 60)])],
      feel: feel,
      painArea: painArea,
      painLevel: painLevel,
      note: note,
    ));
  }

  RehabEpisode linked({List<String> flags = const []}) {
    final ep = episode(flags: flags);
    ep.routineIds = [makeRoutine('康复 A', withPlan: true)];
    fit.createEpisode(ep);
    return ep;
  }

  Routine routineA() =>
      fit.routines.singleWhere((r) => r.id == fit.episodeById('re1')!.routineIds.first);

  group('提示词：当前计划块', () {
    test('无关联计划时写明暂无计划', () {
      final text = fit.rehabPromptText(episode());
      expect(text, contains('【当前计划】'));
      expect(text, contains('暂无计划'));
    });

    test('有关联计划时附上计划快照（含计划名与动作名）', () {
      final ep = episode()..routineIds = [makeRoutine('康复 A')];
      fit.createEpisode(ep);
      final text = fit.rehabPromptText(ep);
      expect(text, contains('【当前计划】'));
      expect(text, contains('康复 A'));
      expect(text, contains('Barbell Bench Press'));
    });
  });

  group('提示词：近期训练反馈块', () {
    test('近 7 天的反馈逐条展示（感觉/部位/程度/备注）', () {
      logSession(daysAgo: 0, feel: 1, painArea: 'back', painLevel: 3, note: '腰部有点紧');
      final text = fit.rehabPromptText(episode());
      expect(text, contains('【近期训练反馈】'));
      expect(text, contains('刚好'));
      expect(text, contains('3/10'));
      expect(text, contains('腰部有点紧'));
    });

    test('7 天内无反馈不展示，更早的只取最近 3 次', () {
      logSession(daysAgo: 2, note: ''); // 无反馈，忽略
      logSession(daysAgo: 10, feel: 0, note: '最近一条');
      logSession(daysAgo: 12, feel: 0, note: '次近一条');
      logSession(daysAgo: 14, feel: 0, note: '再次近');
      logSession(daysAgo: 16, feel: 0, note: '最旧一条'); // 超出 3 次，被截掉
      final text = fit.rehabPromptText(episode());
      expect(text, contains('最近一条'));
      expect(text, contains('次近一条'));
      expect(text, contains('再次近'));
      expect(text, isNot(contains('最旧一条')));
    });

    test('7 天整的反馈算窗口之外（保守边界）', () {
      logSession(daysAgo: 7, feel: 0, note: '七天前整');
      logSession(daysAgo: 6, feel: 0, note: '六天前');
      final text = fit.rehabPromptText(episode());
      expect(text, contains('六天前'));
      expect(text, isNot(contains('七天前整')));
    });

    test('完全没有反馈时写明无反馈记录', () {
      final text = fit.rehabPromptText(episode());
      expect(text, contains('无训练反馈记录'));
    });
  });

  group('提示词：输出要求含 adjust 规格', () {
    test('写清 adjust 数组结构、字段白名单和默认行为', () {
      final text = fit.rehabPromptText(episode());
      expect(text, contains('adjust 数组'));
      expect(text, contains('"action":"set"'));
      expect(text, contains('"field":"weight"'));
      expect(text, contains('weight / sets / reps / rest'));
      expect(text, contains('省略 = 应用到全部当前计划'));
    });
  });

  group('extractRehabAdjust 解析', () {
    test('解析 set / remove / add 及 routine 限定', () {
      const raw = '{"advice": "x", "adjust": ['
          '{"action":"set","routine":"康复 A","exercise":"Barbell Bench Press","field":"weight","value":45},'
          '{"action":"set","exercise":"Barbell Bench Press","field":"sets","value":3},'
          '{"action":"remove","exercise":"Skull Crusher"},'
          '{"action":"add","routine":"康复 A","exercise":"Glute Bridge","sets":3,"reps":12}]}';
      final out = extractRehabAdjust(raw);
      expect(out.length, 4);
      expect(out[0].action, 'set');
      expect(out[0].target, '康复 A');
      expect(out[0].exercise, 'Barbell Bench Press');
      expect(out[0].field, 'weight');
      expect(out[0].value, 45);
      expect(out[1].target, '');
      expect(out[2].action, 'remove');
      expect(out[3].action, 'add');
      expect(out[3].addSets, 3);
      expect(out[3].addReps, 12);
    });

    test('没有 adjust（或空数组）时返回空列表', () {
      expect(extractRehabAdjust('{"advice": "x"}'), isEmpty);
      expect(extractRehabAdjust('{"advice": "x", "adjust": []}'), isEmpty);
      expect(extractRehabAdjust('完全不是 JSON'), isEmpty);
    });

    test('非法 action / 缺关键字段 / 非法 field 的条目被过滤', () {
      const raw = '{"adjust": ['
          '{"action":"explode","exercise":"A","field":"weight","value":1},'
          '{"action":"set","exercise":"A","field":"weight"},'
          '{"action":"set","exercise":"A","field":"color","value":1},'
          '{"action":"set","exercise":"A","field":"weight","value":80}]}';
      final out = extractRehabAdjust(raw);
      expect(out.length, 1);
      expect(out.first.value, 80);
    });
  });

  group('applyRehabAdjust 套用：set', () {
    test('set weight：有 plan 时只改工作组，warmup 不动', () {
      linked();
      final res = fit.applyRehabAdjust('re1', [
        const RehabAdjust(action: 'set', exercise: 'Barbell Bench Press', field: 'weight', value: 40),
      ]);
      expect(res.adjusted, 1);
      final planned = fit.plannedSets(routineA(), benchId());
      expect(planned[0].weightKg, 40);
      expect(planned[1].kind, SetKind.warmup);
      expect(planned[1].weightKg, 20);
      expect(planned[2].weightKg, 40);
    });

    test('set weight：无 plan 时建立 plan 组并设置', () {
      final ep = episode()..routineIds = [makeRoutine('康复 A')];
      fit.createEpisode(ep);
      fit.applyRehabAdjust('re1', [
        const RehabAdjust(action: 'set', exercise: 'Barbell Bench Press', field: 'weight', value: 30),
      ]);
      final planned = fit.plannedSets(routineA(), benchId());
      expect(planned.length, 3); // 默认 3 组
      expect(planned.every((p) => p.weightKg == 30), isTrue);
    });

    test('set sets：无 plan 时走简单模式只改组数', () {
      final ep = episode()..routineIds = [makeRoutine('康复 A')];
      fit.createEpisode(ep);
      fit.applyRehabAdjust('re1', [
        const RehabAdjust(action: 'set', exercise: 'Barbell Bench Press', field: 'sets', value: 5),
      ]);
      expect(routineA().sets[benchId()], 5);
      expect(fit.plannedSets(routineA(), benchId()), isEmpty);
    });

    test('set sets：有 plan 时调整工作组数量（补组与删组）', () {
      linked();
      fit.applyRehabAdjust('re1', [
        const RehabAdjust(action: 'set', exercise: 'Barbell Bench Press', field: 'sets', value: 4),
      ]);
      var planned = fit.plannedSets(routineA(), benchId());
      expect(planned.where((p) => p.kind != SetKind.warmup).length, 4);
      expect(planned.length, 5); // 4 working + 1 warmup
      fit.applyRehabAdjust('re1', [
        const RehabAdjust(action: 'set', exercise: 'Barbell Bench Press', field: 'sets', value: 2),
      ]);
      planned = fit.plannedSets(routineA(), benchId());
      expect(planned.where((p) => p.kind != SetKind.warmup).length, 2);
      expect(planned[1].kind, SetKind.warmup); // warmup 留在原位
    });

    test('set rest：写组间休息秒数', () {
      linked();
      fit.applyRehabAdjust('re1', [
        const RehabAdjust(action: 'set', exercise: 'Barbell Bench Press', field: 'rest', value: 90),
      ]);
      expect(fit.routineRest(routineA().id, benchId()), 90);
    });

    test('set 动作名匹配不到时进 missed', () {
      linked();
      final res = fit.applyRehabAdjust('re1', [
        const RehabAdjust(action: 'set', exercise: '不存在的动作', field: 'weight', value: 40),
      ]);
      expect(res.adjusted, 0);
      expect(res.missed, ['不存在的动作']);
    });
  });

  group('applyRehabAdjust 套用：remove / add', () {
    test('remove：动作整体移除且清理组数/计划/休息', () {
      linked();
      fit.toggleRoutineExercise(routineA().id, bridgeId());
      fit.setRoutineRest(routineA().id, bridgeId(), 60);
      final res = fit.applyRehabAdjust('re1', [
        const RehabAdjust(action: 'remove', exercise: 'Glute Bridge'),
      ]);
      expect(res.adjusted, 1);
      final r = routineA();
      expect(r.exerciseIds, isNot(contains(bridgeId())));
      expect(r.sets.containsKey(bridgeId()), isFalse);
      expect(r.plan.containsKey(bridgeId()), isFalse);
      expect(r.rest.containsKey(bridgeId()), isFalse);
    });

    test('add：匹配动作库追加，带 sets/reps 时建 plan', () {
      linked();
      final res = fit.applyRehabAdjust('re1', [
        const RehabAdjust(action: 'add', exercise: 'Glute Bridge', addSets: 3, addReps: 12),
      ]);
      expect(res.adjusted, 1);
      final r = routineA();
      expect(r.exerciseIds.contains(bridgeId()), isTrue);
      final planned = fit.plannedSets(r, bridgeId());
      expect(planned.length, 3);
      expect(planned.every((p) => p.reps == 12), isTrue);
    });

    test('add：动作已存在时不重复添加（幂等）', () {
      linked();
      fit.applyRehabAdjust('re1', [
        const RehabAdjust(action: 'add', exercise: 'Barbell Bench Press', addSets: 5),
      ]);
      expect(routineA().exerciseIds.where((e) => e == benchId()).length, 1);
      expect(routineA().sets[benchId()], 5); // sets 仍按指令更新
    });

    test('add：动作匹配不到进 missed', () {
      linked();
      final res = fit.applyRehabAdjust('re1', [
        const RehabAdjust(action: 'add', exercise: '不存在的动作'),
      ]);
      expect(res.adjusted, 0);
      expect(res.missed, ['不存在的动作']);
    });

    test('routine 限定：名字不存在时整条进 missed', () {
      linked();
      final res = fit.applyRehabAdjust('re1', [
        const RehabAdjust(action: 'set', target: '不存在的计划', exercise: 'Barbell Bench Press', field: 'weight', value: 40),
      ]);
      expect(res.adjusted, 0);
      expect(res.missed.single, contains('不存在的计划'));
    });
  });

  group('applyRehabAdjust 安全门与边界', () {
    test('档案未通过安全门时忽略全部调整', () {
      final ep = linked(flags: ['bladder']);
      ep.redFlags = ['bladder']; // 构造时带上了，显式重申
      final res = fit.applyRehabAdjust('re1', [
        const RehabAdjust(action: 'set', exercise: 'Barbell Bench Press', field: 'weight', value: 99),
      ]);
      expect(fit.episodeById('re1')!.safe, isFalse);
      expect(res.adjusted, 0);
      expect(res.missed.single, contains('安全门'));
    });

    test('档案不存在时无操作', () {
      final res = fit.applyRehabAdjust('nope', const []);
      expect(res.adjusted, 0);
    });

    test('档案没有关联计划时提示', () {
      fit.createEpisode(episode());
      final res = fit.applyRehabAdjust('re1', [
        const RehabAdjust(action: 'add', exercise: 'Glute Bridge'),
      ]);
      expect(res.adjusted, 0);
      expect(res.missed.single, contains('没有关联计划'));
    });
  });

  group('applyRehabReply 集成', () {
    test('routines + adjust + advice 一次套用：建计划、调重量、存注意事项', () {
      final ep = episode();
      ep.routineIds = [makeRoutine('康复 A', withPlan: true)];
      fit.createEpisode(ep);
      const reply = '{"advice": "疼就停", '
          '"routines": [{"name": "康复 B", "exercises": [{"name": "Glute Bridge", "sets": 2}]}], '
          '"adjust": [{"action":"set","exercise":"Barbell Bench Press","field":"weight","value":40}]}';
      final res = fit.applyRehabReply('re1', reply);
      expect(res.routines, 1);
      expect(res.adjusted, 1);
      expect(res.added, 1);
      final r = fit.routines.singleWhere((x) => x.name == '康复 A');
      final planned = fit.plannedSets(r, benchId());
      for (final p in planned) {
        if (p.kind != SetKind.warmup) expect(p.weightKg, 40);
      }
      expect(fit.episodeById('re1')!.advice, '疼就停');
    });

    test('未通过安全门时 adjust 被忽略、advice 保留', () {
      fit.createEpisode(episode(flags: ['bladder']));
      const reply =
          '{"advice": "尽快就医", "adjust": [{"action":"set","exercise":"Barbell Bench Press","field":"weight","value":99}]}';
      final res = fit.applyRehabReply('re1', reply);
      expect(res.adjusted, 0);
      expect(fit.episodeById('re1')!.advice, '尽快就医');
    });

    test('未通过安全门时计划与调整都不落地，只留注意事项', () {
      fit.createEpisode(episode(flags: ['bladder']));
      const reply = '{"advice": "先就医", "routines": [{"name": "X", "exercises": ['
          '{"name": "Glute Bridge", "sets": 3}]}], '
          '"adjust": [{"action":"add","exercise":"Glute Bridge"}]}';
      final res = fit.applyRehabReply('re1', reply);
      expect(res.routines, 0);
      expect(res.added, 0);
      expect(res.adjusted, 0);
      expect(fit.routines.where((r) => r.name == 'X'), isEmpty);
      expect(fit.episodeById('re1')!.advice, '先就医');
    });

    test('同一回复重复导入：调整不叠加（幂等）', () {
      linked();
      const reply = '{"adjust": [{"action":"set","exercise":"Barbell Bench Press","field":"weight","value":40},'
          '{"action":"add","exercise":"Glute Bridge","sets":3,"reps":12}]}';
      fit.applyRehabReply('re1', reply);
      fit.applyRehabReply('re1', reply);
      final r = fit.routines.singleWhere((x) => x.name == '康复 A');
      expect(r.exerciseIds.where((e) => e == bridgeId()).length, 1); // 未重复添加
      final planned = fit.plannedSets(r, benchId());
      expect(planned.where((p) => p.kind != SetKind.warmup).every((p) => p.weightKg == 40), isTrue);
    });
  });
}