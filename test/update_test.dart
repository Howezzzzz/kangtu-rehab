// ISS-136 回归：检查更新模块（唯一联网功能）——清单解析 / 版本比对 / 多源兜底 / 权限与清单存在性。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/services/update_service.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    setAppLanguage('zh');
  });
  String manifest({required int build, String version = '1.6.0-kangtu'}) =>
      jsonEncode({
        'version': version,
        'version_code': build,
        'desc': 'new stuff',
        'page_url': 'https://example.com/releases',
        'download_urls': {
          'arm64-v8a': 'https://example.com/a.apk',
          'armeabi-v7a': 'https://example.com/b.apk',
        },
      });

  group('UpdateInfo.parse', () {
    test('正常 JSON 解析（含分 ABI 直链）', () {
      final info = UpdateInfo.parse(manifest(build: 22))!;
      expect(info.version, '1.6.0-kangtu');
      expect(info.build, 22);
      expect(info.desc, 'new stuff');
      expect(info.downloadUrls['arm64-v8a'], 'https://example.com/a.apk');
    });

    test('坏 JSON → null', () {
      expect(UpdateInfo.parse('not json'), isNull);
      expect(UpdateInfo.parse('[]'), isNull);
    });

    test('缺字段兜底（version_code 字符串 / 无 download_urls）', () {
      final info = UpdateInfo.parse('{"version":"1.0.0","version_code":"7"}')!;
      expect(info.build, 7);
      expect(info.downloadUrls, isEmpty);
      expect(info.pageUrl, UpdateService.releasesPage);
    });
  });

  group('UpdateService.check', () {
    test('远端构建号更大 → 有更新', () async {
      final res = await UpdateService.check(
        current: ('1.6.0-kangtu', 21),
        fetch: (_) async => manifest(build: 22),
      );
      expect(res.ok, isTrue);
      expect(res.hasUpdate, isTrue);
      expect(res.info!.build, 22);
    });

    test('远端构建号相同 → 已是最新', () async {
      final res = await UpdateService.check(
        current: ('1.6.0-kangtu', 21),
        fetch: (_) async => manifest(build: 21),
      );
      expect(res.ok, isTrue);
      expect(res.hasUpdate, isFalse);
    });

    test('远端构建号更小（异常）→ 不提示更新', () async {
      final res = await UpdateService.check(
        current: ('1.6.0-kangtu', 21),
        fetch: (_) async => manifest(build: 20),
      );
      expect(res.hasUpdate, isFalse);
    });

    test('先完成的源返回脏数据 → 不判失败，继续等另一个源', () async {
      final res = await UpdateService.check(
        current: ('1.6.0-kangtu', 21),
        fetch: (url) {
          if (url.contains('raw.githubusercontent')) {
            return Future.value('not json'); // 秒回脏数据（非 JSON）
          }
          return Future.delayed(const Duration(milliseconds: 50), () => manifest(build: 22));
        },
      );
      expect(res.ok, isTrue, reason: '脏数据不应抢占结果');
      expect(res.hasUpdate, isTrue);
    });

    test('两源都成功但一源陈旧 → 取构建号更高者（ISS-145）', () async {
      final res = await UpdateService.check(
        current: ('1.6.0-kangtu', 21),
        fetch: (url) => url.contains('raw')
            ? Future.delayed(const Duration(milliseconds: 30), () => manifest(build: 23))
            : Future.value(manifest(build: 22)), // 陈旧缓存，秒回
      );
      expect(res.info!.build, 23, reason: '不应被陈旧 CDN 抢答');
    });

    test('慢源超过宽限期 → 不阻塞（用先回者）', () async {
      final slow = Completer<String>();
      final sw = Stopwatch()..start();
      final res = await UpdateService.check(
        current: ('1.6.0-kangtu', 21),
        fetch: (url) => url.contains('gh-proxy') ? slow.future : Future.value(manifest(build: 22)),
      );
      sw.stop();
      expect(res.info!.build, 22);
      expect(sw.elapsedMilliseconds, lessThan(2500), reason: '不应等慢源');
      slow.complete(manifest(build: 23)); // 收尾
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });

    test('所有源永不返回 → hardTimeout 兜底收口（ok=false）', () async {
      final old = UpdateService.hardTimeout;
      UpdateService.hardTimeout = const Duration(milliseconds: 200);
      addTearDown(() => UpdateService.hardTimeout = old);
      final hang = Completer<String>();
      final res = await UpdateService.check(
        current: ('1.6.0-kangtu', 21),
        fetch: (_) => hang.future,
      );
      expect(res.ok, isFalse);
      hang.complete('x'); // 收尾
    });

    test('两源并行：慢源（模拟被墙）不阻塞，快源先胜', () async {
      final ctrl = Completer<String>();
      var calls = 0;
      final res = await UpdateService.check(
        current: ('1.6.0-kangtu', 21),
        fetch: (url) {
          calls++;
          if (url.startsWith('https://raw.githubusercontent.com')) return ctrl.future; // 直连被墙，永不返回
          return Future.value(manifest(build: 22)); // 其余源秒回
        },
      );
      expect(calls, UpdateService.sources.length, reason: '所有源应被并行发起');
      expect(res.ok, isTrue);
      expect(res.hasUpdate, isTrue);
      ctrl.complete('x'); // 收尾，避免悬挂
    });

    test('主源失败 → 自动切备用源', () async {
      var calls = 0;
      final res = await UpdateService.check(
        current: ('1.6.0-kangtu', 21),
        fetch: (url) async {
          calls++;
          if (calls == 1) throw const SocketException('blocked');
          return manifest(build: 22);
        },
      );
      expect(res.ok, isTrue);
      expect(res.hasUpdate, isTrue);
      expect(calls, UpdateService.sources.length);
    });

    test('所有源都失败 → ok=false（不误报"已是最新"）', () async {
      final res = await UpdateService.check(
        current: ('1.6.0-kangtu', 21),
        fetch: (_) async => throw const SocketException('down'),
      );
      expect(res.ok, isFalse);
      expect(res.hasUpdate, isFalse);
    });

    test('本地构建号读不到（0）→ 不误报更新', () async {
      final res = await UpdateService.check(
        current: ('', 0),
        fetch: (_) async => manifest(build: 22),
      );
      expect(res.ok, isTrue);
      expect(res.hasUpdate, isFalse);
    });

    test('脏数据（version_code<=0）→ 继续尝试/失败，不当成更新', () async {
      final res = await UpdateService.check(
        current: ('1.6.0-kangtu', 21),
        fetch: (_) async => '{"version":"x","version_code":0}',
      );
      expect(res.hasUpdate, isFalse);
    });
  });

  group('pickUrl', () {
    test('优先 arm64-v8a', () {
      final info = UpdateInfo.parse(manifest(build: 22))!;
      expect(UpdateService.pickUrl(info), 'https://example.com/a.apk');
    });

    test('无直链 → 回落发布页', () {
      final info = UpdateInfo.parse('{"version":"1.0.0","version_code":9}')!;
      expect(UpdateService.pickUrl(info), UpdateService.releasesPage);
    });
  });

  group('权限与版本清单（静态哨兵，防误删）', () {
    test('AndroidManifest 声明 INTERNET + REQUEST_INSTALL_PACKAGES', () {
      final f = File('android/app/src/main/AndroidManifest.xml');
      expect(f.existsSync(), isTrue, reason: '找不到 AndroidManifest.xml');
      final s = f.readAsStringSync();
      expect(s.contains('android.permission.INTERNET'), isTrue);
      expect(s.contains('android.permission.REQUEST_INSTALL_PACKAGES'), isTrue);
      // 仍然不声明 ACCESS_NETWORK_STATE（保持最小化）
      expect(s.contains('android.permission.ACCESS_NETWORK_STATE" tools:node="remove"'), isTrue);
    });

    test('assets/app_version.json 存在且结构正确', () {
      final f = File('assets/app_version.json');
      expect(f.existsSync(), isTrue, reason: '找不到 app_version.json');
      final info = UpdateInfo.parse(f.readAsStringSync());
      expect(info, isNotNull);
      expect(info!.build, greaterThan(0));
      expect(info.version.isNotEmpty, isTrue);
      expect(info.downloadUrls.isNotEmpty, isTrue);
      // 镜像字段哨兵（ISS-143）：清单必须带镜像兜底，否则国内下载基本不可用
      expect(info.mirrorUrls.isNotEmpty, isTrue, reason: '清单缺 mirror_urls');
      // 多镜像链哨兵（RISK-031/035）：单镜像易挂，每个 ABI 至少两条备选
      expect(info.mirrorChains.isNotEmpty, isTrue, reason: '清单缺 mirrors 多镜像链');
      for (final e in info.mirrorChains.entries) {
        expect(e.value.length, greaterThanOrEqualTo(2),
            reason: 'ABI ${e.key} 镜像链不足两条');
      }
    });
  });

  group('下载写盘（ISS-139 回归）', () {
    test('成功：写全 + 进度回调到 1.0', () async {
      final dir = Directory.systemTemp.createTempSync('kt_upd_ok');
      final f = File('${dir.path}/a.apk');
      final seen = <double?>[];
      await UpdateService.writeStreamToFile(
        f,
        Stream.fromIterable([List.filled(30, 1), List.filled(70, 1)]),
        total: 100,
        onProgress: seen.add,
      );
      expect(f.lengthSync(), 100);
      expect(seen.last, 1.0);
      dir.deleteSync(recursive: true);
    });

    test('中途断流：关流并清理半成品，不残留残缺 APK', () async {
      final dir = Directory.systemTemp.createTempSync('kt_upd_bad');
      final f = File('${dir.path}/b.apk');
      Stream<List<int>> bad() async* {
        yield List.filled(10, 1);
        throw const SocketException('mid-stream');
      }

      await expectLater(
        UpdateService.writeStreamToFile(f, bad(), total: 100),
        throwsA(isA<SocketException>()),
      );
      expect(f.existsSync(), isFalse);
      dir.deleteSync(recursive: true);
    });
  });

  group('pickUrls（直链优先、镜像兜底）', () {
    UpdateInfo withUrls({
      Map<String, String>? direct,
      Map<String, String>? mirror,
      Map<String, List<String>>? chains,
    }) {
      final j = <String, dynamic>{'version': '1.0.0', 'version_code': 9};
      if (direct != null) j['download_urls'] = direct;
      if (mirror != null) j['mirror_urls'] = mirror;
      if (chains != null) j['mirrors'] = chains;
      return UpdateInfo.parse(jsonEncode(j))!;
    }

    test('直链在前、镜像在后', () {
      final info = withUrls(
        direct: {'arm64-v8a': 'https://d/a.apk'},
        mirror: {'arm64-v8a': 'https://m/a.apk'},
      );
      expect(UpdateService.pickUrls(info), ['https://d/a.apk', 'https://m/a.apk']);
    });

    test('只有镜像时直接用镜像', () {
      final info = withUrls(mirror: {'arm64-v8a': 'https://m/a.apk'});
      expect(UpdateService.pickUrls(info), ['https://m/a.apk']);
    });

    test('镜像与直链相同 → 不重复', () {
      final info = withUrls(
        direct: {'arm64-v8a': 'https://x/a.apk'},
        mirror: {'arm64-v8a': 'https://x/a.apk'},
      );
      expect(UpdateService.pickUrls(info), ['https://x/a.apk']);
    });

    test('都没有 → 返回空（不把发布页当 APK）', () {
      final info = withUrls();
      expect(UpdateService.pickUrls(info), isEmpty);
    });

    test('镜像与直链按同一 ABI 键配对（不做各自首选，ISS-146）', () {
      final info = withUrls(
        direct: {'arm64-v8a': 'https://d/arm64.apk'},
        mirror: {'x86_64': 'https://m/x86.apk'},
      );
      expect(UpdateService.pickUrls(info), ['https://d/arm64.apk']);
    });

    test('多镜像链：直链在前、镜像按清单顺序逐个兜底（RISK-031/035）', () {
      final info = withUrls(
        direct: {'arm64-v8a': 'https://d/a.apk'},
        chains: {
          'arm64-v8a': ['https://m1/a.apk', 'https://m2/a.apk', 'https://m3/a.apk'],
        },
      );
      expect(UpdateService.pickUrls(info),
          ['https://d/a.apk', 'https://m1/a.apk', 'https://m2/a.apk', 'https://m3/a.apk']);
    });

    test('有 mirrors 时优先于单镜像 mirror_urls，且与直链去重', () {
      final info = withUrls(
        direct: {'arm64-v8a': 'https://d/a.apk'},
        mirror: {'arm64-v8a': 'https://m1/a.apk'},
        chains: {
          'arm64-v8a': ['https://m1/a.apk', 'https://m2/a.apk'],
        },
      );
      expect(UpdateService.pickUrls(info), ['https://d/a.apk', 'https://m1/a.apk', 'https://m2/a.apk']);
    });

    test('chains 里的空串/非字符串项被消毒', () {
      final info = UpdateInfo.parse(jsonEncode({
        'version': '1.0.0',
        'version_code': 9,
        'mirrors': {
          'arm64-v8a': ['', 'https://m1/a.apk', 42, 'https://m2/a.apk'],
        },
      }))!;
      expect(UpdateService.pickUrls(info), ['https://m1/a.apk', 'https://m2/a.apk']);
    });

    test('chains 值为字符串（容错）→ 视作单元素链', () {
      final info = UpdateInfo.parse(jsonEncode({
        'version': '1.0.0',
        'version_code': 9,
        'mirrors': {'arm64-v8a': 'https://m1/a.apk'},
      }))!;
      expect(UpdateService.pickUrls(info), ['https://m1/a.apk']);
    });

    test('只有多镜像链（无直链/单镜像）→ 用整条链', () {
      final info = withUrls(chains: {
        'x86_64': ['https://m1/x.apk', 'https://m2/x.apk'],
      });
      expect(UpdateService.pickUrls(info), ['https://m1/x.apk', 'https://m2/x.apk']);
    });
  });

  group('apkFileName（消毒，ISS-149）', () {
    test('版本名里的斜杠/怪异字符被替换', () {
      final info = UpdateInfo.parse('{"version":"1.0/../evil","version_code":9}')!;
      expect(UpdateService.apkFileName(info), 'kangtu-1.0_.._evil-9.apk');
    });
  });

  group('下载候选兜底（ISS-143 回归）', () {
    test('直链失败 → 自动换镜像成功', () async {
      final dir = Directory.systemTemp.createTempSync('kt_upd_mir');
      final f = File('${dir.path}/a.apk');
      final tried = <String>[];
      await UpdateService.downloadTo(
        f,
        ['https://d/a.apk', 'https://m/a.apk'],
        one: (url, file, _) async {
          tried.add(url);
          if (url.startsWith('https://d')) throw const SocketException('blocked');
          await file.writeAsBytes(List.filled(5, 1));
        },
      );
      expect(tried, ['https://d/a.apk', 'https://m/a.apk']);
      expect(f.existsSync(), isTrue);
      dir.deleteSync(recursive: true);
    });

    test('全部候选失败 → 抛最后异常', () async {
      final dir = Directory.systemTemp.createTempSync('kt_upd_all_bad');
      final f = File('${dir.path}/b.apk');
      await expectLater(
        UpdateService.downloadTo(
          f,
          ['https://d/a.apk', 'https://m/a.apk'],
          one: (url, file, _) async {
            file.writeAsBytesSync(List.filled(3, 1));
            throw const SocketException('down');
          },
        ),
        throwsA(isA<SocketException>()),
      );
      dir.deleteSync(recursive: true);
    });

    test('无候选（ISS-147）→ 抛异常且不落盘', () async {
      final dir = Directory.systemTemp.createTempSync('kt_upd_none');
      final f = File('${dir.path}/c.apk');
      await expectLater(
        UpdateService.downloadTo(f, const [], one: (u, file, _) async {}),
        throwsA(isA<HttpException>()),
      );
      expect(f.existsSync(), isFalse);
      dir.deleteSync(recursive: true);
    });
  });

  group('清单源配置（国内可达性哨兵）', () {
    test('sources 全部 https，且含国内友好源与 CDN 备用源', () {
      final s = UpdateService.sources;
      expect(s.length, greaterThanOrEqualTo(3));
      expect(s.every((u) => u.startsWith('https://')), isTrue);
      expect(s.any((u) => u.contains('gh-proxy.com')), isTrue, reason: '缺国内可用代理源');
      expect(s.any((u) => u.contains('jsdelivr.net')), isTrue, reason: '缺 CDN 备用源');
      expect(s.any((u) => u.contains('raw.githubusercontent.com')), isTrue);
      // 均指向同一份清单
      expect(s.every((u) => u.endsWith('assets/app_version.json')), isTrue);
    });
  });

  group('设置页入口', () {
    testWidgets('设置页显示「检查更新」行（不触发网络）', (tester) async {
      fit.onboarded = true;
      fit.route = 'preferences';
      await tester.pumpWidget(const GymManeApp());
      await tester.pumpAndSettle();
      expect(find.text(t.updateTitle), findsOneWidget);
    });

    Future<void> openSettings(WidgetTester tester) async {
      fit.onboarded = true;
      fit.route = 'preferences';
      await tester.pumpWidget(const GymManeApp());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(t.updateTitle), 400,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text(t.updateTitle));
      await tester.pumpAndSettle();
    }

    testWidgets('有新版本 → 弹「发现新版本」+ 下载并安装', (tester) async {
      UpdateService.debugCurrent = ('1.6.0-kangtu', 21);
      UpdateService.debugFetch = (_) async => manifest(build: 9999);
      addTearDown(() {
        UpdateService.debugCurrent = null;
        UpdateService.debugFetch = null;
      });
      await openSettings(tester);
      expect(find.text(t.updateAvailable('1.6.0-kangtu')), findsOneWidget);
      expect(find.text(t.updateNow), findsOneWidget);
      expect(find.text(t.updateLater), findsOneWidget);
    });

    testWidgets('构建号相同 → 弹「已是最新版本」', (tester) async {
      UpdateService.debugCurrent = ('1.6.0-kangtu', 21);
      UpdateService.debugFetch = (_) async => manifest(build: 21);
      addTearDown(() {
        UpdateService.debugCurrent = null;
        UpdateService.debugFetch = null;
      });
      await openSettings(tester);
      expect(find.text(t.updateLatest('1.6.0-kangtu')), findsOneWidget);
      expect(find.text(t.updateNow), findsNothing);
    });

    testWidgets('全部源失败 → 弹失败提示 + 可打开发布页', (tester) async {
      UpdateService.debugCurrent = ('1.6.0-kangtu', 21);
      UpdateService.debugFetch = (_) async => throw const SocketException('blocked');
      addTearDown(() {
        UpdateService.debugCurrent = null;
        UpdateService.debugFetch = null;
      });
      await openSettings(tester);
      expect(find.text(t.updateFailed), findsOneWidget);
      expect(find.text(t.updateOpenPage), findsOneWidget);
    });
    testWidgets('检查中弹窗：系统返回键关不掉（防误弹设置页）', (tester) async {
      UpdateService.debugCurrent = ('1.6.0-kangtu', 21);
      final c = Completer<String>();
      UpdateService.debugFetch = (_) => c.future;
      addTearDown(() {
        UpdateService.debugCurrent = null;
        UpdateService.debugFetch = null;
      });
      fit.onboarded = true;
      fit.route = 'preferences';
      await tester.pumpWidget(const GymManeApp());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(t.updateTitle), 400,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text(t.updateTitle));
      await tester.pump(); // 弹窗出现（转圈动画常驻，不能 pumpAndSettle）
      expect(find.text(t.updateChecking), findsOneWidget);

      await tester.binding.handlePopRoute(); // 模拟系统返回键
      await tester.pump();
      expect(find.text(t.updateChecking), findsOneWidget); // 弹窗仍在
      expect(find.text(t.updateTitle), findsOneWidget); // 设置页仍在（未被误弹）

      c.complete(manifest(build: 21));
      await tester.pumpAndSettle();
      expect(find.text(t.updateLatest('1.6.0-kangtu')), findsOneWidget);
    });
  });
}
