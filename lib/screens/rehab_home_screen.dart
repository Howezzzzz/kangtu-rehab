/*
 * 「康复」模块首页 —— 康复档案为主（个性化），康复手册为次（静态内容）。
 * 不依赖任何在线服务。
 */
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'rehab_episodes_screen.dart';
import '../l10n/l10n.dart';

class RehabHomeScreen extends StatelessWidget {
  const RehabHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: t.rehabTitle,
              onBack: fit.backFromRehabHome,
              titleSize: 22,
              subtitle: t.rehabModuleSubtitle,
            ),
            const SizedBox(height: 16),
            // —— 康复档案（主）
            const RehabEpisodesBody(),
            const SizedBox(height: 20),
            // —— 康复手册（静态内容，次级入口）
            Pressable(
              onTap: fit.goRehabBook,
              child: SoftCard(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: gc.emberSoft, shape: BoxShape.circle),
                      child: Icon(PhosphorIconsRegular.bookOpenText, size: 18, color: gc.ember),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.rehabBookTitle,
                              style: AppTheme.f(15, weight: FontWeight.w800, color: gc.text)),
                          const SizedBox(height: 2),
                          Text(t.rehabBookBlurb,
                              style: AppTheme.f(12,
                                  weight: FontWeight.w500, color: gc.textSecondary)),
                        ],
                      ),
                    ),
                    Text(t.rehabEnter, style: AppTheme.f(12, weight: FontWeight.w700, color: gc.ember)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
