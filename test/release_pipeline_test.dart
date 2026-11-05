import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 发布流水线守门（对应 `.github/workflows/build.yml`）。
///
/// 为什么要有：应用内「检查更新」依赖**流水线写出来的** `assets/app_version.json`
/// （版本号 / 下载地址 / 每个 ABI 的 sha256）。流水线一旦和更新器的契约脱节，
/// 用户就会「检查更新失败」或「下载校验失败」，而且**只在真机、只在发版后**才暴露。
void main() {
  final yml = File('.github/workflows/build.yml').readAsStringSync();
  final manifest =
      jsonDecode(File('assets/app_version.json').readAsStringSync()) as Map<String, dynamic>;

  const abis = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];
  final expectedNames = [for (final a in abis) 'kangtu-$a.apk'];

  test('流水线把 APK 命名成 kangtu-<abi>.apk，与清单里的下载地址逐字一致', () {
    for (final n in expectedNames) {
      expect(yml, contains(n), reason: 'build.yml 必须产出 $n');
    }
    final urls = manifest['download_urls'] as Map<String, dynamic>;
    expect(urls.keys.toList()..sort(), abis.toList()..sort());
    final fromJson = [for (final a in abis) (urls[a] as String).split('/').last];
    expect(fromJson, expectedNames, reason: '清单地址的文件名必须与流水线产物同名');
  });

  test('回写清单时**必须**给每个 ABI 算 sha256（更新模块的完整性校验靠它）', () {
    // 必须**逐个 ABI**真的算（只查 'sha256sum' 字样会被「注释掉一行」蒙混 —— 变异验证逮到过）
    for (final a in abis) {
      expect(yml, contains('sha256sum apks/kangtu-$a.apk'),
          reason: '\$a 没有真正计算哈希（回写里对应变量会拿到空值）'.replaceFirst('\$a', a));
      expect(yml, contains('"$a": "\${S'), reason: '回写 JSON 里缺 $a 的 sha256');
    }
    // 仓库里那份清单也要有（应用启动后可能直接被读到）
    final sums = manifest['sha256'] as Map<String, dynamic>?;
    expect(sums, isNotNull, reason: '清单缺 sha256 段');
    for (final a in abis) {
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch('${sums![a]}'), isTrue, reason: '$a 哈希格式不对');
    }
  });

  test('回写提交必须带 [skip ci]，否则 push 回 main 会再触发一次发布（死循环）', () {
    expect(yml, contains('chore(update): app_version.json'));
    expect(yml, contains('[skip ci]'));
  });

  test('page_url 指向具体 tag，不得用 /releases/latest（那会跳过预发行版）', () {
    expect(yml, contains('/releases/tag/'));
    expect(yml.contains('/releases/latest'), isFalse);
    expect(manifest['page_url'] as String, contains('/releases/tag/'));
  });

  test('check 门禁存在、卡在加构建号之前、有超时，且 analyze 让 warning 也挡', () {
    expect(yml, contains('\n  check:'));
    expect(yml, contains('flutter test'));
    expect(yml, contains('timeout-minutes:'), reason: '没超时上限：runner 卡死会白等 360 分钟');
    expect(yml, contains('needs: check'), reason: 'prepare 必须依赖 check');
    expect(yml, contains("needs.check.result == 'success'"));
    expect(yml, contains('flutter analyze --no-fatal-infos'), reason: '分析与出包同口径');
    expect(yml.contains('--no-fatal-warnings'), isFalse, reason: '别退回「只认 error」');
  });

  test('三套镜像 + 预发行版策略保持（用户侧更新体验）', () {
    for (final a in abis) {
      expect((manifest['mirrors'] as Map)[a], isA<List>(), reason: '$a 缺镜像链');
      expect(((manifest['mirrors'] as Map)[a] as List).length, greaterThanOrEqualTo(2));
    }
    expect(yml, contains('--prerelease'));
  });

  test('签名链路必须存在且在构建之前（缺了会静默出 debug 签名包）', () {
    // 为什么单独锁：debug keystore 是公开的 = 等于没有签名防护；而 Gradle 找不到
    // key.properties 时会**静默回落 debug 签名**，构建照样绿 —— 只有真机能发现。
    expect(yml, contains('Set up signing'), reason: '缺「设置签名」步骤');
    expect(yml, contains('base64 -d > android/app/kangtu-release.jks'), reason: '没把 keystore 落盘');
    expect(yml, contains('android/key.properties'), reason: '没生成 key.properties');
    // 顺序：签名步骤必须在 build 之前
    final iSign = yml.indexOf('Set up signing');
    final iBuild = yml.indexOf('Build split APKs');
    expect(iSign, greaterThan(-1));
    expect(iBuild, greaterThan(iSign), reason: '签名必须在构建之前');
    // Gradle 侧确实会读 key.properties（否则前面的落盘毫无作用）
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('key.properties'), reason: 'Gradle 没读 key.properties');
  });

  test('build 不允许绕过 check（dispatch 也一样）', () {
    final buildJob = yml.substring(yml.indexOf('\n  build:'));
    expect(buildJob, contains("needs.check.result == 'success'"));
    expect(buildJob.contains("if: always() && (needs.prepare.result"), isFalse,
        reason: 'always() 会让 check 红了 build 照跑');
  });
}
