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
      expect(calls, 2);
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
