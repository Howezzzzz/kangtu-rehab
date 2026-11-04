import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// RISK-097 / ISS-216 守门：Android 应用身份 = `com.kangtu.app`。
///
/// 背景：本 fork 长期沿用上游的 `com.gymmane.app`，导致 ① 装过上游 GymMane 的设备
/// 因签名不同装不上康途、两个 app 不能共存；② 显示名「康途」与包名不符。
/// Howe 2026-11-04 20:12 决定改为 `com.kangtu.app`。
///
/// 这类改动的坑在于：**namespace、applicationId、Kotlin 目录、Kotlin `package` 声明、
/// 以及散落在 Dart/CI 里的包名字符串**必须同时一致，而其中「目录 ↔ package 声明」
/// 不一致只有真正跑 Gradle 构建才会暴露（沙箱构建不了 → 只能靠 CI）。
/// 本文件把能在静态层钉住的全部钉住，减少 CI 往返。
void main() {
  const pkg = 'com.kangtu.app';
  const oldPkg = 'com.gymmane.app';

  final gradle = File('android/app/build.gradle.kts').readAsStringSync();
  final ktDir = Directory('android/app/src/main/kotlin/com/kangtu/app');
  final ktFiles = ktDir.existsSync()
      ? ktDir.listSync().whereType<File>().where((f) => f.path.endsWith('.kt')).toList()
      : <File>[];

  test('build.gradle.kts 的 namespace 与 applicationId 都是 $pkg', () {
    expect(gradle, contains('namespace = "$pkg"'), reason: 'namespace 决定 R 类与 Manifest 相对类名的解析基准');
    expect(gradle, contains('applicationId = "$pkg"'), reason: 'applicationId 才是用户在系统里看到的应用身份');
    expect(gradle.contains(oldPkg), isFalse, reason: 'gradle 里不得残留旧包名');
  });

  test('Kotlin 源码目录与 package 声明一致（不一致只有真构建才炸）', () {
    expect(ktDir.existsSync(), isTrue, reason: '应有 android/app/src/main/kotlin/com/kangtu/app/');
    expect(Directory('android/app/src/main/kotlin/com/gymmane').existsSync(), isFalse,
        reason: '旧目录 com/gymmane 必须清掉，否则 Gradle 会同时编译两套包');
    expect(ktFiles.length, greaterThanOrEqualTo(13), reason: '13 个原生桥/小组件文件应全部迁移过来');
    final bad = <String>[];
    for (final f in ktFiles) {
      final first = f.readAsLinesSync().firstWhere((l) => l.startsWith('package '), orElse: () => '');
      if (first != 'package $pkg') bad.add('${f.uri.pathSegments.last}: "$first"');
    }
    expect(bad, isEmpty, reason: 'package 声明必须与新目录一致：\n${bad.join('\n')}');
  });

  test('自定义广播 action 的前缀跟着包名走（否则显式 Intent 失效）', () {
    final actions = <String>[];
    for (final f in ktFiles) {
      for (final m in RegExp(r'"(com\.[a-z0-9_.]+\.(?:LIVE_ACTION|NUTRI_ADD|NEW_DAY))"').allMatches(f.readAsStringSync())) {
        actions.add(m.group(1)!);
      }
    }
    expect(actions, isNotEmpty, reason: '应扫到 LIVE_ACTION / NUTRI_ADD / NEW_DAY 三个内部广播');
    for (final a in actions) {
      expect(a.startsWith('$pkg.'), isTrue, reason: '广播 action 前缀应与 applicationId 同源，实际：$a');
    }
  });

  test('Dart 侧不得硬编码包名（动态取 PackageInfo.packageName）', () {
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();
    // 固定小组件（requestPinWidget）需要「包名.类名」的全限定名
    expect(settings, contains('qualifiedAndroidName:'), reason: '固定小组件的调用点应还在');
    final line = settings
        .split('\n')
        .firstWhere((l) => l.contains('qualifiedAndroidName:'), orElse: () => '');
    expect(line.contains('packageName'), isTrue,
        reason: '包名必须动态取（PackageInfo.fromPlatform().packageName），'
            '写死的话下次改包名会静默失败并被 catch (_) 吞成「不支持固定小组件」。实际：${line.trim()}');
    expect(settings.contains(oldPkg), isFalse, reason: '注释里也不许出现旧包名字面量');
    expect(settings.contains(pkg), isFalse, reason: '也不应写死新包名，保持动态');

    // 桌面小组件的刷新通道同样不得写死包名：`_reload()` 用它拼 qualifiedAndroidName，
    // 写死会让 8 个小组件（今日/连续/本周/营养/喝水/恢复/进度环/周容量）全部静默停止
    // 刷新，而外层 try/catch 只 debugPrint（ISS-216）。
    final bridge = File('lib/services/home_widget_bridge.dart').readAsStringSync();
    expect(bridge, contains('PackageInfo.fromPlatform()).packageName'),
        reason: 'home_widget_bridge 必须动态解析包名');
    expect(bridge.contains(oldPkg), isFalse);
    expect(bridge.contains(pkg), isFalse, reason: 'group id 也应由包名拼出，不写死');
    expect(bridge.contains("static const _pkg = '"), isFalse, reason: '不得再把包名写成常量');
  });

  test('全库不得再出现旧包名（docs/ 下上游的多语言 README 例外）', () {
    final hits = <String>[];
    for (final d in [Directory('lib'), Directory('test'), Directory('android'), Directory('.github')]) {
      if (!d.existsSync()) continue;
      for (final f in d.listSync(recursive: true).whereType<File>()) {
        final p2 = f.path;
        if (p2.endsWith('test/package_identity_test.dart')) continue; // 守门测试自身必须持有两个字面量常量
        if (p2.contains('/build/') || p2.endsWith('.jks') || p2.endsWith('.png') || p2.endsWith('.webp')) continue;
        String txt;
        try {
          txt = f.readAsStringSync();
        } catch (_) {
          continue; // 二进制
        }
        if (txt.contains(oldPkg) || txt.contains('com/gymmane/app')) {
          hits.add(p2.replaceAll('\\', '/'));
        }
      }
    }
    expect(hits, isEmpty,
        reason: '旧包名残留会让「固定小组件 / 系统设置跳转 / 签名之外的身份判断」静默失效：\n${hits.join('\n')}');
  });

  test('Manifest 只用相对类名（namespace 一改就自动跟着走）', () {
    final mf = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(mf.contains('android:name="$pkg'), isFalse, reason: '不应出现自己类的绝对包名写法');
    expect(mf.contains(oldPkg), isFalse);
    expect(mf, contains('android:name=".MainActivity"'), reason: '主 Activity 应保持相对写法');
    expect(mf.contains('package='), isFalse, reason: 'Manifest 不应再写 package 属性（由 gradle namespace 提供）');
  });

  test('CI 里 keystore 落地文件名前后一致（写错会导致签名步骤失败）', () {
    final yml = File('.github/workflows/build-apk.yml').readAsStringSync();
    final written = RegExp(r'>\s*android/app/([\w.-]+\.jks)').allMatches(yml).map((m) => m.group(1)!).toSet();
    final referenced = RegExp(r'storeFile=([\w.-]+\.jks)').allMatches(yml).map((m) => m.group(1)!).toSet();
    expect(written, isNotEmpty, reason: '应扫到 CI 写入 keystore 的那一步');
    expect(referenced, written, reason: 'storeFile 引用的文件名必须与写入的一致');
    expect(yml.contains('gymmane-release.jks'), isFalse, reason: '品牌残留');
  });
}
