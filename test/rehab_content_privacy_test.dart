// 康途定制 · 康复手册 asset（assets/rehab/content.json）的守门测试
//
// 这里两组断言，状态不同：
//
// 【生效中】结构守门 —— 此前没有任何测试碰过这份 asset，JSON 改坏只会在用户点开手册时
//   才炸（ISS-201）。手册页依赖 19 个顶层键，且 asset 必须真能被 rootBundle 经
//   `RehabData.load()` 解析（顺带守住 pubspec 的 assets 声明与打包路径）。
//   这组与内容脱不脱敏无关，长期生效。
//
// 【已暂停，等 Howe 决定】隐私棘轮（RISK-082 / RISK-093）——
//   这份 asset 原本就是我们自己那份 12 周腰痛康复计划的原文，带着可识别的病历信息：
//   姓名 + 年龄 + 影像诊断与突出毫米数（L5-S1 轻度突出 0.3cm）+ 受伤机制「搬煤气罐」
//   + CT/复诊日期 + 六条逐条病程 + 「护腰不买（9-22 已议定）」这类私人决策记录
//   + 「分不清就发消息问」私人联系渠道，而这个仓库是**公开**的（RISK-082 自 2026-10-07 挂着）。
//   2026-11-04 16:40 曾整份脱敏成通用示例（提交 `c2176c3d`，教学与训练内容一字未删）；
//   **Howe 17:16 决定「个人版先留着，等测完再决定删不删」** → 脱敏已回滚，这组棘轮转为 skip。
//
//   哪天决定脱敏：把下面两条的 `skip:` 去掉即可，它们就是当时的验收标准。
//   - 脱敏成品可直接取回：`git show c2176c3d:assets/rehab/content.json`
//   - 个人版原件另存（chmod 600）：`文件/医疗健康/康复手册原文-个人版-脱敏前备份-20261104.json`
//   - 注意脱敏只管源码；git 历史（`2f2adf8b` 引入，已在 origin/main）与 11 个已发布
//     release 的 APK（累计下载约 58 次）里仍是原文，清理与否见 RISK-093。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/services/rehab_data.dart';

/// 隐私棘轮暂停原因（见文件头注释）。决定脱敏时删掉这个常量与两处 `skip:` 即可。
const _privacyDeferred = 'RISK-093：Howe 2026-11-04 17:16 决定个人版内容先留着，'
    '测完 v1.4.0 再决定要不要脱敏；脱敏时去掉 skip 恢复棘轮（验收标准见 c2176c3d）';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const path = 'assets/rehab/content.json';
  Map<String, dynamic> read() =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  test('手册页依赖的结构完整，且 asset 能被 rootBundle 解析', () async {
    final d = read();
    for (final k in const [
      'meta', 'story', 'mustread', 'warmup', 'stretch', 'moves', 'phases',
      'trainDays', 'evalDays', 'maintainSample', 'firstDay', 'planEnd',
      'sessions', 'daily', 'monitor', 'faq', 'muscles', 'videos', 'baseline',
    ]) {
      expect(d.containsKey(k), isTrue, reason: '缺 "$k" 会让康复手册页开天窗');
    }
    // meta 的必填字段：手册页头部与暂停横幅都读它
    final meta = metaOf(d);
    for (final k in const ['appTitle', 'subtitle', 'target', 'disclaimer', 'paused']) {
      expect(meta.containsKey(k), isTrue, reason: 'meta 缺 "$k"');
    }
    expect(meta['paused'], isA<bool>(), reason: 'paused 必须是 bool，暂停横幅按它分支');
    // paused 为真时，横幅三件套必须都有文案，否则渲染出来是空白条
    if (meta['paused'] == true) {
      for (final k in const ['pauseTitle', 'pauseDate', 'pauseText']) {
        expect((meta[k]?.toString() ?? '').isNotEmpty, isTrue,
            reason: 'paused=true 但 meta.$k 为空 → 暂停横幅开天窗');
      }
    }
    expect((d['story']! as List), isNotEmpty, reason: '病程为空 → 时间线区块渲染不出来');
    expect((d['sessions']! as List), isNotEmpty);
    expect(((d['baseline']! as Map)['fields']! as List), isNotEmpty);

    await RehabData.load();
    expect(RehabData.ready, isTrue, reason: 'rootBundle 加载失败 = 打包路径/pubspec 声明被改坏');
    expect(RehabData.meta()['subtitle'], isNotEmpty);
    expect(RehabData.a('story'), isNotEmpty);
    expect(RehabData.o('mustread')['lead'], isNotEmpty);
    expect(RehabData.a('sessions'), isNotEmpty);
    expect(RehabData.o('baseline')['fields'], isNotEmpty);
  });

  test('康复手册 asset 不含个人病历信息（RISK-082 棘轮）', () {
    final raw = File(path).readAsStringSync();
    const banned = [
      'Howe', // 姓名
      '29 岁', // 年龄
      '0.3cm', // 影像测量值
      '煤气罐', // 受伤机制（高度可识别）
      'CT 确诊',
      'CT 报告',
      '发消息问', // 私人联系渠道
      '已议定', // 私人决策记录
      '国庆假期', // 与真实日历绑定的私人痕迹
      '222.222', // 早先笔记里提过的假 IP，一并守住（实测全仓库 0 命中，ISS-202）
    ];
    for (final b in banned) {
      expect(raw.contains(b), isFalse, reason: '公开仓库不能带个人病历/私人痕迹：$b');
    }
    expect(RegExp(r'\d+\s*岁').hasMatch(raw), isFalse, reason: '全文不能出现年龄');

    final meta = metaOf(read());
    expect(meta['paused'], isFalse, reason: '出厂不该显示「计划暂停中」——那是个人状态');
    final target = meta['target']!.toString();
    expect(target, contains('示例'), reason: '适用对象要写明是示例档案');
    expect(RegExp(r'\d+(\.\d+)?\s*(cm|厘米)').hasMatch(target), isFalse, reason: '不能带测量值');
    expect(meta['disclaimer'].toString(), contains('不是任何人的病历'));
  }, skip: _privacyDeferred);

  test('病程时间线用相对周次，不用真实日期', () {
    final story = (read()['story']! as List).cast<Map<String, dynamic>>();
    expect(story, isNotEmpty);
    for (final s in story) {
      expect(RegExp(r'^\d{1,2}-\d{1,2}$').hasMatch(s['when'].toString()), isFalse,
          reason: 'story.when 应是「第 N 周」这类相对标签，实际是 ${s['when']}');
      expect(RegExp(r'\d+(\.\d+)?\s*(cm|厘米)').hasMatch(s['d'].toString()), isFalse,
          reason: '病程叙述不能带影像测量值：${s['d']}');
    }
    expect(story.last['now'], isTrue, reason: '末条仍标 now，手册页要高亮当前节点');
  }, skip: _privacyDeferred);
}

/// meta 的取值 helper（避免每处都写一遍 cast）。
Map<String, dynamic> metaOf(Map<String, dynamic> d) =>
    (d['meta']! as Map).cast<String, dynamic>();
