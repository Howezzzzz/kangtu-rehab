import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/services/workout_import.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('lyfta', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Store.instance.init();
      fit.resetAllData();
      fit.setUnits('kg');
    });

    tearDown(() {
      if (fit.session != null) fit.saveAndExit();
    });

    const csv = '﻿Title,Date,Duration,Description,Notes,Exercise,Exercise Note,Superset id,Weight,Reps,'
        'RIR/RPE,Distance,Time,Set Type,RecordLevel: gold/silver/bronze,RecordType: 1RM / max_weight / volume / reps\n'
        'Pull Day,2026-04-17 16:00:05,01:19:33,"A plan, with commas",,Barbell Bent Over Row,,,60.000,10,,,,NORMAL_SET,,\n'
        'Pull Day,2026-04-17 16:00:05,01:19:33,"A plan, with commas",,Barbell Bent Over Row,,,70.000,8,,,,NORMAL_SET,1,1\n'
        'Pull Day,2026-04-17 16:00:05,01:19:33,"A plan, with commas",,Pull Up,,,,12,,,,NORMAL_SET,,\n';

    test('the export is recognised and read', () {
      expect(detectFormat(csv), ImportFormat.lyfta);
      final result = parseImport(csv);
      final session = result.sessions.single;
      expect(session.durationSec, 3600 + 19 * 60 + 33);
      expect(session.exercises.first.sets.map((s) => s.weightKg), [60, 70]);
      expect(session.exercises.last.name, 'Pull Up');
    });
  });

  group('#55 nombres de Lyfta', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Store.instance.init();
      fit.resetAllData();
      fit.setUnits('kg');
    });

    tearDown(() {
      if (fit.session != null) fit.saveAndExit();
    });

    String? match(String name) => fit.matchExerciseByName(name)?.name;

    test('no cambia de músculo por una palabra suelta', () {
      expect(match('Dumbbell Seated Curl'), isNot('Seated Leg Curl'));
      expect(match('Lever Seated Leg Extension'), isNot(contains('Calf')));
      // 康途定制：上游此处断言 isNull（因为它库里根本没这条动作）；我方 RepDB 扩充库
      // 有「dumbbell seated one arm rotate」条目，isNull 不再成立。不能只把断言删成注释
      // （那等于丢一格覆盖），改为正向锁住原测试意图：
      // ① 在我方库里确实能解析到；② 不会因为「Seated」这个松散的词跳到 Seated Leg Curl。
      final rotate = match('Dumbbell Seated One Arm Rotate');
      expect(rotate, isNotNull, reason: 'RepDB 扩充库应能解析这条动作');
      expect(rotate, isNot('Seated Leg Curl'));
      expect(rotate!.toLowerCase(), contains('rotate'),
          reason: '应匹配到同名的旋转类动作，实际得到 $rotate');
    });

    test('el nombre exacto gana', () {
      expect(match('Machine Reverse Fly'), 'Machine Reverse Fly');
      expect(match('Smith Hack Squat'), 'Smith Hack Squat');
    });

    test('encuentra el ejercicio aunque el nombre traiga más cosas', () {
      // 康途定制：RepDB 扩充库中「Cable Face Pull」匹配更好
      expect(match('Cable Standing Face Pull (with rope)'), 'Cable Face Pull');
      expect(match('Barbell Feet Flat Bench Press (male)'), 'Barbell Bench Press');
      expect(match('Lever Pec Deck Fly'), 'Pec Deck');
      // 康途定制：扩充库里有 EZ 杠窄握牧师凳弯举，比 「Barbell Preacher Curl」更贴
      expect(match('Close Grip Preacher Curl'), 'ez barbell close grip preacher curl');
    });

    test('su columna RIR/RPE se entiende en las dos escalas', () {
      const csv = 'Title,Date,Duration,Description,Notes,Exercise,Exercise Note,Superset id,Weight,Reps,'
          'RIR/RPE,Distance,Time,Set Type,RecordLevel: gold/silver/bronze,RecordType: 1RM / max_weight / volume / reps\n'
          'Pull,2026-04-17 16:00:05,01:00:00,,,Barbell Curl,,,30.000,10,2,,,NORMAL_SET,,\n'
          'Pull,2026-04-17 16:00:05,01:00:00,,,Barbell Curl,,,30.000,8,8.5,,,NORMAL_SET,,\n'
          'Pull,2026-04-17 16:00:05,01:00:00,,,Barbell Curl,,,30.000,8,,,,NORMAL_SET,,\n';
      final sets = parseImport(csv).sessions.single.exercises.single.sets;
      expect(sets.map((s) => s.rpe), [8, 8.5, null]);
    });
  });
}
