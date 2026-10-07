import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/rehab_episode.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/services/rehab_intake.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/widgets/session_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.setUnits('kg');
  });

  LoggedSession session() {
    final bench = fit.matchExerciseByName('Barbell Bench Press')!.id;
    return LoggedSession(DateTime.now(), 3600, [
      LoggedExercise(bench, 'Barbell Bench Press', 'chest', [LoggedSet(8, 60)]),
    ]);
  }

  group('训练反馈', () {
    test('新训练默认没有反馈', () {
      expect(session().hasFeedback, isFalse);
      expect(session().feel, isNull);
      expect(session().painLevel, 0);
    });

    test('记录感觉 / 不适 / 备注', () {
      final s = session();
      fit.sessions.add(s);
      fit.setSessionFeedback(s, feel: 2, painArea: 'back', painLevel: 6, note: '腰部有点紧');
      expect(s.hasFeedback, isTrue);
      expect(s.feel, 2);
      expect(s.painArea, 'back');
      expect(s.painLevel, 6);
      expect(s.note, '腰部有点紧');
      // 存进 session 列表的那条也要同步
      expect(fit.sessions.last.note, '腰部有点紧');
    });

    test('可以清除反馈', () {
      final s = session();
      fit.setSessionFeedback(s, feel: 1, note: '还行');
      fit.clearSessionFeedback(s);
      expect(s.hasFeedback, isFalse);
      expect(s.feel, isNull);
      expect(s.note, '');
    });

    test('反馈能存进 JSON 再读回来', () {
      final s = session();
      fit.setSessionFeedback(s, feel: 0, painArea: 'quads', painLevel: 3, note: '轻松');
      final back = LoggedSession.fromJson(s.toJson());
      expect(back.feel, 0);
      expect(back.painArea, 'quads');
      expect(back.painLevel, 3);
      expect(back.note, '轻松');
      // 没写反馈的那次不产生多余字段
      final plain = LoggedSession.fromJson(session().toJson());
      expect(plain.hasFeedback, isFalse);
    });

    test('感觉档位有本地化文案', () {
      setAppLanguage('en');
      expect(feelLabels().length, 4);
      expect(feelLabels().first, 'Easy');
      setAppLanguage('zh');
      expect(feelLabels().first, '很轻松');
      setAppLanguage('es');
      expect(feelLabels().length, 4);
    });

    // ---- 台账回归测试 ----

    test('FB-01 康复提示只在命中活跃档案时出现', () {
      // 没有档案 → 不提示
      expect(rehabFeedbackHint('back', 8), isFalse);
      // 建一个腰部档案(映射到 back)
      fit.createEpisode(RehabEpisode(
        id: 'ep1', title: '腰部康复', createdAt: DateTime.now(), area: 'lowback', status: 'active'));
      expect(rehabFeedbackHint('back', 8), isTrue);
      // 阈值以下不提示
      expect(rehabFeedbackHint('back', 4), isFalse);
      // 部位对不上不提示
      expect(rehabFeedbackHint('calves', 9), isFalse);
      // 档案收尾后不再提示
      fit.updateEpisode(fit.episodeById('ep1')!..status = 'done');
      expect(rehabFeedbackHint('back', 8), isFalse);
    });

    test('FB-02 没有部位时不留孤立的不适程度', () {
      final s = session();
      fit.setSessionFeedback(s, painLevel: 7);
      expect(s.painLevel, 0);
      expect(s.hasFeedback, isFalse);
      fit.setSessionFeedback(s, painArea: 'back', painLevel: 7);
      expect(s.painLevel, 7);
      expect(s.hasFeedback, isTrue);
    });

    test('FB-05 腰背用 lowerback 肌群标签时仍命中腰部康复档案', () {
      // 上游把下背动作重标为 lowerback 后，反馈选择器会给出 lowerback 标签；
      // 它必须与 kRehabAreaMuscle['lowback']='back' 同义命中（回归：上游融合引入断层）
      fit.createEpisode(RehabEpisode(
        id: 'ep-low2', title: '腰部康复', createdAt: DateTime.now(), area: 'lowback', status: 'active'));
      expect(rehabAreaMatches('lowerback'), isTrue);
      expect(rehabFeedbackHint('lowerback', 8), isTrue);
      // 旧的 back 标签仍然命中
      expect(rehabAreaMatches('back'), isTrue);
      // 其他部位仍不误命中
      expect(rehabAreaMatches('calves'), isFalse);
    });

    test('FB-03 部位映射覆盖全部康复部位(除“其他”)', () {
      final missing = kRehabAreaIds
          .where((k) => k != 'other' && !kRehabAreaMuscle.containsKey(k))
          .toList();
      expect(missing, isEmpty, reason: '康复部位新增后必须同步 kRehabAreaMuscle');
    });

    test('FB-04 取消选中感觉档能真正清掉', () {
      final s = session();
      fit.setSessionFeedback(s, feel: 2);
      expect(s.feel, 2);
      // 弹层里再点一下同一档 = 取消选中(feel 变回 null),必须真清掉
      fit.setSessionFeedback(s, feel: null, clearFeel: true);
      expect(s.feel, isNull);
      expect(s.hasFeedback, isFalse);
    });

    test('FB-06 续训不会丢掉已填反馈', () {
      fit.sessions.clear();
      fit.selectedMuscles.clear();
      fit.startWorkout();
      fit.toggleMuscle('chest');
      fit.trainContinue();
      fit.startSession();
      for (final e in fit.session!.exercises) {
        for (final st in e.sets) {
          st.done = true;
        }
      }
      fit.finishSession();
      fit.setSessionFeedback(fit.filedSession!, feel: 3, note: '有点累');
      // 继续训练 → 临时归档条目被移除
      fit.continueSession();
      expect(fit.sessions.any((x) => x.note == '有点累'), isFalse);
      // 再次完成 → 反馈写回新的归档条目
      for (final e in fit.session!.exercises) {
        for (final st in e.sets) {
          st.done = true;
        }
      }
      fit.finishSession();
      expect(fit.filedSession!.note, '有点累');
      expect(fit.filedSession!.feel, 3);
      fit.saveAndExit();
    });
  });
}
