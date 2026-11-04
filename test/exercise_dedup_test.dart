import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/catalog/exercise_catalog.dart';
import 'package:gymmane/catalog/exercises_ext.dart';
import 'package:gymmane/catalog/exercises_rep.dart';
import 'package:gymmane/catalog/merged_exercises.dart';
import 'package:gymmane/l10n/catalog_zh.dart';
import 'package:gymmane/l10n/catalog_zh_ext.dart';
import 'package:gymmane/l10n/catalog_zh_rep.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/services/merged_ids.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// RISK-086：动作库跨源去重的不变量。
///
/// 背景：动作来自三个源（上游 `kExercises` / 我方 `kExercisesExt` / `kExercisesRep`），
/// 跨源同名重复会让动作选择器里出现两条一模一样的条目。处置：**判定为同一动作的，
/// 只留一条（优先上游），其余删除，并把被删 id 记进 `kMergedExercises` 做别名重定向** ——
/// 这样历史 session / 例程 / 备注 / 自定义照片（都按 id 存）仍然能解析到动作。
///
/// 判定「同一动作」的口径（与去重脚本一致）：**英文名（忽略大小写/标点/词序）+ 主肌群 + 器材**
/// 相同，或 **中文名 + 主肌群 + 器材** 相同。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.setUnits('kg');
  });

  final all = [...kExercises, ...kExercisesExt, ...kExercisesRep];
  final ids = {for (final e in all) e.id};

  String zhOf(String id) =>
      kExerciseNameZh[id] ?? kExerciseNameZhExt[id] ?? kExerciseNameZhRep[id] ?? '';

  String normEn(String s) {
    final toks = s
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.isNotEmpty)
        .toList()
      ..sort();
    return toks.join(' ');
  }

  test('别名表：目标必须真实存在，不得自指', () {
    expect(kMergedExercises, isNotEmpty, reason: '别名表空了？被合并掉的历史 id 会解析不到动作');
    final problems = <String>[];
    kMergedExercises.forEach((from, to) {
      if (from == to) problems.add('$from→$to 自指');
      if (!ids.contains(to)) problems.add('$from→$to 目标不存在');
    });
    expect(problems, isEmpty, reason: problems.take(10).join('; '));
  });

  test('别名表不成环（A→B→A 会让解析死循环）', () {
    final problems = <String>[];
    kMergedExercises.forEach((from, to) {
      var cur = to;
      var hops = 0;
      while (kMergedExercises.containsKey(cur) && hops++ < 20) {
        cur = kMergedExercises[cur]!;
      }
      if (cur == from) problems.add('$from 成环');
    });
    expect(problems, isEmpty, reason: problems.take(10).join('; '));
  });

  test('动作库没有跨源重复（英文名忽略词序 + 主肌群 + 器材）', () {
    final seen = <String, String>{};
    final dup = <String>[];
    for (final e in all) {
      final k = '${normEn(e.name)}|${e.primary}|${e.equipment}';
      if (seen.containsKey(k)) {
        dup.add('$k → ${seen[k]} vs ${e.id}');
      } else {
        seen[k] = e.id;
      }
    }
    expect(dup, isEmpty, reason: '同一动作还留着两条：\n${dup.take(10).join('\n')}');
  });

  test('动作库没有跨源重复（中文名 + 主肌群 + 器材）', () {
    final seen = <String, String>{};
    final dup = <String>[];
    for (final e in all) {
      final zh = zhOf(e.id);
      if (zh.isEmpty) continue;
      final k = '$zh|${e.primary}|${e.equipment}';
      if (seen.containsKey(k)) {
        dup.add('$k → ${seen[k]} vs ${e.id}');
      } else {
        seen[k] = e.id;
      }
    }
    expect(dup, isEmpty, reason: '同一动作还留着两条：\n${dup.take(10).join('\n')}');
  });

  test('被合并掉的历史 id 仍能解析到保留项（老数据不丢动作）', () {
    var checked = 0;
    for (final from in kMergedExercises.keys) {
      final ex = fit.exerciseById(from);
      expect(ex, isNotNull, reason: '历史 id $from 解析不到动作（老 session / 例程 / 照片会丢）');
      expect(ex!.id, kMergedExercises[from], reason: '$from 应重定向到保留项');
      checked++;
      if (checked >= 40) break; // 抽 40 个足够（全表在别的用例里已校验目标存在）
    }
    expect(checked, greaterThan(0));
  });

  test('存档加载会把历史 id 重映射（withMergedExercises 生效）', () {
    final sample = kMergedExercises.keys.first;
    final target = kMergedExercises[sample]!;
    final out = withMergedExercises(<String, dynamic>{
      'sessions': [
        {'ex': sample, 'note': 'x'}
      ],
      'media': {sample: '/tmp/a.jpg'},
    });
    expect((out['sessions'] as List).first['ex'], target);
    expect((out['media'] as Map).keys.first, target);
  });
}