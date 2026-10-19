/*
 * 检查更新 —— 唯一联网功能（Howe 2026-10-19 定）。
 * 优先读本仓库的版本清单（raw.githubusercontent → jsdelivr 备用），比对构建号；
 * 有新版本则应用内下载 APK 并调起系统安装器；失败回落打开发布页。
 *
 * 隐私：除本文件外，康途不发起任何网络请求；其余数据全程留在本机。
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
    required this.pageUrl,
  });

  final String version;
  final int build;
  final String desc;
  final Map<String, String> downloadUrls;
  final String pageUrl;

  static UpdateInfo? parse(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return null;
      final urls = <String, String>{};
      final m = j['download_urls'];
      if (m is Map) {
        m.forEach((k, v) {
          if (v is String && v.isNotEmpty) urls['$k'] = v;
        });
      }
      return UpdateInfo(
        version: '${j['version'] ?? ''}',
        build: (j['version_code'] is int)
            ? j['version_code'] as int
            : int.tryParse('${j['version_code'] ?? ''}') ?? 0,
        desc: '${j['desc'] ?? ''}',
        downloadUrls: urls,
        pageUrl: '${j['page_url'] ?? UpdateService.releasesPage}',
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

class UpdateService {
  /// 发布页（兜底）
  static const releasesPage = 'https://github.com/Howezzzzz/kangtu-rehab/releases/latest';

  /// 版本清单地址（主 → 备用）
  static const sources = <String>[
    'https://raw.githubusercontent.com/Howezzzzz/kangtu-rehab/main/assets/app_version.json',
    'https://cdn.jsdelivr.net/gh/Howezzzzz/kangtu-rehab@main/assets/app_version.json',
  ];

  static const _timeout = Duration(seconds: 8);

  /// 下载正文的空闲超时：服务端中途停发不会永久挂起（ISS-137）
  static const _idleTimeout = Duration(seconds: 20);

  /// 测试注入钩子（生产为 null）
  static Future<String> Function(String url)? debugFetch;
  static (String, int)? debugCurrent;

  /// 当前已安装版本（读系统真实值，避免与包体漂移）
  static Future<(String, int)> currentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return (info.version, int.tryParse(info.buildNumber) ?? 0);
    } catch (_) {
      return ('', 0);
    }
  }

  /// 检查更新。[fetch] 可注入（测试用）；默认走 Http。
  static Future<UpdateCheckResult> check({
    Future<String> Function(String url)? fetch,
    (String, int)? current,
  }) async {
    final cur = current ?? debugCurrent ?? await currentVersion();
    final doFetch = fetch ?? debugFetch ?? _httpGet;
    for (final url in sources) {
      try {
        final raw = await doFetch(url);
        final info = UpdateInfo.parse(raw);
        if (info == null || info.build <= 0) continue;
        return UpdateCheckResult(
          ok: true,
          info: info,
          currentVersion: cur.$1,
          currentBuild: cur.$2,
        );
      } catch (_) {
        continue; // 换下一个源
      }
    }
    return UpdateCheckResult(ok: false, currentVersion: cur.$1, currentBuild: cur.$2);
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

  /// 按 ABI 选下载地址（缺失则回落 page_url / 首个直链）
  static String pickUrl(UpdateInfo info) {
    const order = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];
    for (final k in order) {
      final u = info.downloadUrls[k];
      if (u != null && u.isNotEmpty) return u;
    }
    return info.downloadUrls['arm64-v8a'] ??
        (info.downloadUrls.isEmpty ? info.pageUrl : info.downloadUrls.values.first);
  }

  /// 下载 APK 到应用外部目录，返回文件。[onProgress] 0..1（未知总长时为 null）。
  static Future<File> download(
    UpdateInfo info, {
    void Function(double? progress)? onProgress,
  }) async {
    final url = pickUrl(info);
    final name = 'kangtu-${info.version}-${info.build}.apk';
    final dir = await getExternalStorageDirectory() ??
        await getApplicationSupportDirectory();
    final target = Directory('${dir.path}/update')..createSync(recursive: true);
    final file = File('${target.path}/$name');

    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final req = await client.getUrl(Uri.parse(url)).timeout(_timeout);
      final res = await req.close().timeout(_timeout);
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      await writeStreamToFile(
        file,
        res.timeout(_idleTimeout),
        total: res.contentLength,
        onProgress: onProgress,
      );
      return file;
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

  /// 调起系统安装器
  static Future<bool> install(File apk) async {
    try {
      final r = await OpenFilex.open(apk.path, type: 'application/vnd.android.package-archive');
      return r.type == ResultType.done;
    } catch (_) {
      return false;
    }
  }
}
