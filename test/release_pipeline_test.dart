import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ISS-215 守门：发布流水线的命名与回写必须自洽。
///
/// 背景：仓库里有**两条** workflow ——
/// - `.github/workflows/build.yml`（名 "build-apk"）：**权威流水线**，push main 触发，
///   自动加构建号 → 构建 → 重命名 `kangtu-<abi>.apk` → 发 Release → **回写
///   `assets/app_version.json`**（应用内「检查更新」读的就是它）。
/// - `.github/workflows/build-apk.yml`：上游的 F-Droid 可复现构建配方，只在
///   pull_request / 手动 dispatch 时跑，**不回写** app_version.json。
///
/// 曾经两条的资产命名不一致（后者是 `康途-<版本>-<abi>.apk`），手动 dispatch 就会发出
/// 一版中文名资产、和应用内更新通道对不上。本文件把「命名同源 + 回写存在 + 预发行版
/// 策略 + page_url 不用 latest」钉住。
void main() {
  final buildYml = File('.github/workflows/build.yml').readAsStringSync();
  final legacyYml = File('.github/workflows/build-apk.yml').readAsStringSync();
  final manifest = jsonDecode(File('assets/app_version.json').readAsStringSync()) as Map<String, dynamic>;

  const abis = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];
  final expectedNames = [for (final a in abis) 'kangtu-$a.apk'];

  test('权威流水线重命名出的 APK 名，与 app_version.json 的下载地址逐字一致', () {
    final urls = manifest['download_urls'] as Map<String, dynamic>;
    expect(urls.keys.toList(), abis, reason: 'ABI 清单应与流水线构建的三份一致');
    final fromJson = [for (final a in abis) (urls[a] as String).split('/').last];
    expect(fromJson, expectedNames);
    for (final n in expectedNames) {
      expect(buildYml, contains(n), reason: 'build.yml 必须产出 $n（否则更新通道 404）');
    }
  });

  test('遗留 workflow 的资产命名已对齐，且两条都不再用中文资产名', () {
    for (final n in expectedNames) {
      expect(legacyYml, contains(n), reason: 'build-apk.yml 手动 dispatch 时也应产出同名资产');
    }
    expect(legacyYml.contains('康途-'), isFalse, reason: '中文资产名会与 app_version.json 脱节（ISS-215）');
    expect(buildYml.contains('康途-'), isFalse);
    // Release 标题保留中文（人看的是标题，机器用的是文件名）
    expect(legacyYml, contains('name: 康途 '), reason: 'Release 标题仍应是中文「康途 <tag>」');
    expect(buildYml, contains('TITLE="康途 '), reason: '同上');
  });

  test('权威流水线会回写 app_version.json，且回写提交带 [skip ci] 防止发布循环', () {
    expect(buildYml, contains('assets/app_version.json'), reason: '缺了回写，应用内就永远看不到新版本');
    expect(buildYml, contains('Write back assets/app_version.json'));
    expect(buildYml, contains('[skip ci]'),
        reason: '回写提交必须带 [skip ci]：它 push 回 main，否则会再触发一次构建→发布→回写的死循环');
  });

  test('一律发预发行版（Howe 2026-10-25 定），两条 workflow 都保持', () {
    expect(buildYml, contains('--prerelease'), reason: 'gh release create/edit 都要带 --prerelease');
    expect(legacyYml, contains('prerelease: true'));
  });

  test('page_url 指向具体 tag，不得用 /releases/latest（那会跳过预发行版）', () {
    final page = manifest['page_url'] as String;
    expect(page, contains('/releases/tag/'), reason: '因为我们一律发预发行版，latest 会解析不到');
    expect(page.contains('/releases/latest'), isFalse);
    expect(buildYml, contains('/releases/tag/'), reason: '回写逻辑也必须用 tag 形式');
  });

  test('三个 ABI 都配了国内中转镜像，且每个至少 2 条（单点失效可切换）', () {
    final mirrors = manifest['mirrors'] as Map<String, dynamic>;
    for (final a in abis) {
      final list = (mirrors[a] as List).cast<String>();
      expect(list.length, greaterThanOrEqualTo(2), reason: '$a 的镜像太少，挂了就没得切');
      for (final u in list) {
        expect(u.startsWith('https://'), isTrue);
        expect(u, contains('kangtu-$a.apk'), reason: '镜像 URL 的文件名必须与直链一致');
      }
    }
    // 直链也必须存在（镜像全挂时的兜底）
    for (final a in abis) {
      expect((manifest['download_urls'] as Map)[a], contains('github.com'));
    }
  });

  test('发行说明支持置顶块（把「先导出备份」这类话送进更新弹窗的 desc）', () {
    expect(buildYml, contains('docs/RELEASE_HEAD.md'),
        reason: 'desc 取自 notes.md，只有把提示置顶进 notes.md 才会在更新弹窗里被看到');
    final head = File('docs/RELEASE_HEAD.md');
    if (head.existsSync()) {
      final txt = head.readAsStringSync();
      expect(txt.trim(), isNotEmpty);
      // 包名变更版的置顶块必须讲清迁移，否则老用户会以为数据丢了（RISK-102）
      if (txt.contains('com.kangtu.app')) {
        expect(txt, contains('备份'), reason: '换包名的那一版必须写明「先导出备份」');
        expect(txt, contains('导入'), reason: '要给出导入步骤，不能只吓人不给出路');
      }
    }
  });

  test('build.yml 有 check 门禁，且卡在 prepare（加构建号）之前 —— 红了零副作用', () {
    expect(buildYml, contains('\n  check:'),
        reason: '门禁 job 不见了？我们直接 push main，没有它等于本地测试在 CI 上没人复核');
    expect(buildYml, contains('flutter test --no-pub'), reason: '门禁必须真跑测试');
    expect(buildYml, contains('timeout-minutes:'),
        reason: 'job 没超时上限：runner 卡死会白等 GitHub 默认的 360 分钟（本地实测过 flutter test 卡死）');
    final iCheck = buildYml.indexOf('\n  check:');
    final iPrep = buildYml.indexOf('\n  prepare:');
    expect(iCheck, greaterThan(-1));
    expect(iCheck, lessThan(iPrep), reason: 'check 必须写在 prepare 之前（否则会先加构建号再发现测试红）');
    expect(buildYml, contains('needs: check'), reason: 'prepare 必须依赖 check');
    expect(buildYml, contains("needs.check.result == 'success'"), reason: 'prepare 的条件必须要求 check 成功');
    expect(buildYml, contains('needs: [check, prepare]'), reason: 'build 也必须依赖 check');
  });

  test('门禁与出包用同一个 Flutter 版本（否则门禁验的不是要发的那个构建）', () {
    final versions = RegExp(r'flutter-version:\s*([\d.]+)')
        .allMatches(buildYml)
        .map((m) => m.group(1)!)
        .toSet();
    expect(versions.length, 1, reason: 'build.yml 里 Flutter 版本应只有一处（check 与 build 共用）：$versions');
  });

  test('人工发布正文接进了 CI：docs/RELEASE_NOTES.md 存在则替代自动提交列表', () {
    expect(buildYml, contains('docs/RELEASE_NOTES.md'),
        reason: '机制不见了 → Release 正文会退回机械的提交标题列表');
    final f = File('docs/RELEASE_NOTES.md');
    if (!f.existsSync()) return; // 没有该文件即走自动列表，属合法状态
    final raw = f.readAsStringSync();
    expect(raw.trim(), isNotEmpty);
    // 用户视角的正文里不得出现内部编号/台账用语（先剥掉对用户不可见的 HTML 注释）
    final visible = raw.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
    for (final bad in ['ISS-', 'RISK-', 'EV-', '台账']) {
      expect(visible.contains(bad), isFalse, reason: '发布正文是给用户看的，不该出现内部标记 "$bad"');
    }
    expect(visible.trim(), isNotEmpty, reason: '剥掉注释后正文不能是空的');
  });

  test('CI 的 analyze 必须让 warning 也挡（别退回只认 error）', () {
    expect(buildYml, contains('flutter analyze --no-fatal-infos'),
        reason: '收紧后的门禁口径：只放行 info，warning/error 一律挡');
    expect(buildYml.contains('--no-fatal-warnings'), isFalse,
        reason: '退回「只认 error」会让 warning 级问题溜进发布');
  });
}
