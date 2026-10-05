/*
 * 训练后反馈 —— 整体感觉 + 不适部位/程度 + 一句话记录。
 * 完成页和历史详情共用同一个弹层。
 * 融合进 GymMane（GPLv3），随本体一同以 GPLv3 分发。
 */
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../l10n/l10n.dart';
import '../models/exercise.dart' show kMuscles, muscleLabel;
import '../models/workout.dart';
import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'glass.dart';
import 'liquid_notch.dart';
import 'ui_kit.dart';

/// 0 很轻松 / 1 刚好 / 2 吃力 / 3 拼到底
String feelLabel(int i) => switch (i) {
      0 => t.fbFeelEasy,
      1 => t.fbFeelOk,
      2 => t.fbFeelHard,
      _ => t.fbFeelMax,
    };

/// 四档感觉的本地化文案（0 很轻松 … 3 拼到底）
List<String> feelLabels() => [for (var i = 0; i < 4; i++) feelLabel(i)];

const _feelIcons = [  PhosphorIconsRegular.smiley,
  PhosphorIconsRegular.thumbsUp,
  PhosphorIconsRegular.fire,
  PhosphorIconsRegular.skull,
];

/// 康复档案的「部位」→ 身体肌群 id（用来提示同部位不适）
const Map<String, String> _rehabAreaMuscle = {
  'lowback': 'back',
  'neck': 'trapezius',
  'shoulder': 'shoulders',
  'elbow': 'forearm',
  'hip': 'glutes',
  'knee': 'quads',
  'ankle': 'calves',
};

bool _rehabWorthMentioning(LoggedSession s) {
  if (s.painArea.isEmpty || s.painLevel < 5) return false;
  for (final ep in fit.rehabEpisodes) {
    if (ep.status != 'active') continue;
    final want = _rehabAreaMuscle[ep.area];
    if (want == null || want == s.painArea) return true;
  }
  return false;
}

Future<void> showSessionFeedbackSheet(BuildContext context, LoggedSession s) async {
  final gc = context.gc;
  await showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      var feel = s.feel;
      var painArea = s.painArea;
      var pain = s.painLevel;
      final note = TextEditingController(text: s.note);
      return StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
            decoration: BoxDecoration(
              color: gc.bgRaised,
              border: Border.all(color: gc.border),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SheetHandle(),
                    const SizedBox(height: 18),
                    Text(t.fbTitle, style: AppTheme.d(20, weight: FontWeight.w700, color: gc.text)),
                    const SizedBox(height: 4),
                    Text(t.fbPrompt, style: AppTheme.s(12.5, color: gc.textSecondary)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < 4; i++)
                          _chip(
                            gc,
                            feelLabel(i),
                            icon: _feelIcons[i],
                            on: feel == i,
                            tap: () => setSheet(() => feel = feel == i ? null : i),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(t.fbPain, style: AppTheme.d(14, weight: FontWeight.w700, color: gc.text)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in kMuscles)
                          _chip(
                            gc,
                            muscleLabel(m.id),
                            on: painArea == m.id,
                            tap: () => setSheet(() {
                              painArea = painArea == m.id ? '' : m.id;
                              if (painArea.isEmpty) pain = 0;
                            }),
                          ),
                      ],
                    ),
                    if (painArea.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text('${t.fbPainLevel}：$pain/10',
                          style: AppTheme.d(13, weight: FontWeight.w600, color: gc.text)),
                      Slider(
                        value: pain.toDouble(),
                        min: 0,
                        max: 10,
                        divisions: 10,
                        activeColor: gc.ember,
                        label: '$pain',
                        onChanged: (v) => setSheet(() => pain = v.round()),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: note,
                      minLines: 2,
                      maxLines: 5,
                      style: AppTheme.s(13, color: gc.text),
                      cursorColor: gc.ember,
                      decoration: InputDecoration(
                        hintText: t.notePlaceholder,
                        hintStyle: AppTheme.s(12.5, color: gc.textTertiary),
                        filled: true,
                        fillColor: gc.bgRaised2,
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    if (painArea.isNotEmpty && pain >= 5) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Icon(PhosphorIconsRegular.warning, size: 16, color: gc.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(t.fbRehabHint,
                              style: AppTheme.s(12, color: gc.textSecondary, height: 1.4)),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 18),
                    PrimaryButton(
                      label: t.save,
                      onTap: () {
                        fit.setSessionFeedback(s,
                            feel: feel,
                            painArea: painArea,
                            painLevel: pain,
                            note: note.text.trim());
                        Navigator.of(sheetCtx).pop();
                        showNotchToast(context, t.fbTitle,
                            icon: PhosphorIconsFill.checkCircle, accent: context.gc.sage);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _chip(GymColors gc, String label, {IconData? icon, required bool on, required VoidCallback tap}) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: tap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: on ? gc.ember : gc.bgRaised2,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: on ? Colors.transparent : gc.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: on ? gc.onEmber : gc.textSecondary),
          const SizedBox(width: 6),
        ],
        Text(label,
            style: AppTheme.d(12.5, weight: FontWeight.w600, color: on ? gc.onEmber : gc.text)),
      ]),
    ),
  );
}

/// 完成页 / 历史详情里的反馈卡（未记录时点一下即可填）
class SessionFeedbackCard extends StatelessWidget {
  const SessionFeedbackCard(this.session, {super.key});
  final LoggedSession session;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final s = session;
    final has = s.hasFeedback;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showSessionFeedbackSheet(context, s),
      child: SoftCard(
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(PhosphorIconsRegular.clipboardText, size: 17, color: gc.ember),
              const SizedBox(width: 9),
              Expanded(
                child: Text(t.fbTitle,
                    style: AppTheme.d(14.5, weight: FontWeight.w700, color: gc.text)),
              ),
              Text(t.editEntry, style: AppTheme.d(12, weight: FontWeight.w600, color: gc.ember)),
            ]),
            if (!has) ...[
              const SizedBox(height: 8),
              Text(t.fbPrompt, style: AppTheme.s(12.5, color: gc.textSecondary)),
            ] else ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (s.feel != null) _tag(gc, feelLabel(s.feel!), gc.sage),
                  if (s.painArea.isNotEmpty)
                    _tag(gc, '${muscleLabel(s.painArea)} ${s.painLevel}/10', gc.danger),
                ],
              ),
              if (s.note.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(s.note.trim(),
                    style: AppTheme.s(12.5, color: gc.textSecondary, height: 1.45)),
              ],
              if (_rehabWorthMentioning(s)) ...[
                const SizedBox(height: 8),
                Text(t.fbRehabHint, style: AppTheme.s(11.5, color: gc.danger, height: 1.35)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _tag(GymColors gc, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(text, style: AppTheme.d(12, weight: FontWeight.w600, color: color)),
      );
}
