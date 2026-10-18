// ISS-127 回归：康复档案「诊断与医嘱」——就医后记录医嘱即可放行生成训练计划。
//   ① 模型：新增字段的 JSON 往返 + 旧档兼容 + hasDoctorOrders 判定
//   ② 提示词：医嘱区块插入、安全门分支（有医嘱放行）、隐私（不含医院/医生与用药）
//   ③ 存档：persist→load 往返、resetAllData 清空档案（原漏清，一并修）
//   ④ widget：引导条出现条件 + 记录后 AI 卡解锁
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/rehab_episode.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.setUnits('kg');
    setAppLanguage('zh');
  });

  RehabEpisode episode({List<String> flags = const []}) => RehabEpisode(
        id: 're1',
        title: '腰部康复',
        createdAt: DateTime(2026, 10, 18),
        area: 'lowback',
        duration: 'sub',
        pain: 4,
        redFlags: flags,
        factors: '久坐加重',
        goals: const ['pain', 'strength'],
        equipment: const ['Bodyweight'],
        daysPerWeek: 3,
      );

  group('ISS-127 模型：诊断与医嘱字段', () {
    test('新字段 JSON 往返完整', () {
      final ep = episode()
        ..doctorDx = 'L5-S1 椎间盘突出'
        ..icdCode = 'M51.1'
        ..visitDate = DateTime(2026, 10, 10)
        ..ordersText = '避免弯腰搬重物，以核心稳定性训练为主'
        ..advisedCare = '核心稳定性训练'
        ..restrictions = '禁负重深蹲、硬拉；暂不跑步'
        ..followUpAt = DateTime(2026, 11, 10)
        ..imaging = 'MRI：L5-S1 轻度突出'
        ..facility = '市立医院 骨科 张医生'
        ..medNote = '塞来昔布 0.2g 每日一次';
      final back = RehabEpisode.fromJson(
          jsonDecode(jsonEncode(ep.toJson())) as Map<String, dynamic>);
      expect(back.doctorDx, 'L5-S1 椎间盘突出');
      expect(back.icdCode, 'M51.1');
      expect(back.visitDate, DateTime(2026, 10, 10));
      expect(back.ordersText, '避免弯腰搬重物，以核心稳定性训练为主');
      expect(back.advisedCare, '核心稳定性训练');
      expect(back.restrictions, '禁负重深蹲、硬拉；暂不跑步');
      expect(back.followUpAt, DateTime(2026, 11, 10));
      expect(back.imaging, 'MRI：L5-S1 轻度突出');
      expect(back.facility, '市立医院 骨科 张医生');
      expect(back.medNote, '塞来昔布 0.2g 每日一次');
      expect(back.hasDoctorOrders, isTrue);
    });

    test('旧档（无新增键）安全读回；无日期时不写多余键', () {
      final legacy = RehabEpisode.fromJson(
          {'id': 'x', 't': '旧档', 'c': '2026-01-01T00:00:00.000'});
      expect(legacy.doctorDx, '');
      expect(legacy.ordersText, '');
      expect(legacy.restrictions, '');
      expect(legacy.visitDate, isNull);
      expect(legacy.followUpAt, isNull);
      expect(legacy.medNote, '');
      expect(legacy.hasDoctorOrders, isFalse);

      final j = episode().toJson();
      expect(j.containsKey('vd'), isFalse);
      expect(j.containsKey('fua'), isFalse);
    });

    test('hasDoctorOrders：诊断 / 医嘱原文 / 限制 任一非空即真；仅医院名不算', () {
      expect(episode().hasDoctorOrders, isFalse);
      expect((episode()..doctorDx = '腰突').hasDoctorOrders, isTrue);
      expect((episode()..ordersText = '少弯腰').hasDoctorOrders, isTrue);
      expect((episode()..restrictions = '禁硬拉').hasDoctorOrders, isTrue);
      expect((episode()..facility = '某医院').hasDoctorOrders, isFalse);
      expect((episode()..doctorDx = '   ').hasDoctorOrders, isFalse);
    });
  });

  group('ISS-127 提示词：医嘱区块 + 安全门分支', () {
    test('未过安全门、无医嘱 → 维持「只给 advice」限制，不出计划', () {
      final text = fit.rehabPromptText(episode(flags: const ['bladder']));
      expect(text, contains('未通过安全门时，只给 advice'));
      expect(text, isNot(contains('【医生诊断与医嘱】')));
    });

    test('未过安全门、有医嘱 → 插入医嘱区块且放行输出计划', () {
      final ep = episode(flags: const ['bladder'])
        ..doctorDx = 'L5-S1 突出'
        ..ordersText = '保守治疗，核心训练'
        ..restrictions = '禁负重深蹲、硬拉';
      final text = fit.rehabPromptText(ep);
      expect(text, contains('【医生诊断与医嘱】'));
      expect(text, contains('L5-S1 突出'));
      expect(text, contains('保守治疗，核心训练'));
      expect(text, contains('限制与禁忌（必须遵守）：禁负重深蹲、硬拉'));
      expect(text, contains('即使安全门未通过也应给出计划'));
      expect(text, isNot(contains('未通过安全门时，只给 advice')));
    });

    test('隐私：提示词不含医院 / 医生与用药备注（仅本地记录）', () {
      final ep = episode()
        ..doctorDx = '腰突'
        ..facility = '某医院 骨科 张医生'
        ..medNote = '塞来昔布';
      final text = fit.rehabPromptText(ep);
      expect(text, contains('【医生诊断与医嘱】'));
      expect(text, isNot(contains('某医院')));
      expect(text, isNot(contains('张医生')));
      expect(text, isNot(contains('塞来昔布')));
    });
  });

  group('ISS-127 存档路径', () {
    test('persist → loadFromStore 带回医嘱字段', () {
      fit.createEpisode(episode()
        ..doctorDx = '腰突'
        ..restrictions = '禁硬拉'
        ..visitDate = DateTime(2026, 10, 10));
      fit.persistNow();
      fit.rehabEpisodes.clear();
      fit.loadFromStore();
      final back = fit.episodeById('re1')!;
      expect(back.doctorDx, '腰突');
      expect(back.restrictions, '禁硬拉');
      expect(back.visitDate, DateTime(2026, 10, 10));
    });

    test('resetAllData 清空康复档案（原有漏清，随本次一并修复）', () {
      fit.createEpisode(episode()..doctorDx = '腰突');
      expect(fit.rehabEpisodes, isNotEmpty);
      fit.resetAllData();
      expect(fit.rehabEpisodes, isEmpty);
    });
  });

  group('ISS-127 widget：引导条与 AI 卡解锁', () {
    Future<void> pumpEpisode(WidgetTester tester, RehabEpisode ep) async {
      fit.onboarded = true;
      fit.createEpisode(ep);
      fit.activeEpisodeId = ep.id;
      fit.route = 'rehab-episode';
      await tester.pumpWidget(const GymManeApp());
      await tester.pumpAndSettle();
    }

    testWidgets('未过安全门且无医嘱：出现就医引导条，AI 输入框不出现', (tester) async {
      await pumpEpisode(tester, episode(flags: const ['bladder']));
      expect(find.textContaining('已就医？'), findsOneWidget);
      expect(find.byKey(const Key('rehabAiReply')), findsNothing);
      expect(find.text('诊断与医嘱'), findsOneWidget);
    });

    testWidgets('未过安全门但已记录医嘱：引导条消失，AI 输入框出现', (tester) async {
      await pumpEpisode(tester, episode(flags: const ['bladder'])..doctorDx = 'L5-S1 突出');
      expect(find.textContaining('已就医？'), findsNothing);
      expect(find.byKey(const Key('rehabAiReply')), findsOneWidget);
      // F2 回归：已放行时不应再显示「未通过安全门，暂不生成训练建议」
      expect(find.text(t.rehabGateBlocksPlan), findsNothing);
    });

    testWidgets('填写诊断并保存 → 落盘且放行（引导条收、AI 卡开）', (tester) async {
      await pumpEpisode(tester, episode(flags: const ['bladder']));
      // 卡片里的第一个文本框 = 诊断
      await tester.enterText(find.byType(TextField).first, 'L5-S1 突出');
      await tester.pump();
      final saveBtn = find.text('保存诊断与医嘱');
      await tester.scrollUntilVisible(saveBtn, 400.0,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(fit.episodeById('re1')!.doctorDx, 'L5-S1 突出');
      expect(fit.episodeById('re1')!.hasDoctorOrders, isTrue);
      expect(find.byKey(const Key('rehabAiReply')), findsOneWidget);
      expect(find.textContaining('已就医？'), findsNothing);
    });
  });

  // 阶段 4 独立复核 F1 回归：此前 applyRehabReply/applyRehabAdjust 仍按「未过安全门」硬拦，
  // 导致「有医嘱 = 可生成计划」在导入环节断链（提示词/UI 放行、落地时静默丢弃）。
  group('ISS-127 端到端导入（复核 F1）', () {
    const replyJson =
        '{"advice":"仅供参考","routines":[{"name":"康复 A","exercises":[{"name":"Barbell Bench Press","sets":3,"reps":10}]}]}';
    const adjustJson =
        '{"advice":"x","adjust":[{"action":"set","exercise":"Barbell Bench Press","field":"sets","value":5}]}';

    test('未过安全门 + 无医嘱 → 仍拦截，计划不落地（只留 advice）', () {
      fit.createEpisode(episode(flags: const ['bladder']));
      final r = fit.applyRehabReply('re1', replyJson);
      expect(r.routines, 0);
      expect(r.missed, contains('未通过安全门，已忽略计划与调整'));
      expect(fit.episodeById('re1')!.routineIds, isEmpty);
      expect(fit.episodeById('re1')!.advice, '仅供参考');
    });

    test('未过安全门 + 有医嘱 → 放行，计划落地', () {
      fit.createEpisode(episode(flags: const ['bladder'])
        ..doctorDx = 'L5-S1 突出'
        ..restrictions = '禁负重深蹲、硬拉');
      final r = fit.applyRehabReply('re1', replyJson);
      expect(r.missed, isNot(contains('未通过安全门，已忽略计划与调整')));
      expect(r.routines + r.added, greaterThan(0));
      expect(fit.episodeById('re1')!.routineIds, isNotEmpty);
    });

    test('未过安全门 + 无医嘱 → adjust 仍拦截', () {
      final ep = episode(flags: const ['bladder']);
      final rid = fit.createRoutine('康复 A');
      fit.toggleRoutineExercise(rid, fit.matchExerciseByName('Barbell Bench Press')!.id);
      ep.routineIds = [rid];
      fit.createEpisode(ep);
      final r = fit.applyRehabReply('re1', adjustJson);
      expect(r.adjusted, 0);
      expect(r.missed.join(), contains('未通过安全门'));
    });

    test('未过安全门 + 有医嘱 → adjust 套用放行', () {
      final ep = episode(flags: const ['bladder'])..doctorDx = '腰突';
      final rid = fit.createRoutine('康复 A');
      fit.toggleRoutineExercise(rid, fit.matchExerciseByName('Barbell Bench Press')!.id);
      ep.routineIds = [rid];
      fit.createEpisode(ep);
      final r = fit.applyRehabReply('re1', adjustJson);
      expect(r.adjusted, greaterThan(0));
    });
  });
}
