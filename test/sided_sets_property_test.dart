import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/models/live_session.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/headphones.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 上游 129349d2（轻量训练 + 单侧动作左右次数）与 fd02fedb（耳机音频路由）的
/// 自测证据：
///  - 属性测试（2.12）：`SessionSet` / `LoggedSet` 的 JSON 往返与不变量；
///  - 兼容性（E）：旧 JSON（无 `rr` / `rl` / `lt`）必须仍能解析；
///  - 异常路径（2.7）：耳机探测失败必须安全回落 false；
///  - 状态层：开启/关闭单侧后，`repsR` 的补齐与「收敛到较弱一侧」。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('属性测试：序列化往返与不变量', () {
    test('SessionSet 随机 2000 例：JSON 往返稳定 + weakReps = min(reps, repsR)', () {
      final rnd = Random(20261106);
      for (var n = 0; n < 2000; n++) {
        final reps = rnd.nextInt(999);
        final repsR = rnd.nextBool() ? null : rnd.nextInt(999);
        final st = SessionSet(reps, rnd.nextInt(5000) / 10, rnd.nextBool(),
            repsR: repsR,
            kind: SetKind.values[rnd.nextInt(SetKind.values.length)],
            rpe: rnd.nextBool() ? rnd.nextInt(10) / 2 : null,
            sec: rnd.nextBool() ? rnd.nextInt(3600) : null,
            km: rnd.nextBool() ? rnd.nextInt(500) / 10 : null,
            note: 'n$n');

        final back = SessionSet.fromJson(jsonDecode(jsonEncode(st.toJson())) as Map<String, dynamic>);
        expect(back.reps, reps, reason: 'reps 往返（第 $n 例）');
        expect(back.repsR, repsR, reason: 'repsR 往返（第 $n 例）');
        expect(back.kind, st.kind);
        expect(back.rpe, st.rpe);
        expect(back.sec, st.sec);
        expect(back.km, st.km);
        expect(back.note, st.note);

        // 不变量：弱侧次数永远 = min(左, 右)；未分侧时等于 reps
        expect(st.weakReps, repsR == null ? reps : min(reps, repsR), reason: 'weakReps 不变量（第 $n 例）');

        // logged 的映射不变量
        final lg = st.logged;
        expect(lg.reps, st.weakReps);
        if (repsR == null) {
          expect(lg.left, isNull);
          expect(lg.right, isNull);
          expect(lg.sided, isFalse);
        } else {
          expect(lg.left, reps);
          expect(lg.right, repsR);
          expect(lg.sided, isTrue);
        }
      }
    });

    test('LoggedSet 随机 1000 例：只有左右都非空才序列化 rl/rr', () {
      final rnd = Random(7);
      for (var n = 0; n < 1000; n++) {
        final hasLeft = rnd.nextBool();
        final hasRight = rnd.nextBool();
        final lg = LoggedSet(rnd.nextInt(999), rnd.nextInt(5000) / 10,
            left: hasLeft ? rnd.nextInt(999) : null, right: hasRight ? rnd.nextInt(999) : null);
        final j = jsonDecode(jsonEncode(lg.toJson())) as Map<String, dynamic>;
        final both = hasLeft && hasRight;
        expect(j.containsKey('rl'), both, reason: 'rl 只在双侧齐全时写出（第 $n 例）');
        expect(j.containsKey('rr'), both, reason: 'rr 只在双侧齐全时写出（第 $n 例）');
        final back = LoggedSet.fromJson(j);
        expect(back.sided, both);
        // 只记单侧时模型本就不落盘（sided 要求两侧都有）→ 解析回来为空，属预期
        expect(back.left, both ? lg.left : isNull);
        expect(back.right, both ? lg.right : isNull);
      }
    });
  });

  group('兼容性：旧数据（无新字段）', () {
    test('旧 SessionSet JSON 无 rr → repsR 为空且不计为分侧', () {
      final back = SessionSet.fromJson({'r': 12, 'w': 40.0, 'd': true});
      expect(back.repsR, isNull);
      expect(back.weakReps, 12);
      expect(back.logged.sided, isFalse);
    });

    test('旧 WorkoutSession JSON 无 lt → lightened 为 false；有 lt 则为 true', () {
      final live = WorkoutSession()
        ..lightened = true
        ..loggedAt = DateTime.now();
      final map = jsonDecode(jsonEncode(live.toJson())) as Map<String, dynamic>;
      expect(map['lt'], isTrue);
      expect(WorkoutSession.fromJson(map).lightened, isTrue);
      map.remove('lt'); // 模拟旧数据：该字段还不存在
      expect(WorkoutSession.fromJson(map).lightened, isFalse);
    });

    test('旧 LoggedSet JSON 无 rl/rr → 非分侧', () {
      final back = LoggedSet.fromJson({'r': 8, 'w': 60.0});
      expect(back.sided, isFalse);
      expect(back.left, isNull);
      expect(back.right, isNull);
    });
  });

  group('异常路径：耳机探测失败必须回落 false', () {
    test('非 Android 平台直接返回 false（不抛异常）', () async {
      expect(await Headphones.connected(), isFalse);
    });
  });

  group('状态层：单侧次数与轻量训练', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Store.instance.init();
      fit.resetAllData();
      fit.onboarded = true;
    });

    String startWith(String name) {
      final id = fit.matchExerciseByName(name)!.id;
      final rid = fit.createRoutine('t');
      fit.toggleRoutineExercise(rid, id);
      fit.startRoutine(fit.routines.firstWhere((r) => r.id == rid));
      return id;
    }

    test('开启单侧 → 现有组补齐 repsR；关闭 → 收敛到较弱一侧', () {
      final id = startWith('Barbell Bench Press');
      final ex = fit.session!.exercises.firstWhere((e) => e.id == id);
      expect(ex.sets.every((st) => st.repsR == null), isTrue);

      fit.toggleSidedReps(id);
      expect(ex.sets.every((st) => st.repsR != null), isTrue, reason: '开启后每组都要有 repsR');
      expect(ex.sets.every((st) => st.repsR == st.reps), isTrue);

      // 右 3 < 左 10 → 弱侧为右
      fit.setSessionReps(0, 0, 10);
      fit.setSessionRepsRight(0, 0, 3);
      expect(ex.sets.first.weakReps, 3);
      expect(ex.sets.first.logged.reps, 3);
      expect(ex.sets.first.logged.left, 10);
      expect(ex.sets.first.logged.right, 3);

      fit.toggleSidedReps(id);
      expect(ex.sets.first.repsR, isNull, reason: '关闭后 repsR 清空');
      expect(ex.sets.first.reps, 3, reason: '关闭后 reps 收敛到较弱一侧');
    });

    test('分侧组的训练量按较弱一侧计', () {
      final id = startWith('Barbell Bench Press');
      fit.toggleSidedReps(id);
      fit.setSessionReps(0, 0, 10);
      fit.setSessionRepsRight(0, 0, 4);
      fit.setSessionWeight(0, 0, 50);
      fit.toggleSet(0, 0);
      expect(fit.sessionVolumeKg, 4 * 50, reason: '10 与 4 → 取 4');
    });

    LoggedExercise seedHistory(String name, List<LoggedSet> sets, {int days = 2}) {
      final id = fit.matchExerciseByName(name)!.id;
      fit.sessions.add(LoggedSession(DateTime.now().subtract(Duration(days: days)), 1200,
          [LoggedExercise(id, id, 'back', sets)]));
      return fit.sessions.last.exercises.first;
    }

    test('bumpLoggedSide：只动指定一侧，reps 跟较弱一侧走', () {
      seedHistory('Barbell Bench Press', [LoggedSet(10, 80, left: 10, right: 6)]);
      final ex = fit.sessions.last.exercises.first;
      fit.bumpLoggedSide(ex, 0, true, 2); // 左 10 → 12
      expect(ex.sets[0].left, 12);
      expect(ex.sets[0].right, 6);
      expect(ex.sets[0].reps, 6, reason: 'reps 保持较弱一侧');
      fit.bumpLoggedSide(ex, 0, false, -6); // 右 6 → 0
      expect(ex.sets[0].right, 0);
      expect(ex.sets[0].reps, 0);
    });

    test('bumpLoggedSide：非分侧组是空操作（不得凭空造出侧次数）', () {
      seedHistory('Barbell Squat', [LoggedSet(5, 100)]);
      final ex = fit.sessions.last.exercises.first;
      fit.bumpLoggedSide(ex, 0, true, 3);
      expect(ex.sets[0].sided, isFalse);
      expect(ex.sets[0].reps, 5);
    });

    test('repRecords：按次数取最佳重量、≤5 点、单调递增；有氧/纯次数为空', () {
      final id = fit.matchExerciseByName('Barbell Bench Press')!.id;
      for (final (r, kg) in [(12, 60.0), (10, 70.0), (8, 80.0), (6, 90.0), (5, 95.0), (3, 100.0), (15, 40.0)]) {
        fit.sessions.add(LoggedSession(DateTime.now().subtract(Duration(days: r)), 1200,
            [LoggedExercise(id, id, 'chest', [LoggedSet(r, kg)])]));
      }
      final ladder = fit.repRecords(id);
      expect(ladder, isNotEmpty);
      expect(ladder.length, lessThanOrEqualTo(5));
      for (var i = 1; i < ladder.length; i++) {
        expect(ladder[i].reps, greaterThan(ladder[i - 1].reps), reason: '次数递增');
        expect(ladder[i].kg, lessThan(ladder[i - 1].kg), reason: '次数越多、最佳重量越轻（同一榜单内严格单调）');
      }
      expect(fit.repRecords(fit.matchExerciseByName('Running')!.id), isEmpty, reason: '有氧不属于该榜单');
    });

    test('copyPreviousSet：分侧组按左右分别回填', () {
      seedHistory('Barbell Bench Press', [LoggedSet(10, 80, left: 10, right: 6)]);
      final id = startWith('Barbell Bench Press');
      fit.toggleSidedReps(id);
      fit.copyPreviousSet(0, 0);
      final st = fit.session!.exercises.firstWhere((e) => e.id == id).sets.first;
      expect(st.reps, 10);
      expect(st.repsR, 6);
      expect(st.weight, 80);
    });

    test('bumpSessionRepsRight：以 repsR（未设则 reps）为基准增减', () {
      final id = startWith('Barbell Bench Press');
      fit.toggleSidedReps(id);
      fit.setSessionReps(0, 0, 10);
      fit.setSessionRepsRight(0, 0, 6);
      fit.bumpSessionRepsRight(0, 0, 2);
      expect(fit.session!.exercises.firstWhere((e) => e.id == id).sets.first.repsR, 8);
      expect(fit.session!.exercises.firstWhere((e) => e.id == id).sets.first.reps, 10, reason: '右侧增减不动左侧');
    });

    test('轻量训练：手动开关只改 deload，不动重量', () {
      startWith('Barbell Bench Press');
      final s = fit.session!;
      final before = s.exercises.first.sets.first.weight;
      expect(s.deload, isFalse);
      fit.toggleLightSession();
      expect(s.deload, isTrue);
      expect(s.lightened, isFalse, reason: '手动轻量不算自动降载');
      expect(s.exercises.first.sets.first.weight, before, reason: '手动轻量不改重量');
      fit.toggleLightSession();
      expect(s.deload, isFalse);
      expect(s.lightened, isFalse);
    });

    test('轻量训练（自动降载）的记录不得进入「按次数的最佳重量」', () {
      final id = fit.matchExerciseByName('Barbell Bench Press')!.id;
      fit.sessions.add(LoggedSession(DateTime.now().subtract(const Duration(days: 3)), 1200,
          [LoggedExercise(id, id, 'chest', [LoggedSet(10, 100)])]));
      // 减载周：重量按比例下调，且只做 15 次（别处没有 15 次的记录）
      fit.sessions.add(LoggedSession(DateTime.now().subtract(const Duration(days: 1)), 900,
          [LoggedExercise(id, id, 'chest', [LoggedSet(15, 40)])], deload: true));
      final ladder = fit.repRecords(id);
      expect(ladder.any((r) => r.reps == 15), isFalse, reason: '轻量训练的 15 次不该成为记录');
      expect(ladder.map((r) => r.reps), contains(10));
    });

    test('自动降载且已开练：不允许取消「轻量」标记（重量已改、无法还原）', () {
      startWith('Barbell Bench Press');
      final s = fit.session!;
      s.deload = true;
      s.lightened = true;
      fit.toggleSet(0, 0); // 做了第一组 → canSkipDeload 变 false
      expect(fit.canSkipDeload, isFalse);
      fit.toggleLightSession();
      expect(s.deload, isTrue, reason: '不得清掉标记（否则减载数据会混进进阶基线）');
      expect(s.lightened, isTrue);
    });
  });
}
