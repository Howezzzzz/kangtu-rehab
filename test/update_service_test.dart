import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/services/update_service.dart';

/// 更新模块的守门（RISK-086 之后的安全加固）：
/// ① 版本号口径（ABI 后缀 ×10 的还原）；② 清单解析（含 sha256/镜像链）；
/// ③ **下载校验**：哈希不符必须删包并拒装；④ **安装前签名比对**：不一致必须拒装。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('版本号口径', () {
    test('ABI 后缀版 versionCode 还原成构建号', () {
      expect(UpdateService.buildNumberFromVersionCode(362), 36); // arm64: 36*10+2
      expect(UpdateService.buildNumberFromVersionCode(361), 36); // v7a
      expect(UpdateService.buildNumberFromVersionCode(363), 36); // x86_64
      expect(UpdateService.buildNumberFromVersionCode(5), 5); // 未加后缀（调试包）原样
    });

    test('hasUpdate 只看构建号，且当前构建号为 0 时不误报', () {
      final info = UpdateInfo(version: '9.9.9', build: 99, desc: '', downloadUrls: const {}, pageUrl: 'x');
      expect(UpdateCheckResult(ok: true, info: info, currentVersion: '1.0.0', currentBuild: 36).hasUpdate, isTrue);
      expect(UpdateCheckResult(ok: true, info: info, currentVersion: '1.0.0', currentBuild: 99).hasUpdate, isFalse);
      expect(UpdateCheckResult(ok: true, info: info, currentVersion: '', currentBuild: 0).hasUpdate, isFalse);
      expect(const UpdateCheckResult(ok: false, currentVersion: '1.0.0', currentBuild: 36).hasUpdate, isFalse);
    });
  });

  group('清单解析', () {
    final raw = jsonEncode({
      'version': '1.4.0',
      'version_code': 36,
      'desc': 'd',
      'page_url': 'https://example.com/tag',
      'download_urls': {'arm64-v8a': 'https://a/arm64.apk'},
      'mirrors': {'arm64-v8a': ['https://m1/arm64.apk', 'https://m2/arm64.apk']},
      'sha256': {'arm64-v8a': 'SHA256:AAbb', 'armeabi-v7a': '  '},
    });

    test('解析出 sha256（小写化、去 sha256: 前缀、丢弃空值）', () {
      final info = UpdateInfo.parse(raw)!;
      expect(info.checksums['arm64-v8a'], 'aabb');
      expect(info.checksums.containsKey('armeabi-v7a'), isFalse);
      expect(info.build, 36);
      expect(info.mirrorChains['arm64-v8a']!.length, 2);
    });

    test('旧清单没有 sha256 字段 → 空表（向后兼容）', () {
      final old = jsonEncode({'version': '1.0.0', 'version_code': 5, 'page_url': 'p', 'download_urls': <String, String>{}});
      expect(UpdateInfo.parse(old)!.checksums, isEmpty);
    });

    test('机器可读的清单文件（仓库内那份）可解析且哈希是 64 位十六进制', () {
      final info = UpdateInfo.parse(File('assets/app_version.json').readAsStringSync())!;
      expect(info.build, greaterThan(0));
      for (final v in info.checksums.values) {
        expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(v), isTrue, reason: '哈希格式不对：$v');
      }
    });
  });

  group('下载校验（哈希不符必须删包并拒装）', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('upd'));
    tearDown(() { try { tmp.deleteSync(recursive: true); } catch (_) {} });

    Future<void> fakeDownload(String url, File file, void Function(double?)? onProgress) async {
      await file.writeAsBytes(utf8.encode('APK-CONTENT'));
      onProgress?.call(1);
    }

    test('哈希一致 → 返回文件', () async {
      final want = sha256.convert(utf8.encode('APK-CONTENT')).toString();
      final f = File('${tmp.path}/a.apk');
      final out = await UpdateService.fetchVerified(f, const ['https://x/a.apk'], checksum: want, one: fakeDownload);
      expect(out.existsSync(), isTrue);
    });

    test('哈希不符 → 抛 ChecksumException 且不留残包', () async {
      final f = File('${tmp.path}/b.apk');
      await expectLater(
        UpdateService.fetchVerified(f, const ['https://x/b.apk'],
            checksum: 'deadbeef' * 8, one: fakeDownload),
        throwsA(isA<ChecksumException>()),
      );
      expect(f.existsSync(), isFalse, reason: '校验失败必须删掉文件');
    });

    test('某个源哈希不符 → 换下一个镜像继续试（不是整体失败）', () async {
      final good = sha256.convert(utf8.encode('GOOD')).toString();
      var calls = 0;
      Future<void> fakeOne(String url, File file, void Function(double?)? p) async {
        calls++;
        await file.writeAsBytes(utf8.encode(url.contains('tampered') ? 'TAMPERED' : 'GOOD'));
      }

      final f = File('${tmp.path}/retry.apk');
      final out = await UpdateService.fetchVerified(
          f, const ['https://tampered/a.apk', 'https://ok/a.apk'],
          checksum: good, one: fakeOne);
      expect(out.existsSync(), isTrue);
      expect(utf8.decode(out.readAsBytesSync()), 'GOOD');
      expect(calls, 2, reason: '第一个源哈希不符应换下一个源，而不是直接失败');
    });

    test('所有源都哈希不符 → 抛异常且不留残包', () async {
      var calls = 0;
      Future<void> fakeOne(String url, File file, void Function(double?)? p) async {
        calls++;
        await file.writeAsBytes(utf8.encode('TAMPERED'));
      }

      final f = File('${tmp.path}/allbad.apk');
      await expectLater(
        UpdateService.fetchVerified(f, const ['https://a/x.apk', 'https://b/x.apk'],
            checksum: sha256.convert(utf8.encode('GOOD')).toString(), one: fakeOne),
        throwsA(isA<ChecksumException>()),
      );
      expect(calls, 2, reason: '两个源都要试过');
      expect(f.existsSync(), isFalse);
    });

    test('清单没给哈希（旧清单）→ 不阻断，但文件保留', () async {
      final f = File('${tmp.path}/c.apk');
      final out = await UpdateService.fetchVerified(f, const ['https://x/c.apk'], one: fakeDownload);
      expect(out.existsSync(), isTrue);
    });
  });

  group('安装前签名比对', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('upd2'));
    tearDown(() { try { tmp.deleteSync(recursive: true); } catch (_) {} });

    test('签名不一致 → signatureMismatch（不调起安装器）', () async {
      final f = File('${tmp.path}/s.apk')..writeAsBytesSync([1, 2, 3]);
      UpdateService.debugSignatureProbe = (_) async => SigCheck.mismatch;
      addTearDown(() => UpdateService.debugSignatureProbe = null);
      expect(await UpdateService.install(f), InstallOutcome.signatureMismatch);
    });

    test('签名一致但沙箱里没有安装器 → failed（而不是 signatureMismatch）', () async {
      final f = File('${tmp.path}/t.apk')..writeAsBytesSync([1, 2, 3]);
      UpdateService.debugSignatureProbe = (_) async => SigCheck.ok;
      addTearDown(() => UpdateService.debugSignatureProbe = null);
      expect(await UpdateService.install(f), InstallOutcome.failed);
    });

    test('签名读不出来（个别 ROM）→ verifyUnavailable（引导走发布页，而不是说「签名不符」）', () async {
      final f = File('${tmp.path}/v.apk')..writeAsBytesSync([1, 2, 3]);
      UpdateService.debugSignatureProbe = (_) async => SigCheck.unreadable;
      addTearDown(() => UpdateService.debugSignatureProbe = null);
      expect(await UpdateService.install(f), InstallOutcome.verifyUnavailable);
    });

    test('探测抛异常 → 视为读不出来（保守拒绝，不放行）', () async {
      final f = File('${tmp.path}/u.apk')..writeAsBytesSync([1, 2, 3]);
      UpdateService.debugSignatureProbe = (_) async => throw StateError('boom');
      addTearDown(() => UpdateService.debugSignatureProbe = null);
      expect(await UpdateService.install(f), InstallOutcome.verifyUnavailable);
    });
  });

  group('杂项', () {
    test('落盘文件名消毒（防路径穿越）', () {
      final info = UpdateInfo(version: '../../etc/pa ss', build: 7, desc: '', downloadUrls: const {}, pageUrl: 'x');
      final name = UpdateService.apkFileName(info);
      // 危险的是**路径分隔符**（去掉后即使残留 ".." 也无法穿越到上级目录）
      expect(name.contains('/'), isFalse);
      expect(name.contains('\\'), isFalse);
      expect(name.contains(' '), isFalse);
      expect(File('/tmp/$name').parent.path, '/tmp');
    });

    test('按 ABI 选包：直链在前、镜像链依次在后', () {
      final info = UpdateInfo(
        version: '2.0.0',
        build: 99,
        desc: '',
        downloadUrls: const {'arm64-v8a': 'https://direct/arm64.apk', 'x86_64': 'https://direct/x86.apk'},
        mirrorChains: const {'arm64-v8a': ['https://m1/arm64.apk', 'https://m2/arm64.apk']},
        pageUrl: 'https://page',
      );
      final urls = UpdateService.pickUrls(info, abi: 'arm64-v8a');
      expect(urls.first, 'https://direct/arm64.apk');
      expect(urls.contains('https://m1/arm64.apk'), isTrue);
      expect(urls.contains('https://direct/x86.apk'), isFalse);
    });
  });

  test('发布清单必须给全 sha256（否则哈希校验形同虚设）', () {
    final info = UpdateInfo.parse(File('assets/app_version.json').readAsStringSync())!;
    for (final abi in info.downloadUrls.keys) {
      expect(info.checksums[abi], isNotNull,
          reason: '$abi 缺 sha256 —— 复核给的发布条件：每版清单必须带全 ABI 的哈希');
      expect(info.checksums[abi]!.length, 64);
    }
  });
}
