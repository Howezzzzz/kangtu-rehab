/*
 * 本次小结 —— 训练完成页的单一反馈卡（融合方案 2.2 / 评审 M3）。
 *
 * 原先完成页会按条件连出三张语义重叠的「评价类」卡片：
 *   我方 SessionFeedbackCard（感觉 / 不适 / 备注）
 *   上游 _TuneCard（按肌群调下次组数）
 *   上游 CheckInCard（睡眠 / 精力）
 * 三张卡各说各话、提交语义还不一致（签到与肌群点即写，我方要点「保存」），
 * 用户在同一屏要面对三次「给这次训练打分」。这里合并为一张卡、四个分区：
 *   ① 整场感觉（点即写，再点取消）
 *   ② 今日训练量 · 按肌群（沿用上游交互与「自动调下次组数」）
 *   ③ 不适部位 / 程度 + 一句话备注（进弹层编辑）
 *   ④ 状态：睡眠 / 精力（沿用上游签到，点即写）
 *
 * 提交语义统一为「点即写 + 可撤销」（M3）：所有档位类选择点一下立刻落库、
 * 再点一次取消，因此不再需要保存按钮，也不会出现「填了一半退出就丢」。
 * 只有自由文本与不适程度滑杆仍走原弹层（那里有自己的保存）。
 *
 * 融合进 GymMane（GPLv3），随本体一同以 GPLv3 分发。
 */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../l10n/l10n.dart';
import '../models/exercise.dart' show exerciseName, muscleLabel;
import '../models/workout.dart';
import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'check_in.dart';
import 'session_feedback.dart';
import 'ui_kit.dart';

class SessionRecapCard extends StatelessWidget {
  const SessionRecapCard(this.session, {super.key});

  final LoggedSession session;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final s = session;
    final tunes = fit.tuneTargets;
    // 与上游 _TuneCard 同样的守卫：没有当前例程就没有「下次组数」可调
    final showTune = tunes.isNotEmpty && fit.sessionRoutine != null;
    final showCheckIn = fit.askCheckIn;

    return SoftCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(PhosphorIconsRegular.clipboardText, size: 17, color: gc.ember),
            const SizedBox(width: 9),
            Expanded(
              child: Text(t.fbTitle,
                  style: AppTheme.d(14.5, weight: FontWeight.w700, color: gc.text)),
            ),
          ]),
          const SizedBox(height: 12),

          // ① 整场感觉
          Text(t.fbPrompt, style: AppTheme.s(12.5, color: gc.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < 4; i++)
                fbChip(
                  gc,
                  feelLabel(i),
                  icon: kFeelIcons[i],
                  on: s.feel == i,
                  tap: () {
                    HapticFeedback.selectionClick();
                    // 点即写；再点同一档 = 取消（可撤销）
                    fit.setSessionFeedback(s,
                        feel: s.feel == i ? null : i, clearFeel: s.feel == i);
                  },
                ),
            ],
          ),
          if (rehabWorthMentioning(s)) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(PhosphorIconsRegular.warning, size: 15, color: gc.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t.fbRehabHint,
                    style: AppTheme.s(11.5, color: gc.danger, height: 1.35)),
              ),
            ]),
          ],

          // ② 按肌群调下次组数（上游交互）
          if (showTune) ...[
            _divider(gc),
            _TuneBody(tunes),
          ],

          // ③ 不适 / 备注
          _divider(gc),
          const _PainNoteRow(),

          // ④ 睡眠 / 精力（上游签到）
          if (showCheckIn) ...[
            _divider(gc),
            CheckInCard(s, flat: true),
          ],
        ],
      ),
    );
  }

  Widget _divider(GymColors gc) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 12),
        child: Container(height: 1, color: gc.border),
      );
}

/// ③ 不适部位 / 程度 + 一句话备注：紧凑一行，点进原弹层编辑（含康复记录）。
class _PainNoteRow extends StatelessWidget {
  const _PainNoteRow();

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final s = fit.filedSession;
    if (s == null) return const SizedBox.shrink();
    final note = s.note.trim();
    final hasPain = s.painArea.isNotEmpty;
    final sub = [
      if (hasPain) '${muscleLabel(s.painArea)} ${s.painLevel}/10',
      if (note.isNotEmpty) note,
    ].join(' · ');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showSessionFeedbackSheet(context, s),
      child: Row(children: [
        Icon(PhosphorIconsRegular.pencilSimple, size: 15,
            color: hasPain ? gc.danger : gc.textSecondary),
        const SizedBox(width: 9),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.fbPain, style: AppTheme.d(13, weight: FontWeight.w700, color: gc.text)),
            const SizedBox(height: 2),
            Text(sub.isEmpty ? t.notePlaceholder : sub,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.s(12,
                    color: sub.isEmpty ? gc.textTertiary : gc.textSecondary, height: 1.35)),
          ]),
        ),
        const SizedBox(width: 8),
        Text(t.editEntry, style: AppTheme.d(11.5, weight: FontWeight.w600, color: gc.ember)),
      ]),
    );
  }
}

/// ② 上游「今日训练量」按肌群投票（原 session_screen._TuneCard 的内容部分）。
class _TuneBody extends StatelessWidget {
  const _TuneBody(this.targets);

  final List<({String muscle, String exId})> targets;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final routine = fit.sessionRoutine;
    if (routine == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(t.tuneTitle.toUpperCase(),
          style: AppTheme.f(10.5,
              weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.4)),
      const SizedBox(height: 4),
      Text(t.tuneHint,
          style: AppTheme.f(12.5,
              weight: FontWeight.w500, color: gc.textSecondary, height: 1.35)),
      const SizedBox(height: 6),
      for (final m in targets) _row(gc, routine, m),
    ]);
  }

  Widget _row(GymColors gc, Routine routine, ({String muscle, String exId}) m) {
    final vote = fit.muscleVote(m.muscle);
    final ex = fit.exerciseById(m.exId);
    final sets = fit.routineSets(routine, m.exId);
    void pick(int v) => fit.voteMuscle(m.muscle, vote == v ? null : v);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(muscleLabel(m.muscle),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.f(14, weight: FontWeight.w700, color: gc.text)),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              child: vote == null || ex == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                          vote == 0
                              ? t.tuneSame
                              : t.tuneNext(t.setCount(sets), exerciseName(ex)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.f(11.5,
                              weight: FontWeight.w600,
                              color: vote == 0 ? gc.textSecondary : gc.sage,
                              height: 1.3)),
                    ),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerEnd,
            child: SegToggle([
              SegOption(t.tuneLess, vote == 1, () => pick(1)),
              SegOption(t.tuneRight, vote == 0, () => pick(0)),
              SegOption(t.tuneMore, vote == -1, () => pick(-1)),
            ], hPad: 10),
          ),
        ),
      ]),
    );
  }
}
