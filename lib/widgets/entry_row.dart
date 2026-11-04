// 康途定制：康复模块的入口行（首页「康复 / 日志」＋「我的」页「档案 / 手册 / 自评」共用）
//
// 融合 2.5：此前这 5 个入口在两个页面里各自手搓 Pressable + SoftCard + Row，
// 字号、图标底座、尾标、间距写了五份，规格随时可能漂移（首页 15/w800、
// 「我的」页无图标就是漂移的结果）。抽成一个组件后，规格只有一处定义，
// 卡片基元仍用上游 ui_kit 的 SoftCard(radius: 22) / Pressable，与上游卡片同规格。
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'ui_kit.dart';

class EntryRow extends StatelessWidget {
  const EntryRow({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return Pressable(
      onTap: onTap,
      child: SoftCard(
        radius: 22,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: gc.emberSoft, shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: gc.ember),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.f(15, weight: FontWeight.w800, color: gc.text)),
                  const SizedBox(height: 2),
                  Text(detail,
                      style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(t.rehabEnter, style: AppTheme.f(12, weight: FontWeight.w700, color: gc.ember)),
          ],
        ),
      ),
    );
  }
}

/// 康复档案入口的副标题：有档案就报第一个档案名 + 计划数，没有就用引导文案。
String rehabEntryDetail(String fallbackBlurb, String? episodeTitle, int planCount) =>
    episodeTitle == null ? fallbackBlurb : '$episodeTitle · ${t.rehabPlanCount(planCount)}';

/// 图标统一在这里定，两个页面不会各挑各的。
abstract final class EntryIcons {
  static const IconData rehab = PhosphorIconsRegular.heartbeat;
  static const IconData log = PhosphorIconsRegular.bookOpenText;
  static const IconData episodes = PhosphorIconsRegular.folder;
  static const IconData book = PhosphorIconsRegular.bookOpenText;
  static const IconData baseline = PhosphorIconsRegular.clipboardText;
}
