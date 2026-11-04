import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ISS-213 守门：CJK 硬编码棘轮的**扫描盲区**。
///
/// 原有棘轮（`test/i18n_test.dart` 的 `no new CJK strings hard-coded in the widgets`）
/// 只扫 `lib/screens`、`lib/widgets`、`lib/app` 三个目录，于是
/// `lib/state/fit_state.dart` 里那段**用户可见的康复提示词**一直是硬编码中文：
/// 它会被复制到剪贴板交给外部 AI（`rehabPromptText`），非中文用户导出的是中文提示词，
/// 外部 AI 大概率也用中文回答，回答再被贴回来（`applyRehabReply`）显示在界面上。
/// 同目录还有 `applyRehabAdjust` / `applyRehabReply` 返回的 `missed[]` 说明文案，
/// 这些也会直接显示给用户。
///
/// 一次还清成本不小（提示词约 40 行、含大量插值，要抽成 arb 并覆盖 17 语种），
/// 所以先按规程做**计数棘轮**：登记现状基线，只许减不许增，新文件出现中文即红。
/// 债还清一个文件就从基线里删一个；基线数字禁止往上调。
void main() {
  /// 基线：文件 → 含中文的字符串字面量计数（2026-11-04 首测共 66 处；
  /// 同日 RISK-100 把 `fit_state.dart` 的康复提示词抽进 arb 后，该文件已归零 → 从基线删除）。
  /// 计数口径 = 本文件 `scan()` 的口径（单引号与双引号两套正则分别计数），
  /// 与 `test/i18n_test.dart` 里那条棘轮不完全相同，**不要拿两边的数字互相对账**；
  /// 棘轮只要求「同一口径下不许涨」。
  const baseline = <String, int>{
    // 唯一保留项：这些中文是 **AI 回帖里可能出现的字段名**（机器匹配用，见 rehab_intake.dart 行内注释），
    // 不是界面文案 —— 多一种写法能多接住一类回复，故有意保留。
    'lib/services/rehab_intake.dart': 1,
  };

  /// 与原棘轮同口径：跳过注释行，只数字符串字面量里的中文
  Map<String, int> scan() {
    final cjk = RegExp(r'[\u4e00-\u9fff]');
    final lits = [RegExp(r"'([^'\n]*)'"), RegExp(r'"([^"\n]*)"')];
    final dirs = [Directory('lib/state'), Directory('lib/services'), Directory('lib/models')];
    final out = <String, int>{};
    for (final d in dirs) {
      if (!d.existsSync()) continue;
      for (final f in d.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        var n = 0;
        for (final raw in f.readAsLinesSync()) {
          final s = raw.trim();
          if (s.startsWith('//') || s.startsWith('*') || s.startsWith('/*')) continue;
          if (!cjk.hasMatch(s)) continue;
          for (final re in lits) {
            for (final m in re.allMatches(s)) {
              if (cjk.hasMatch(m.group(1) ?? '')) n++;
            }
          }
        }
        if (n > 0) out[f.path.replaceAll('\\', '/')] = n;
      }
    }
    return out;
  }

  test('lib/state · lib/services · lib/models 不得新增硬编码中文（计数棘轮）', () {
    final actual = scan();
    final total = actual.values.fold(0, (a, b) => a + b);

    // 新出现的文件：一律不许有中文（走 arb）
    final newFiles = actual.keys.where((k) => !baseline.containsKey(k)).toList()..sort();
    expect(newFiles, isEmpty,
        reason: '这些文件在 lib/state|services|models 里新出现了硬编码中文，'
            '用户可见文案一律走 t.xxx（arb），否则另外 16 种语言会看到中文：\n'
            '${newFiles.map((f) => '  $f: ${actual[f]} 处').join('\n')}');

    // 已登记的债：只许减不许增
    final grew = <String>[];
    for (final e in baseline.entries) {
      final now = actual[e.key] ?? 0;
      if (now > e.value) grew.add('${e.key}: ${e.value} → $now');
    }
    expect(grew, isEmpty,
        reason: '已登记的中文债只许减不许增（ISS-213 棘轮）：\n${grew.join('\n')}\n'
            '新增文案请走 arb；确实减少了的话，把基线数字同步调低。');

    // 还清的文件应从基线移除，避免基线变成「允许再次欠债」的额度
    final cleared = baseline.keys.where((k) => (actual[k] ?? 0) == 0).toList()..sort();
    expect(cleared, isEmpty,
        reason: '这些文件的中文债已还清，请从基线里删掉（基线不是额度）：\n${cleared.join('\n')}');

    expect(total, lessThanOrEqualTo(66), reason: '总中文债不得超过登记时的 66 处，当前 $total');
  });

  test('基线本身没有虚报：每个登记文件当前确实存在且计数吻合', () {
    final actual = scan();
    for (final e in baseline.entries) {
      expect(File(e.key).existsSync(), isTrue, reason: '基线登记的文件已不存在：${e.key}');
      expect(actual[e.key], e.value,
          reason: '${e.key} 的中文计数与基线不符（减少是好事，请把基线调低；增加则违反棘轮）');
    }
  });
}
