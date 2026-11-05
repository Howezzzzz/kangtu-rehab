/*
 * 应用内「检查更新」的界面流程（About 页与设置页共用同一个入口逻辑）。
 *
 * 安全：下载完按清单声明的 SHA-256 校验；安装前比对签名证书（见 services/update_service.dart）。
 * 隐私：只有用户主动走这个流程才会联网。
 */
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../services/update_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'liquid_notch.dart';

/// 上次检查发现的新版本构建号（null = 未发现 / 已是最新）→ 入口上显示一个小圆点。
/// 只在用户**主动检查过**之后才有值，不做任何后台轮询。
final ValueNotifier<int?> updateFoundBuild = ValueNotifier<int?>(null);

String _mb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';

Future<void> _open(BuildContext context, String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

void _toast(BuildContext context, String msg) =>
    showNotchToast(context, msg, icon: PhosphorIconsFill.checkCircle, accent: context.gc.sage);

/// 检查更新（唯一联网入口）。失败可重试，不再只能去打开发布页。
Future<void> checkForUpdates(BuildContext context) async {
  final gc = context.gc;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: gc.bgRaised,
        content: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 14),
          Flexible(child: Text(t.updateChecking, style: AppTheme.f(14, weight: FontWeight.w500, color: gc.text))),
        ]),
      ),
    ),
  );
  // await 之前先把 navigator 拿到手：避免「await 回来后 context 已卸载」的早退分支
  final nav = Navigator.of(context, rootNavigator: true);
  UpdateCheckResult res;
  try {
    res = await UpdateService.check();
  } catch (_) {
    res = const UpdateCheckResult(ok: false);
  }
  nav.pop();
  if (!context.mounted) return;

  if (!res.ok) {
    final retry = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: gc.bgRaised,
        title: Text(t.updateTitle, style: AppTheme.f(16, weight: FontWeight.w700, color: gc.text)),
        content: Text(t.updateFailed, style: AppTheme.f(13.5, height: 1.45, color: gc.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(t.updateOpenPage, style: AppTheme.f(13.5, weight: FontWeight.w600, color: gc.textTertiary))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(t.updateRetry, style: AppTheme.f(13.5, weight: FontWeight.w700, color: gc.ember))),
        ],
      ),
    );
    if (!context.mounted) return;
    if (retry == true) {
      await checkForUpdates(context);
    } else {
      await _open(context, UpdateService.releasesPage);
    }
    return;
  }

  if (!res.hasUpdate) {
    updateFoundBuild.value = null;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: gc.bgRaised,
        title: Text(t.updateTitle, style: AppTheme.f(16, weight: FontWeight.w700, color: gc.text)),
        content: Text(t.updateLatest(res.currentVersion),
            style: AppTheme.f(13.5, height: 1.45, color: gc.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(t.updateLater, style: AppTheme.f(13.5, weight: FontWeight.w700, color: gc.ember))),
        ],
      ),
    );
    return;
  }

  final info = res.info!;
  updateFoundBuild.value = info.build;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: gc.bgRaised,
      title: Text(t.updateAvailable(info.version), style: AppTheme.f(16, weight: FontWeight.w700, color: gc.text)),
      content: Text('${info.desc.isEmpty ? '' : '${info.desc}\n\n'}${t.updateNetNote}',
          style: AppTheme.f(13.5, height: 1.45, color: gc.textSecondary)),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.updateLater, style: AppTheme.f(13.5, weight: FontWeight.w600, color: gc.textTertiary))),
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.updateNow, style: AppTheme.f(13.5, weight: FontWeight.w700, color: gc.ember))),
      ],
    ),
  );
  if (go == true && context.mounted) await _downloadAndInstall(context, info);
}

Future<void> _downloadAndInstall(BuildContext context, UpdateInfo info) async {
  final gc = context.gc;
  final progress = ValueNotifier<double?>(null);
  final total = ValueNotifier<int>(0);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: gc.bgRaised,
        content: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (_, v, _) => ValueListenableBuilder<int>(
            valueListenable: total,
            builder: (_, bytes, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bytes > 0 && v != null
                      ? '${t.updateDownloading} ${_mb((bytes * v).round())} / ${_mb(bytes)}'
                      : t.updateDownloading,
                  style: AppTheme.f(14, weight: FontWeight.w500, color: gc.text),
                ),
                const SizedBox(height: 14),
                LinearProgressIndicator(value: v, minHeight: 4, color: gc.ember, backgroundColor: gc.bgRaised2),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  File? apk;
  var checksumFailed = false;
  var failed = false;
  try {
    apk = await UpdateService.download(info,
        onProgress: (p) => progress.value = p, onTotal: (n) => total.value = n);
  } on ChecksumException {
    checksumFailed = true;
  } catch (_) {
    failed = true;
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    progress.dispose();
    total.dispose();
  }
  if (!context.mounted) return;
  if (checksumFailed) {
    _toast(context, t.updateChecksumFailed);
    return;
  }
  if (failed || apk == null) {
    _toast(context, t.updateDownloadFailed);
    return;
  }
  final outcome = await UpdateService.install(apk);
  if (!context.mounted) return;
  switch (outcome) {
    case InstallOutcome.ok:
      _toast(context, t.updateInstallHint);
    case InstallOutcome.signatureMismatch:
      _toast(context, t.updateVerifyFailed);
    case InstallOutcome.verifyUnavailable:
      _toast(context, t.updateVerifyUnavailable);
    case InstallOutcome.failed:
      _toast(context, t.updateFailed);
  }
}
