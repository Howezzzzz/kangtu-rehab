/*
 * 康复记录选择器：阶段（1/2/3/维持）+ 红绿灯（绿/黄/红），并显示所选选项的说明。
 * 训练后反馈 与 统一「日志」页共用。
 * 融合进 GymMane（GPLv3），随本体一同以 GPLv3 分发。
 */
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// phase: 1/2/3 = 阶段，4 = 维持期；light: 'g' 绿 | 'y' 黄 | 'r' 红。
class RehabPick extends StatelessWidget {
  const RehabPick({
    super.key,
    required this.phase,
    required this.light,
    required this.onPhase,
    required this.onLight,
  });

  final int phase;
  final String light;
  final ValueChanged<int> onPhase;
  final ValueChanged<String> onLight;

  static const _phases = [1, 2, 3, 4];

  int get _p => phase >= 4 ? 4 : (phase <= 0 ? 1 : phase);

  String _phaseLabel(int p) => p >= 4 ? t.rehabHandMaintain : t.rehabLogStage('$p');
  String _phaseDesc(int p) => switch (p) {
        1 => t.rehabStPhaseDesc1,
        2 => t.rehabStPhaseDesc2,
        3 => t.rehabStPhaseDesc3,
        _ => t.rehabStPhaseDescMaintain,
      };

  String _lightLabel(String l) =>
      l == 'g' ? t.rehabHandTrafficGreen : (l == 'y' ? t.rehabHandTrafficYellow : t.rehabHandTrafficRed);
  String _lightDesc(String l) =>
      l == 'g' ? t.rehabStLightDescGreen : (l == 'y' ? t.rehabStLightDescAmber : t.rehabStLightDescRed);
  Color _lightColor(GymColors gc, String l) =>
      l == 'g' ? gc.sage : (l == 'y' ? gc.warn : gc.danger);

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in _phases)
              _chip(gc, _phaseLabel(p), _p == p, () => onPhase(p)),
          ],
        ),
        const SizedBox(height: 6),
        Text(_phaseDesc(_p),
            style: AppTheme.f(11.5, weight: FontWeight.w500, color: gc.textSecondary, height: 1.45)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final l in const ['g', 'y', 'r'])
              _chip(gc, _lightLabel(l), light == l, () => onLight(l), color: _lightColor(gc, l)),
          ],
        ),
        const SizedBox(height: 6),
        Text(_lightDesc(light),
            style: AppTheme.f(11.5, weight: FontWeight.w500, color: gc.textSecondary, height: 1.45)),
      ],
    );
  }

  Widget _chip(GymColors gc, String label, bool on, VoidCallback tap, {Color? color}) {
    final c = color ?? gc.ember;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: on ? c : gc.bgRaised2,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: on ? Colors.transparent : gc.border),
        ),
        child: Text(label,
            style: AppTheme.f(12.5,
                weight: FontWeight.w700, color: on ? gc.onEmber : gc.textSecondary)),
      ),
    );
  }
}
