// 「日志」合并回归测试（ISS-028）：康复日志并入统一日志后的模型/CRUD/迁移。
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/models/rehab_log.dart';
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

  test('RehabLogEntry JSON 往返', () {
    final e = RehabLogEntry(
        id: 'x1', date: DateTime(2026, 1, 2), phase: 2, light: 'y', feel: '有点紧');
    final b = RehabLogEntry.fromJson(e.toJson());
    expect(b.id, 'x1');
    expect(b.phase, 2);
    expect(b.light, 'y');
    expect(b.feel, '有点紧');
    expect(b.date.year, 2026);
    expect(b.date.day, 2);
  });

  test('康复日志 增/改/删', () {
    fit.addRehabLog(RehabLogEntry(id: 'a', date: DateTime(2026, 1, 1), phase: 0, light: 'g'));
    fit.addRehabLog(RehabLogEntry(id: 'b', date: DateTime(2026, 1, 2), phase: 1, light: 'r'));
    expect(fit.rehabLog.length, 2);
    expect(fit.rehabLog.first.id, 'b'); // insert(0)

    fit.updateRehabLog(
        RehabLogEntry(id: 'a', date: DateTime(2026, 1, 1), phase: 3, light: 'y', feel: 'ok'));
    expect(fit.rehabLog.firstWhere((x) => x.id == 'a').phase, 3);
    expect(fit.rehabLog.firstWhere((x) => x.id == 'a').feel, 'ok');

    fit.deleteRehabLog('b');
    expect(fit.rehabLog.length, 1);
    expect(fit.rehabLog.single.id, 'a');
  });

  test('旧康复手册日志（prefs rehab_log_v1）一次性迁入统一日志', () async {
    SharedPreferences.setMockInitialValues({
      'rehab_log_v1':
          '[{"date":"2026-01-05","phase":1,"light":"g","feel":"hi"},{"date":"2026-01-03","phase":0,"light":"r"}]'
    });
    await Store.instance.init();
    fit.resetAllData();
    expect(fit.rehabLogMerged, isFalse);

    await fit.migrateRehabLog();
    expect(fit.rehabLog.length, 2);
    expect(fit.rehabLogMerged, isTrue);
    expect(fit.rehabLog.first.date.day, 5); // 旧→新，最新在前
    expect(fit.rehabLog.first.feel, 'hi');

    // 幂等：再跑不重复
    await fit.migrateRehabLog();
    expect(fit.rehabLog.length, 2);
  });

  test('toJson 带上 rehabLog 与 merged 标记', () {
    fit.addRehabLog(RehabLogEntry(id: 'z', date: DateTime(2026, 2, 1), phase: 4, light: 'g', feel: '稳'));
    fit.rehabLogMerged = true;
    final map = fit.toJson();
    expect(map['rehabLog'], isA<List>());
    expect((map['rehabLog'] as List).length, 1);
    expect(map['rehabLogMerged'], isTrue);
  });
}