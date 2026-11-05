/*
 * 检查更新 —— 本应用唯一的联网功能。
 * 发布仓库：见下方 _manifestUrls（当前指向 Howezzzzz/kangtu-rehab，换仓库时同步改这里）。
 * 版本清单**两源并行拉取、谁先成功用谁**（raw.githubusercontent / jsdelivr）；
 * 有新版本则应用内下载 APK（直链优先、失败自动换镜像）并调起系统安装器。
 *
 * 隐私：除本文件外，本应用不发起任何网络请求；其余数据全程留在本机。
 * 镜像仅代取公开的 APK 文件，不携带任何用户数据。
 */
import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// 远端版本清单
class UpdateInfo {
  UpdateInfo({
    required this.version,
    required this.build,
    required this.desc,
    required this.downloadUrls,
    this.mirrorUrls = const {},
    this.mirrorChains = const {},
    this.checksums = const {},
    required this.pageUrl,
  });

  final String version;
  final int build;
  final String desc;
  final Map<String, String> downloadUrls;

  /// 镜像地址（同键；直链失败时使用）。旧版清单无此字段时为空。
  final Map<String, String> mirrorUrls;

  /// 多镜像链（同键，按顺序试；RISK-031/035）。新清单的 `mirrors` 字段；
  /// 旧版清单无此字段，此时回落到 [mirrorUrls]（单镜像，向后兼容）。
  final Map<String, List<String>> mirrorChains;
  final String pageUrl;

  /// 各 ABI 的 SHA-256（十六进制，可带 `sha256:` 前缀）。
  /// **下载后据此校验**：防镜像篡改 / 传输截断（ISS-2xx）。旧清单无此字段 → 空。
  final Map<String, String> checksums;

  static UpdateInfo? parse(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return null;
      Map<String, String> urls(String key) {
        final out = <String, String>{};
        final m = j[key];
        if (m is Map) {
          m.forEach((k, v) {
            if (v is String && v.isNotEmpty) out['$k'] = v;
          });
        }
        return out;
      }

      // sha256: {"abi": "hex"} —— 下载校验用；消毒空串、去掉可能的 "sha256:" 前缀
      final sums = <String, String>{};
      final sumRaw = j['sha256'];
      if (sumRaw is Map) {
        sumRaw.forEach((k, v) {
          if (v is String && v.trim().isNotEmpty) {
            sums['$k'] = v.trim().toLowerCase().replaceFirst('sha256:', '');
          }
        });
      }

      // mirrors: {"abi": [url, url, ...]} —— 多镜像链，逐项消毒空串
      Map<String, List<String>> chains(String key) {
        final out = <String, List<String>>{};
        final m = j[key];
        if (m is Map) {
          m.forEach((k, v) {
            if (v is List) {
              final list = v.whereType<String>().where((e) => e.isNotEmpty).toList();
              if (list.isNotEmpty) out['$k'] = list;
            } else if (v is String && v.isNotEmpty) {
              out['$k'] = [v];
            }
          });
        }
        return out;
      }

      return UpdateInfo(
        version: '${j['version'] ?? ''}',
        build: (j['version_code'] is int)
            ? j['version_code'] as int
            : int.tryParse('${j['version_code'] ?? ''}') ?? 0,
        desc: '${j['desc'] ?? ''}',
        downloadUrls: urls('download_urls'),
        mirrorUrls: urls('mirror_urls'),
        mirrorChains: chains('mirrors'),
        pageUrl: '${j['page_url'] ?? UpdateService.releasesPage}',
        checksums: sums,
      );
    } catch (_) {
      return null;
    }
  }
}

/// 检查结果
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.ok,
    this.info,
    this.currentVersion = '',
    this.currentBuild = 0,
    this.error = '',
  });

  final bool ok; // 检查是否成功（false = 网络/解析失败）
  final UpdateInfo? info;
  final String currentVersion;
  final int currentBuild;
  final String error;

  bool get hasUpdate =>
      ok && info != null && currentBuild > 0 && info!.build > currentBuild;
}

/// 安装结果（区分「签名不符」与「签名读不出来」，界面才能给出正确的下一步）
enum InstallOutcome { ok, signatureMismatch, verifyUnavailable, failed }

/// 签名校验三态
enum SigCheck { ok, mismatch, unreadable }

/// 下载后校验失败（哈希不符 / 文件缺失）——调用方据此给「文件校验失败」的提示
class ChecksumException implements Exception {
  const ChecksumException(this.expected, this.actual);
  final String expected;
  final String actual;
  @override
  String toString() => 'ChecksumException($expected != $actual)';
}

class UpdateService {
  /// 发布页（兜底）。用 /releases 而不是 /releases/latest ——
  /// 我们一律发预发行版，而 /latest 会跳过预发行版指向旧版。
  static const releasesPage = 'https://github.com/Howezzzzz/kangtu-rehab/releases';

  /// Android 侧给每个 ABI 加了 versionCode 后缀（见 android/app/build.gradle.kts：
  /// `versionCodeOverride = variant.versionCode * 10 + abiVersionCode`，abi 码 1/2/3），
  /// 而版本清单的 `version_code` 是**原始构建号** → 两者相差 10 倍。
  /// 直接比较会「永远显示已是最新」（ISS-167），比较前必须用
  /// [buildNumberFromVersionCode] 把安装版 versionCode 还原成构建号。
  static const int abiVersionCodeFactor = 10;

  /// 由 Android versionCode 还原构建号（302 -> 30、312 -> 31）。
  /// versionCode 小于 [abiVersionCodeFactor]（如未加后缀的调试包）时原样返回。
  static int buildNumberFromVersionCode(int versionCode) =>
      versionCode >= abiVersionCodeFactor ? versionCode ~/ abiVersionCodeFactor : versionCode;

  /// 设备 ABI 对应的清单键（用 dart:ffi 的 [Abi]，不引入新依赖）。
  /// 返回 null = 识别不出 → 调用方回落「按清单顺序取首个」的旧行为。
  static String? deviceAbiKey() {
    try {
      switch (Abi.current()) {
        case Abi.androidArm64:
          return 'arm64-v8a';
        case Abi.androidArm:
          return 'armeabi-v7a';
        case Abi.androidX64:
          return 'x86_64';
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  /// 版本清单地址（多源并行竞速，谁先成功用谁）。
  /// 国内实测（2026-10-20）：raw.githubusercontent 不可达；gh-proxy 前缀最快（~0.3s）；
  /// jsdelivr 系列（cdn/fastly/gcore）多数网络可达但有地区被污染。
  static const sources = <String>[
    // 国内友好代理（最新、无缓存）
    'https://gh-proxy.com/https://raw.githubusercontent.com/Howezzzzz/kangtu-rehab/main/assets/app_version.json',
    // 直连（海外/未污染网络）
    'https://raw.githubusercontent.com/Howezzzzz/kangtu-rehab/main/assets/app_version.json',
    // CDN 备用（两个域名提高命中率）
    'https://fastly.jsdelivr.net/gh/Howezzzzz/kangtu-rehab@main/assets/app_version.json',
    'https://cdn.jsdelivr.net/gh/Howezzzzz/kangtu-rehab@main/assets/app_version.json',
  ];

  static const _timeout = Duration(seconds: 8);

  /// 并行竞速的宽限期：先成功者不立即定稿，给另一源一个很短窗口，
  /// 以免 CDN 陈旧缓存抢答（ISS-145）。
  static const _graceWindow = Duration(milliseconds: 1200);

  /// 整体兜底上限：任何情况下 check 都要收口（ISS-148；测试可调）
  static Duration hardTimeout = const Duration(seconds: 12);

  /// 下载正文的空闲超时：服务端中途停发不会永久挂起（ISS-137）
  static const _idleTimeout = Duration(seconds: 20);

  /// 测试注入钩子（生产为 null）
  static Future<String> Function(String url)? debugFetch;
  static (String, int)? debugCurrent;
  /// 测试注入：签名探测（默认走 MethodChannel 到原生）
  static Future<SigCheck> Function(String path)? debugSignatureProbe;

  static Future<void> Function(String url, File file, void Function(double?)? onProgress)?
      debugDownloadOne;

  /// 当前已安装版本（读系统真实值，避免与包体漂移）。
  /// PackageInfo 的 buildNumber 是 Android **versionCode**（被 ABI 后缀放大过），
  /// 这里统一还原成构建号，才能与清单的 `version_code` 同尺度比较（ISS-167）。
  static Future<(String, int)> currentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final versionCode = int.tryParse(info.buildNumber) ?? 0;
      return (info.version, buildNumberFromVersionCode(versionCode));
    } catch (_) {
      return ('', 0);
    }
  }

  /// 检查更新。[fetch] 可注入（测试用）；默认走 Http。
  /// 两个源**并行**拉取，先成功者胜（ISS-142：不再先等主源 8s 超时）。
  static Future<UpdateCheckResult> check({
    Future<String> Function(String url)? fetch,
    (String, int)? current,
  }) async {
    final cur = current ?? debugCurrent ?? await currentVersion();
    final doFetch = fetch ?? debugFetch ?? _httpGet;
    final info = await _fetchFirst(doFetch);
    if (info == null) {
      return UpdateCheckResult(ok: false, currentVersion: cur.$1, currentBuild: cur.$2);
    }
    return UpdateCheckResult(
      ok: true,
      info: info,
      currentVersion: cur.$1,
      currentBuild: cur.$2,
    );
  }

  /// 并行打两个源：解析成功且构建号合法者可胜出；
  /// 若另一源在 [_graceWindow] 内也成功，取**构建号更高**者（防旧缓存抢答 ISS-145）；
  /// 全失败返回 null；任何情况都由 [hardTimeout] 兜底收口（ISS-148）。
  static Future<UpdateInfo?> _fetchFirst(Future<String> Function(String url) doFetch) {
    if (sources.isEmpty) return Future<UpdateInfo?>.value(null);
    final c = Completer<UpdateInfo?>();
    final got = <UpdateInfo>[];
    var pending = sources.length;
    Timer? grace;
    void finish() {
      if (c.isCompleted) return;
      got.sort((a, b) => b.build.compareTo(a.build));
      c.complete(got.isEmpty ? null : got.first);
    }

    for (final url in sources) {
      unawaited(() async {
        try {
          final info = UpdateInfo.parse(await doFetch(url));
          if (info != null && info.build > 0 && !c.isCompleted) {
            got.add(info);
            grace ??= Timer(_graceWindow, finish);
          }
        } catch (_) {
          // 单源失败不影响其它源
        } finally {
          pending--;
          if (pending == 0) {
            grace?.cancel();
            finish();
          }
        }
      }());
    }
    return c.future.timeout(hardTimeout, onTimeout: () => null);
  }

  static Future<String> _httpGet(String url) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final req = await client.getUrl(Uri.parse(url)).timeout(_timeout);
      final res = await req.close().timeout(_timeout);
      if (res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}');
      }
      return await res.transform(utf8.decoder).join().timeout(_timeout);
    } finally {
      client.close(force: true);
    }
  }

  /// 候选下载地址：**直链优先，其次镜像链；两侧按同一个 ABI 键配对**
  /// （ISS-146：不可各自取首选，否则可能兜底到错架构包）。
  /// [abi] 为设备实际 ABI（ISS-168：旧实现写死 arm64 优先，32 位设备会下到装不上的包）；
  /// 传入且清单有该键时优先用它，否则回落「固定顺序取首个」。
  /// 镜像优先取多镜像链 `mirrors[abi]`，无则回落单镜像 `mirror_urls[abi]`
  /// （RISK-031/035：国内单镜像易挂，需多备）。去重保序。
  /// 无任何 APK 直链时返回空列表——不把发布页 HTML 当 APK（ISS-147）。
  static List<String> pickUrls(UpdateInfo info, {String? abi}) {
    final avail = <String>{
      ...info.downloadUrls.keys,
      ...info.mirrorChains.keys,
      ...info.mirrorUrls.keys,
    };
    String? key;
    if (abi != null && avail.contains(abi)) key = abi;
    const order = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];
    if (key == null) {
      for (final k in order) {
        if (avail.contains(k)) {
          key = k;
          break;
        }
      }
    }
    key ??= avail.isNotEmpty ? avail.first : null;
    if (key == null) return const [];

    final out = <String>[];
    void add(String? u) {
      if (u != null && u.isNotEmpty && !out.contains(u)) out.add(u);
    }

    add(info.downloadUrls[key]);
    final chain = info.mirrorChains[key];
    if (chain != null && chain.isNotEmpty) {
      for (final u in chain) {
        add(u);
      }
    } else {
      add(info.mirrorUrls[key]);
    }
    return out;
  }

  /// 单地址（兼容旧调用；无候选时返回发布页仅作展示用途）
  static String pickUrl(UpdateInfo info, {String? abi}) {
    final urls = pickUrls(info, abi: abi);
    return urls.isEmpty ? info.pageUrl : urls.first;
  }

  /// APK 落盘文件名（消毒 version 中的怪异字符，防路径穿越 ISS-149）
  static String apkFileName(UpdateInfo info) {
    final safe = info.version.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return 'kangtu-$safe-${info.build}.apk';
  }

  /// 下载 APK 到应用外部目录，返回文件。[onProgress] 0..1（未知总长时为 null）。
  /// 候选顺序为直链→镜像，逐个尝试（ISS-143）。
  static Future<File> download(
    UpdateInfo info, {
    void Function(double? progress)? onProgress,
    void Function(int total)? onTotal,
  }) async {
    final name = apkFileName(info);
    final dir = await getExternalStorageDirectory() ??
        await getApplicationSupportDirectory();
    final target = Directory('${dir.path}/update')..createSync(recursive: true);
    // 清掉上一次留下的旧包，避免更新目录无限膨胀
    try {
      for (final f in target.listSync()) {
        if (f is File && f.path.endsWith('.apk') && !f.path.endsWith('/$name')) {
          try { f.deleteSync(); } catch (_) {}
        }
      }
    } catch (_) {}
    final file = File('${target.path}/$name');
    final one = debugDownloadOne ?? _downloadOne;
    // ISS-168：按设备实际 ABI 选包，不再写死 arm64 优先
    final abi = deviceAbiKey();
    return fetchVerified(file, pickUrls(info, abi: abi),
        checksum: abi == null ? null : info.checksums[abi],
        onProgress: onProgress, onTotal: onTotal, one: one);
  }

  /// 下载到 [file] 并**按声明哈希校验**（清单没给哈希时不阻断，向后兼容旧清单）。
  /// 校验失败：删掉文件并抛 [ChecksumException] —— 不让用户装到可疑包。
  static Future<File> fetchVerified(
    File file,
    List<String> urls, {
    String? checksum,
    void Function(double? progress)? onProgress,
    void Function(int total)? onTotal,
    Future<void> Function(String url, File file, void Function(double?)? onProgress)? one,
  }) async {
    final want = (checksum ?? '').trim();
    if (want.isEmpty) {
      // 旧清单没给该 ABI 的哈希 → 不阻断（兼容），但**必须留痕**，不静默放行
      debugPrint('update: no sha256 for this ABI — integrity check skipped (legacy manifest?)');
    }
    Object? last;
    for (final url in urls) {
      try {
        final done = await downloadTo(file, [url],
            onProgress: onProgress, onTotal: onTotal, one: one);
        if (await verifyChecksum(done, want)) return done;
        // 哈希不符：删包，**换下一个镜像再试**（单源截断/污染不应终止整次更新）
        final got = await sha256Of(done);
        try { done.deleteSync(); } catch (_) {}
        last = ChecksumException(want, got);
        debugPrint('update: checksum mismatch on one source, trying next');
      } catch (e) {
        last = e;
      }
    }
    throw last ?? HttpException('no download url');
  }

  /// 依次尝试 [urls]（直链→镜像）：成功返回文件；全失败/无候选抛异常。
  static Future<File> downloadTo(
    File file,
    List<String> urls, {
    void Function(double? progress)? onProgress,
    void Function(int total)? onTotal,
    Future<void> Function(String url, File file, void Function(double?)? onProgress)? one,
  }) async {
    Object? last;
    for (final url in urls) {
      try {
        if (one == null) {
          await _downloadOne(url, file, onProgress, onTotal: onTotal);
        } else {
          await one(url, file, onProgress);
        }
        return file;
      } catch (e) {
        last = e; // 换下一个候选（半成品已由 writeStreamToFile 清理）
      }
    }
    throw last ?? HttpException('no download url');
  }

  static Future<void> _downloadOne(
    String url,
    File file,
    void Function(double?)? onProgress, {
    void Function(int total)? onTotal,
  }) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final req = await client.getUrl(Uri.parse(url)).timeout(_timeout);
      final res = await req.close().timeout(_timeout);
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      if (res.contentLength > 0) onTotal?.call(res.contentLength);
      await writeStreamToFile(
        file,
        res.timeout(_idleTimeout),
        total: res.contentLength,
        onProgress: onProgress,
      );
    } finally {
      client.close(force: true);
    }
  }

  /// 把字节流写盘（addStream 带背压，避免大包全量堆积内存 ISS-138）；
  /// 失败/中断时关流并删除半成品，不留残缺 APK（ISS-139）。
  static Future<void> writeStreamToFile(
    File file,
    Stream<List<int>> body, {
    int total = -1,
    void Function(double? progress)? onProgress,
  }) async {
    var got = 0;
    final sink = file.openWrite();
    var completed = false;
    try {
      await sink.addStream(body.map((chunk) {
        got += chunk.length;
        onProgress?.call(total > 0 ? got / total : null);
        return chunk;
      }));
      await sink.flush();
      await sink.close();
      completed = true;
    } finally {
      if (!completed) {
        try {
          await sink.close();
        } catch (_) {}
        try {
          if (file.existsSync()) file.deleteSync();
        } catch (_) {}
      }
    }
  }

  /// 计算文件 SHA-256（十六进制小写）
  static Future<String> sha256Of(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// 校验下载文件与清单声明的 SHA-256。
  /// [expected] 为空（旧清单没给该 ABI 的哈希）→ 返回 true 并**不阻断**（向后兼容），
  /// 但调用方应把这种情况记录为「未校验」。
  static Future<bool> verifyChecksum(File file, String? expected) async {
    final want = (expected ?? '').trim().toLowerCase().replaceFirst('sha256:', '');
    if (want.isEmpty) return true;
    if (!file.existsSync()) return false;
    final got = await sha256Of(file);
    return got == want;
  }

  /// 安装前校验：下载包的**签名证书**必须与已装应用一致（防镜像投毒 / 换包）。
  /// 三态返回：读不出来（个别 ROM）与真正不符要分开 —— 前者应引导用户走发布页。
  static Future<SigCheck> verifySignature(File apk) async {
    final probe = debugSignatureProbe ?? _probeSignature;
    try {
      return await probe(apk.path);
    } catch (_) {
      return SigCheck.unreadable;
    }
  }

  static Future<SigCheck> _probeSignature(String path) async {
    final r = await _updateChannel.invokeMethod<String>('verifySignature', {'path': path});
    return switch (r) {
      'ok' => SigCheck.ok,
      'mismatch' => SigCheck.mismatch,
      _ => SigCheck.unreadable,
    };
  }

  static const MethodChannel _updateChannel = MethodChannel('gymmane/update');

  /// 安装：**先比对签名**（不一致直接拒绝），再调起系统安装器。
  static Future<InstallOutcome> install(File apk) async {
    switch (await verifySignature(apk)) {
      case SigCheck.mismatch:
        return InstallOutcome.signatureMismatch;
      case SigCheck.unreadable:
        return InstallOutcome.verifyUnavailable;
      case SigCheck.ok:
        break; // 通过，继续安装
    }
    try {
      final r = await OpenFilex.open(apk.path, type: 'application/vnd.android.package-archive');
      return r.type == ResultType.done ? InstallOutcome.ok : InstallOutcome.failed;
    } catch (_) {
      return InstallOutcome.failed;
    }
  }
}
