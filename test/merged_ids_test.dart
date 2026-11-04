import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/catalog/exercise_catalog.dart';
import 'package:gymmane/catalog/exercises_ext.dart';
import 'package:gymmane/catalog/exercises_rep.dart';
import 'package:gymmane/catalog/merged_exercises.dart';
import 'package:gymmane/services/merged_ids.dart';

void main() {
  final old = kMergedExercises.keys.first;
  final kept = kMergedExercises[old]!;

  test('every merged exercise lands on one that still exists', () {
    // RISK-086：去重后别名不再只落向上游条目（我方 ext/rep 之间同动作也会合并），
    // 故这里改为「落到全库仍存在的条目」——意图不变（别名必须有归宿、不得悬空），且更严格。
    final ids = <String>{
      for (final e in [...kExercises, ...kExercisesExt, ...kExercisesRep]) e.id,
    };
    for (final e in kMergedExercises.entries) {
      expect(ids, isNot(contains(e.key)), reason: e.key);
      expect(ids, contains(e.value), reason: '${e.key} -> ${e.value}');
    }
  });

  test('routines, history and favourites move to the exercise that stays', () {
    final data = withMergedExercises({
      'routines': [
        {'id': 'r1', 'ex': [old, 'other']},
      ],
      'sessions': [
        {'ex': [{'id': old, 'n': 'Old name'}]},
      ],
      'favorites': {old: true},
    });
    expect((data['routines'] as List).first['ex'], [kept, 'other']);
    expect((data['sessions'] as List).first['ex'].first['id'], kept);
    expect(data['favorites'], {kept: true});
  });

  test('a routine that already had both keeps it once', () {
    final data = withMergedExercises({
      'routines': [
        {'ex': [kept, old]},
      ],
      'favorites': {kept: false, old: true},
    });
    expect((data['routines'] as List).first['ex'], [kept]);
    expect(data['favorites'], {kept: false});
  });
}
