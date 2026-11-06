import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../catalog/exercise_catalog.dart';
import '../l10n/l10n.dart';
import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/entrance.dart';
import '../widgets/ui_kit.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/update_service.dart';

import '../widgets/update_flow.dart';

/// 兜底用（PackageInfo 取不到时，例如极早期启动）；正常显示的是系统里的真实版本+构建号。
const kAppVersion = '2.0.0';
const _kAuthor = 'InlitX';
const _kAuthorUrl = 'https://github.com/InlitX';
const _kRepoUrl = 'https://github.com/Howezzzzz/kangtu-rehab';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return RiseScope(
      id: 'about',
      once: false,
      child: SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: riseAll([
            ScreenHeader(
              title: t.about,
              onBack: fit.backFromAbout,
              titleSize: 18,
              titleSpacing: 1,
            ),
            const SizedBox(height: 18),
            _hero(context, gc),
            const SizedBox(height: 20),
            _group(gc, [
              (PhosphorIconsRegular.gift, t.freeForever, t.freeForeverWhy),
              (PhosphorIconsRegular.wifiSlash, t.fullyOffline, t.fullyOfflineWhy),
              (PhosphorIconsRegular.export, t.yoursToTake, t.yoursToTakeWhy),
            ]),
            const SizedBox(height: 18),
            _sectionLabel(gc, t.whatsInside),
            const SizedBox(height: 8),
            _group(gc, [
              (PhosphorIconsRegular.barbell, t.exercisesInside(kExercises.length),
                  t.exercisesInsideWhy),
              (PhosphorIconsRegular.calculator, t.calculatorsInside, t.calculatorsInsideWhy),
              (PhosphorIconsRegular.chartLineUp, t.mathInside, t.mathInsideWhy),
            ]),
            const SizedBox(height: 22),
            Text(t.aboutBlurb,
                textAlign: TextAlign.center,
                style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textTertiary, height: 1.6)),
            const SizedBox(height: 20),
            _credits(gc),
          ]),
        ),
      ),
      ),
    );
  }

  Widget _sectionLabel(GymColors gc, String label) => Text(label.toUpperCase(),
      style: AppTheme.f(10.5, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.4));

  Widget _hero(BuildContext context, GymColors gc) {
    return Container(
      height: 178,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: gc.bgRaised,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -46,
            bottom: -56,
            child: Container(
              width: 162,
              height: 162,
              decoration: BoxDecoration(color: gc.accentSoft, shape: BoxShape.circle),
            ),
          ),
          Positioned(
            left: 128,
            top: -42,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: gc.emberSoft, shape: BoxShape.circle),
            ),
          ),
          Positioned(
            right: 6,
            top: 14,
            bottom: 14,
            child: Opacity(
              opacity: 0.6,
              child: BrandMark(fit: BoxFit.fitHeight),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(t.appName,
                    style: AppTheme.f(33, weight: FontWeight.w800, color: gc.text, letterSpacing: -0.5)),
                const SizedBox(height: 10),
                // 版本徽标 = 检查更新入口（版本号旁边最自然）；有新版时带一个小圆点。
                // 版本号**动态取**（PackageInfo）：CI 每次发版都会自增构建号，写死常量会与真实版本脱节。
                InkWell(
                  onTap: () => checkForUpdates(context),
                  borderRadius: BorderRadius.circular(100),
                  child: ValueListenableBuilder<int?>(
                    valueListenable: updateFoundBuild,
                    builder: (_, build, _) => Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                          color: gc.bgRaised2,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: FutureBuilder<PackageInfo>(
                          future: PackageInfo.fromPlatform(),
                          builder: (_, snap) {
                            // 构建号要**归一化**：ABI 拆包给 versionCode 加了 ×10+ABI 码
                            // （见 build.gradle.kts 的 versionCodeOverride），
                            // 直接显示会变成 2.0.0 (372) —— 应该显示 2.0.0 (37)。
                            final v = snap.hasData
                                ? '${snap.data!.version} '
                                    '(${UpdateService.buildNumberFromVersionCode(int.tryParse(snap.data!.buildNumber) ?? 0)})'
                                : kAppVersion;
                            return Text(t.version(v),
                                style: AppTheme.f(11.5, weight: FontWeight.w600, color: gc.textSecondary));
                          },
                        ),
                      ),
                      if (build != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: gc.ember, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(t.updateAvailableShort,
                            style: AppTheme.f(11.5, weight: FontWeight.w700, color: gc.ember)),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(GymColors gc, List<(IconData, String, String)> rows) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: gc.bgRaised,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                border: i < rows.length - 1
                    ? Border(bottom: BorderSide(color: gc.border.withValues(alpha: 0.6)))
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1, right: 14),
                    child: SizedBox(
                      width: 22,
                      child: Icon(rows[i].$1, size: 19, color: gc.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rows[i].$2, style: AppTheme.f(14.5, weight: FontWeight.w600, color: gc.text)),
                        const SizedBox(height: 3),
                        Text(rows[i].$3,
                            style: AppTheme.f(12.5,
                                weight: FontWeight.w500, color: gc.textSecondary, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _credits(GymColors gc) {
    final rows = <(IconData, String, String, String, Color?)>[
      (PhosphorIconsFill.heart, t.madeWithLoveBy, _kAuthor, _kAuthorUrl, gc.accent),
      (PhosphorIconsRegular.githubLogo, t.sourceCode, 'Howezzzzz/kangtu-rehab', _kRepoUrl, null),
    ];
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: gc.bgRaised,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++)
            Semantics(
              button: true,
              link: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _open(rows[i].$4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: i < rows.length - 1
                        ? Border(bottom: BorderSide(color: gc.border.withValues(alpha: 0.6)))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 14),
                        child: SizedBox(
                          width: 22,
                          child: Icon(rows[i].$1, size: 19, color: rows[i].$5 ?? gc.textSecondary),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rows[i].$2.toUpperCase(),
                                style: AppTheme.f(10,
                                    weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.3)),
                            const SizedBox(height: 4),
                            Text(rows[i].$3,
                                style: AppTheme.f(15.5, weight: FontWeight.w700, color: gc.text)),
                          ],
                        ),
                      ),
                      Icon(PhosphorIconsRegular.arrowUpRight, size: 15, color: gc.textTertiary),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
