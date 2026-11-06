import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ISS-208 守门：隐私披露文案必须与实现一致。
///
/// 背景：上游 2.0.0 的 `stepsInfoRead` / `healthPickHint` 向用户保证
/// 「只读取步数，不读取其他任何内容，也不会写入 Health Connect」「数据只读取」，
/// 但同一个包里：
///   - `android/app/src/main/AndroidManifest.xml` 声明了 `health.WRITE_EXERCISE`
///     与 15 项 `health.READ_*`；
///   - `HealthBridge.kt` 调 `insertRecords` / `deleteRecords`（写 ExerciseSessionRecord）；
///   - `lib/services/health_metrics.dart` 的 `writeWorkout()` 被
///     `lib/state/health_state.dart` 实际调用（开启「健康数据」时请求授权并写入）。
/// 即：文案是假的。行为本身合规（opt-in + 系统授权弹窗），但披露不实。
///
/// 本文件把这个「文案不得与实现矛盾」固化成断言，防止后续同步把上游原文取回来。
void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final declaresWrite = manifest.contains('android.permission.health.WRITE_EXERCISE');
  final dartWrites = File('lib/services/health_metrics.dart').readAsStringSync().contains("'writeWorkout'") &&
      File('lib/state/health_state.dart').readAsStringSync().contains('writeWorkout(');

  Map<String, dynamic> arb(String code) =>
      jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync()) as Map<String, dynamic>;

  /// 各语种「写入」一词的识别式（只有定义了该 key 的语种需要命中）
  final writeWord = <String, RegExp>{
    'en': RegExp(r'\bwrit(ten|e|es)\b', caseSensitive: false),
    'zh': RegExp('写回|写入'),
    'zh_Hant': RegExp('寫回|寫入'),
    'es': RegExp(r'\bescrib(en|e|o)\b|escritura', caseSensitive: false),
  };

  /// 上游那句假话的各语种原文（一旦出现即红）
  const falseClaims = <String>[
    'never reads anything else or writes to Health Connect', // en
    '不读取其他任何内容，也不会写入', // zh
    '不讀取其他任何內容，也不會寫入', // zh_Hant
    '数据只读取，永远不会离开手机', // zh
    '資料只讀取，永遠不會離開手機', // zh_Hant
    'nunca lee nada más ni escribe en Health Connect', // es
    'It never reads anything else', // en（全局绝对化断言）
  ];

  test('前提成立：本包确实会写 Health Connect（否则本文件的断言无意义）', () {
    expect(declaresWrite, isTrue, reason: 'Manifest 应声明 health.WRITE_EXERCISE');
    expect(dartWrites, isTrue, reason: 'Dart 侧应真的有 writeWorkout 调用链');
  });

  test('任何语种的文案都不得再出现「不会写入 / 只读取」这类与实现矛盾的保证', () {
    final hits = <String>[];
    for (final f in Directory('lib/l10n').listSync().whereType<File>().where((f) => f.path.endsWith('.arb'))) {
      final code = f.uri.pathSegments.last.replaceAll('app_', '').replaceAll('.arb', '');
      final data = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      data.forEach((k, v) {
        if (v is! String || k.startsWith('@')) return;
        for (final bad in falseClaims) {
          if (v.contains(bad)) hits.add('$code.$k: "$bad"');
        }
      });
    }
    expect(hits, isEmpty,
        reason: '隐私披露与实现不符（app 确实会写 Health Connect）：\n${hits.join('\n')}');
  });

  test('凡是定义了 healthPickHint 的语种，都必须向用户披露「会写入」', () {
    final defined = <String, String>{};
    for (final f in Directory('lib/l10n').listSync().whereType<File>().where((f) => f.path.endsWith('.arb'))) {
      final code = f.uri.pathSegments.last.replaceAll('app_', '').replaceAll('.arb', '');
      final v = arb(code)['healthPickHint'];
      if (v is String) defined[code] = v;
    }
    expect(defined.keys, containsAll(<String>['en', 'zh', 'zh_Hant']),
        reason: '康途的主要语种必须自带准确文案，不能靠回落');
    for (final e in defined.entries) {
      final re = writeWord[e.key];
      expect(re, isNotNull,
          reason: '语种 ${e.key} 定义了 healthPickHint，但本文件没有它的「写入」识别式；'
              '请要么补识别式并确认文案准确，要么删掉该 key 让它回落到准确的英文'
              '（并把 key 登记进 test/nutrition_beta_keys.txt）');
      expect(re!.hasMatch(e.value), isTrue,
          reason: '${e.key}.healthPickHint 没有披露「会写入 Health Connect」：${e.value}');
    }
  });

  test('stepsInfoRead 不得再做全局绝对化承诺，只能限定在「这一项/这张卡」', () {
    for (final code in ['en', 'zh', 'zh_Hant', 'es']) {
      final v = arb(code)['stepsInfoRead'];
      expect(v, isA<String>(), reason: '$code 应自带 stepsInfoRead');
      expect((v as String).length < 200, isTrue, reason: '$code.stepsInfoRead 过长，可能塞进了不必要的承诺');
      for (final bad in ['never reads anything else', '不读取其他任何内容', '不讀取其他任何內容', 'nunca lee nada más']) {
        expect(v.contains(bad), isFalse, reason: '$code.stepsInfoRead 仍含全局绝对化承诺：$bad');
      }
    }
  });

  test('README 不得在声明了 INTERNET 的情况下宣称「没有网络权限」', () {
    final declaresInternet = manifest.contains('android.permission.INTERNET');
    final readme = File('README.md').readAsStringSync();
    if (!declaresInternet) return; // 若哪天真的移除了联网能力，这条自动失效
    for (final bad in ['没有网络权限', '不申请网络权限', '也没有**网络权限**', '甚至没有网络权限']) {
      expect(readme.contains(bad), isFalse,
          reason: 'Manifest 声明了 INTERNET（「检查更新」会拉版本号文件并可下载 APK），'
              'README 不得宣称没有网络权限：$bad');
    }
    expect(readme.contains('检查更新'), isTrue, reason: 'README 应说明联网只发生在手动「检查更新」时');
    expect(readme.contains('Health Connect'), isTrue, reason: 'README 的隐私节应披露 Health Connect 读写');
  });

  test('被删掉两个 key 的语种必须登记在豁免清单里（否则 i18n 一致性测试会红）', () {
    final beta = File('test/nutrition_beta_keys.txt')
        .readAsLinesSync()
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toSet();
    for (final key in ['stepsInfoRead', 'healthPickHint']) {
      final missing = <String>[];
      for (final f in Directory('lib/l10n').listSync().whereType<File>().where((f) => f.path.endsWith('.arb'))) {
        final code = f.uri.pathSegments.last.replaceAll('app_', '').replaceAll('.arb', '');
        if (!arb(code).containsKey(key)) missing.add(code);
      }
      if (missing.isNotEmpty) {
        expect(beta, contains(key),
            reason: '$key 在 ${missing.join(', ')} 中缺失（回落到英文），必须登记进 test/nutrition_beta_keys.txt');
      }
    }
  });

  test('非主要语种不得自带隐私披露键（必须回落到准确的英文）', () {
    // ISS-2xx：13 个非主要语种曾保留上游译文，内容是假的（如 de「schreibt nichts in
    // Health Connect」、ru「никогда не подключается к интернету」）。字面短语扫描只覆盖
    // en/zh/zh_Hant/es，扫不到别的语言 → 这里改成「结构性」断言：这些键根本不许出现。
    const primary = {'en', 'zh', 'zh_Hant', 'es'};
    const guarded = ['stepsInfoRead', 'stepsInfoLocal', 'fullyOffline', 'fullyOfflineWhy', 'welcomeBlurb', 'healthPickHint'];
    final bad = <String>[];
    for (final f in Directory('lib/l10n').listSync().whereType<File>().where((f) => f.path.endsWith('.arb'))) {
      final code = f.uri.pathSegments.last.replaceAll('app_', '').replaceAll('.arb', '');
      if (primary.contains(code)) continue;
      final data = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      for (final k in guarded) {
        if (data.containsKey(k)) bad.add('$code.$k');
      }
    }
    expect(bad, isEmpty, reason: '非主要语种不得自带披露键（要回落到准确英文）：${bad.join('、')}');
  });

  test('es 的披露键必须是西语准确文案，不得直接沿用英文', () {
    final en = arb('en');
    final es = arb('es');
    final same = <String>[];
    for (final k in ['stepsInfoRead', 'stepsInfoLocal', 'fullyOffline', 'fullyOfflineWhy', 'welcomeBlurb']) {
      final v = es[k];
      expect(v, isA<String>(), reason: 'es 必须自带 $k（es 是主要语种，不靠回落）');
      if (v == en[k]) same.add(k);
    }
    expect(same, isEmpty, reason: 'es 这些键与英文完全相同，疑似忘了翻译：${same.join('、')}');
    expect(RegExp(r'actualizacion', caseSensitive: false).hasMatch('${es['fullyOfflineWhy']}'), isTrue,
        reason: 'es.fullyOfflineWhy 应说明「只有检查更新会联网」');
  });
}
