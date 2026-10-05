import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/models/rehab_episode.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/services/rehab_intake.dart';
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

  RehabEpisode episode({List<String> flags = const []}) => RehabEpisode(
        id: 're1',
        title: '腰部康复',
        createdAt: DateTime.now(),
        area: 'lowback',
        duration: 'sub',
        pain: 4,
        redFlags: flags,
        factors: '久坐加重',
        goals: const ['pain', 'strength'],
        equipment: const ['Bodyweight', 'Band'],
        daysPerWeek: 3,
      );

  group('安全门', () {
    test('没有红旗征就放行', () {
      expect(episode().safe, isTrue);
    });

    test('命中任意红旗征就不放行', () {
      expect(episode(flags: ['bladder']).safe, isFalse);
      expect(episode(flags: ['fever', 'trauma']).safe, isFalse);
    });
  });

  group('档案存取', () {
    test('新建 / 读取 / 更新 / 删除', () {
      final ep = episode();
      fit.createEpisode(ep);
      expect(fit.rehabEpisodes.length, 1);
      expect(fit.episodeById('re1')?.title, '腰部康复');

      ep.pain = 2;
      ep.notes = '好多了';
      fit.updateEpisode(ep);
      expect(fit.episodeById('re1')?.notes, '好多了');

      fit.deleteEpisode('re1');
      expect(fit.rehabEpisodes, isEmpty);
    });

    test('能存进 JSON 再读回来', () {
      fit.createEpisode(episode(flags: ['night']));
      final json = fit.toJson();
      final back = RehabEpisode.fromJson((json['rehabEp'] as List).first as Map<String, dynamic>);
      expect(back.title, '腰部康复');
      expect(back.redFlags, ['night']);
      expect(back.safe, isFalse);
      expect(back.equipment, ['Bodyweight', 'Band']);
      expect(back.daysPerWeek, 3);
    });
  });

  group('提示词', () {
    test('带齐情况、困扰、输出要求和动作库清单', () {
      final text = fit.rehabPromptText(episode());
      expect(text, contains('【我的情况】'));
      expect(text, contains('【本次困扰】'));
      expect(text, contains('【输出要求】'));
      expect(text, contains('腰 / 下背'));
      expect(text, contains('康复目标'));
      expect(text, contains('【动作库清单】'));
      // 目录里应当至少出现一个已知动作
      expect(text, contains('Barbell Bench Press'));
      // 叫停规则必须写进去
      expect(text, contains('立即停止并就医'));
    });

    test('未通过安全门时提示词里也如实写出命中项', () {
      final text = fit.rehabPromptText(episode(flags: ['bladder']));
      expect(text, contains('安全筛查命中'));
      expect(text, contains('大小便控制异常'));
    });
  });

  group('AI 回复套用', () {
    const reply = '这是给你的建议：\n'
        '{"advice": "疼痛超过 3/10 就停；两周后复评。", "routines": ['
        '{"name": "康复 A", "exercises": ['
        '{"name": "Barbell Bench Press", "sets": 3, "reps": 10},'
        '{"name": "Glute Bridge", "sets": 3, "reps": 12}]}]}';

    test('建出计划、挂到档案上、存下注意事项', () {
      final ep = episode();
      fit.createEpisode(ep);
      final res = fit.applyRehabReply('re1', reply);
      expect(res.routines, 1);
      expect(res.added, 2);
      final saved = fit.episodeById('re1')!;
      expect(saved.routineIds.length, 1);
      expect(fit.routines.any((r) => r.id == saved.routineIds.first), isTrue);
      expect(saved.advice, contains('疼痛超过 3/10'));
    });

    test('读不懂的内容不会乱建计划', () {
      fit.createEpisode(episode());
      final res = fit.applyRehabReply('re1', '多喝热水，注意休息。');
      expect(res.routines, 0);
      expect(res.added, 0);
      expect(fit.episodeById('re1')!.routineIds, isEmpty);
    });

    test('advice 支持列表写法，也支持 JSON 之外的文字', () {
      expect(extractRehabAdvice('{"advice": ["甲", "乙"], "routines": []}'), '甲\n乙');
      final plain = extractRehabAdvice('先做活动度\n再做力量\n疼痛加重就停');
      expect(plain, contains('疼痛加重就停'));
    });
  });
}
