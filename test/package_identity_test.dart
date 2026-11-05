import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 应用身份不变量（RISK-097 同源）：
/// Android 身份 = `com.kangtu.app`；namespace / applicationId / Kotlin 目录 / package 声明
/// 必须一致；广播 action 前缀同源；Dart 侧不得硬编码包名；Manifest 只用相对类名。
/// 这类改动的坑：三项不一致**只有真构建才炸**（沙箱构建不了 → 只能靠 CI）。
void main() {
  const pkg = 'com.kangtu.app';
  const oldPkg = 'com.gymmane.app';

  final gradle = File('android/app/build.gradle.kts').readAsStringSync();
  final ktDir = Directory('android/app/src/main/kotlin/com/kangtu/app');
  final ktFiles = ktDir.existsSync()
      ? ktDir.listSync().whereType<File>().where((f) => f.path.endsWith('.kt')).toList()
      : <File>[];

  test('build.gradle.kts 的 namespace 与 applicationId 都是 $pkg', () {
    expect(gradle, contains('namespace = "$pkg"'));
    expect(gradle, contains('applicationId = "$pkg"'));
    expect(gradle.contains(oldPkg), isFalse);
  });

  test('Kotlin 目录与 package 声明一致（不一致只有真构建才炸）', () {
    expect(ktDir.existsSync(), isTrue);
    expect(Directory('android/app/src/main/kotlin/com/gymmane').existsSync(), isFalse,
        reason: '旧目录必须清掉，否则 Gradle 会同时编译两套包');
    expect(ktFiles.length, greaterThanOrEqualTo(14));
    final bad = <String>[];
    for (final f in ktFiles) {
      final first = f.readAsLinesSync().firstWhere((l) => l.startsWith('package '), orElse: () => '');
      if (first != 'package $pkg') bad.add('${f.uri.pathSegments.last}: "$first"');
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('自定义广播 action 由 applicationId 派生（以后改包名自动跟随）', () {
    const names = ['LIVE_ACTION', 'NUTRI_ADD', 'NEW_DAY'];
    final derived = <String>{};
    for (final f in ktFiles) {
      final src = f.readAsStringSync();
      for (final n in names) {
        if (src.contains('BuildConfig.APPLICATION_ID + ".$n"')) derived.add(n);
      }
      // 若仍写成字面量，前缀必须与包名一致
      for (final m in RegExp(r'"(com\.[a-z0-9_.]+\.(?:LIVE_ACTION|NUTRI_ADD|NEW_DAY))"').allMatches(src)) {
        expect(m.group(1)!.startsWith('$pkg.'), isTrue, reason: '实际：${m.group(1)}');
      }
    }
    expect(derived, names.toSet(),
        reason: '三个内部广播都应派生自 BuildConfig.APPLICATION_ID，而不是写死前缀');
  });

  test('Dart 侧不得硬编码包名（动态取 PackageInfo.packageName）', () {
    for (final f in ['lib/services/home_widget_bridge.dart', 'lib/screens/settings_screen.dart']) {
      final s = File(f).readAsStringSync();
      expect(s.contains(oldPkg), isFalse, reason: '$f 残留旧包名');
      expect(s.contains(pkg), isFalse, reason: '$f 写死了新包名（应动态取）');
      expect(s.contains('PackageInfo.fromPlatform()'), isTrue, reason: '$f 应动态取包名');
    }
  });

  test('全库不得再出现旧包名', () {
    final hits = <String>[];
    // README 也要扫（分发徽章曾指向旧包名的商店页）；docs/ 是上游多语言文档、已加横幅注明，故排除
    for (final d in ['lib', 'test', 'android', '.github', 'README.md']) {
      final dir = Directory(d);
      final files = dir.existsSync()
          ? dir.listSync(recursive: true).whereType<File>()
          : [File(d)].where((f) => f.existsSync());
      for (final f in files) {
        final p = f.path.replaceAll('\\', '/');
        if (p.contains('/build/') || p.endsWith('.png') || p.endsWith('.webp') || p.endsWith('.jks')) continue;
        if (p.endsWith('test/package_identity_test.dart')) continue; // 本文件自身持有两个字面量
        String txt;
        try { txt = f.readAsStringSync(); } catch (_) { continue; }
        if (txt.contains(oldPkg) || txt.contains('com/gymmane/app')) hits.add(p);
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('Manifest 只用相对类名（namespace 一改就自动跟着走）', () {
    final mf = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(mf.contains('android:name="$pkg'), isFalse);
    expect(mf.contains(oldPkg), isFalse);
    expect(mf, contains('android:name=".MainActivity"'));
    expect(mf.contains('package='), isFalse);
  });
}
