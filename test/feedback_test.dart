import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/local_store.dart';
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
  });
}
