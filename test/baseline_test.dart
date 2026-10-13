// 自测基线回归：模型往返 / 增删 / latest-previous / 持久化字段。
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/models/baseline.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
  });

  test('BaselineSession/Item JSON 往返', () {
    final s = BaselineSession(id: 'b1', date: DateTime(2026, 3, 1), items: [
      BaselineItem('resting_hr', 62),
      BaselineItem('chair_stand_30', 18),
    ]);
    final b = BaselineSession.fromJson(s.toJson());
    expect(b.id, 'b1');
    expect(b.type, 'fitness');
    expect(b.value('resting_hr'), 62);
    expect(b.value('chair_stand_30'), 18);
    expect(b.value('waist'), isNull);
    expect(b.date.month, 3);
  });

  test('v1 普通档 6 项定义齐全', () {
    expect(kBaselineFitness.length, 6);
    expect(baselineDef('resting_hr')!.higherIsBetter, isFalse);
    expect(baselineDef('waist')!.higherIsBetter, isFalse);
    expect(baselineDef('chair_stand_30')!.unit, '次');
    expect(baselineDef('nope'), isNull);
  });

  test('保存/最新/上一个/删除', () {
    fit.saveBaseline(BaselineSession(id: 's1', date: DateTime(2026, 1, 1), items: [BaselineItem('waist', 85)]));
    fit.saveBaseline(BaselineSession(id: 's2', date: DateTime(2026, 2, 1), items: [BaselineItem('waist', 83)]));
    expect(fit.baselines.length, 2);
    expect(fit.latestBaseline!.id, 's2');
    expect(fit.previousBaseline!.id, 's1');
    expect(fit.latestBaseline!.value('waist'), 83);

    fit.deleteBaseline('s2');
    expect(fit.baselines.length, 1);
    expect(fit.latestBaseline!.id, 's1');
    expect(fit.previousBaseline, isNull);
  });

  test('toJson 带 baselines', () {
    fit.saveBaseline(BaselineSession(id: 'x', date: DateTime(2026, 4, 1), items: [BaselineItem('sit_reach', 12)]));
    final map = fit.toJson();
    expect(map['baselines'], isA<List>());
    expect((map['baselines'] as List).length, 1);
  });
}
