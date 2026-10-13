/*
 * 统一「日志」模块 —— 训练日志 + 康复日志 合到一处：
 *   填写（记录训练 / 记录康复）· 报表趋势 · 历史（两类合并按时间）
 * 纯本地。融合进 GymMane（GPLv3），随本体一同以 GPLv3 分发。
 */
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../l10n/l10n.dart';
import '../models/rehab_log.dart';
import '../models/workout.dart';
import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import '../widgets/glass.dart';
import '../widgets/rehab_pick.dart';
import '../widgets/ui_kit.dart';
import 'progress_screen.dart' show showDaySheet;
import 'start_sheet.dart' show showStartSheet;

class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final feed = _feed();
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: t.rehabTabLog,
              onBack: fit.backFromLog,
              titleSize: 22,
              subtitle: t.logSubtitle,
            ),
            const SizedBox(height: 16),
            // —— 填写
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: t.logWorkoutAction,
                    height: 48,
                    onTap: () => showStartSheet(context),
                  ),
                ),
                const SizedBox(width: 10),
                GhostButton(
                  label: t.logAddRehab,
                  icon: PhosphorIconsRegular.heartbeat,
                  onTap: () => showRehabLogSheet(context),
                ),
              ],
            ),
            const SizedBox(height: 22),
            // —— 报表 / 趋势
            _head(gc, t.logTrends),
            const SizedBox(height: 10),
            _Trends(),
            const SizedBox(height: 22),
            // —— 历史（训练 + 康复合并）
            _head(gc, t.history),
            const SizedBox(height: 10),
            if (feed.isEmpty)
              SoftCard(
                child: Text(t.rehabHandNoLog,
                    style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textSecondary)),
              )
            else
              for (final it in feed) ...[
                _LogRow(date: it.date, entry: it.entry),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }

  List<({DateTime date, Object entry})> _feed() => <({DateTime date, Object entry})>[
        for (final s in fit.sessions) (date: s.date, entry: s),
        for (final r in fit.rehabLog) (date: r.date, entry: r),
      ]..sort((a, b) => b.date.compareTo(a.date));

  Widget _head(GymColors gc, String title) => Row(
        children: [
          Text(title.toUpperCase(),
              style: AppTheme.f(10.5, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.4)),
        ],
      );
}

class _Trends extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final rehab = fit.rehabLog.reversed.toList(); // 旧→新
    final vol = fit.sessions.reversed.toList();
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(gc, t.logRehabTrend, fit.rehabLog.isEmpty ? null : fit.rehabLog.length),
          const SizedBox(height: 6),
          TrendChart(
            values: [for (final r in rehab) (r.isMaintain ? 4.0 : r.phase.toDouble())],
            height: 64,
            color: gc.sage,
          ),
          const SizedBox(height: 16),
          _label(gc, t.logTrainTrend, fit.sessions.isEmpty ? null : fit.sessions.length),
          const SizedBox(height: 6),
          TrendChart(
            values: [for (final s in vol) s.volume],
            height: 64,
            color: gc.ember,
          ),
        ],
      ),
    );
  }

  Widget _label(GymColors gc, String title, int? count) => Row(
        children: [
          Expanded(
            child: Text(title, style: AppTheme.f(13, weight: FontWeight.w700, color: gc.text)),
          ),
          if (count != null)
            Text('$count', style: AppTheme.f(12, weight: FontWeight.w700, color: gc.textTertiary)),
        ],
      );
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.date, required this.entry});
  final DateTime date;
  final Object entry;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    if (entry is RehabLogEntry) {
      final r = entry as RehabLogEntry;
      final color = r.light == 'g' ? gc.sage : (r.light == 'y' ? gc.warn : gc.danger);
      final light = r.light == 'g'
          ? t.rehabHandTrafficGreen
          : (r.light == 'y' ? t.rehabHandTrafficYellow : t.rehabHandTrafficRed);
      final stage = r.isMaintain ? t.rehabHandMaintain : t.rehabLogStage('${r.phase}');
      return SoftCard(
        padding: const EdgeInsets.all(12),
        child: Pressable(
          onTap: () => showRehabLogSheet(context, existing: r),
          child: Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              _tag(gc, t.logTagRehab, gc.sage),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_date(date)} · $stage · $light${r.feel.isEmpty ? '' : ' · ${r.feel}'}',
                  style: AppTheme.f(12, weight: FontWeight.w600, color: gc.text),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final s = entry as LoggedSession;
    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: Pressable(
        onTap: () => showDaySheet(context, s.date),
        child: Row(
          children: [
            _tag(gc, t.logTagTrain, gc.ember),
            const SizedBox(width: 8),
            Expanded(
              child: Text(fit.workoutText(s),
                  style: AppTheme.f(12, weight: FontWeight.w600, color: gc.text),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(GymColors gc, String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(100)),
        child: Text(label, style: AppTheme.f(10.5, weight: FontWeight.w800, color: c)),
      );

  String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// 康复日志 填写/编辑 底部弹层
// ---------------------------------------------------------------------------

Future<void> showRehabLogSheet(BuildContext context, {RehabLogEntry? existing}) => showAppSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => RehabLogSheet(existing: existing),
    );

class RehabLogSheet extends StatefulWidget {
  const RehabLogSheet({super.key, this.existing});
  final RehabLogEntry? existing;

  @override
  State<RehabLogSheet> createState() => _RehabLogSheetState();
}

class _RehabLogSheetState extends State<RehabLogSheet> {
  late int _phase = widget.existing?.phase ?? 1;
  late String _light = widget.existing?.light ?? 'g';
  late final TextEditingController _feel = TextEditingController(text: widget.existing?.feel ?? '');

  @override
  void dispose() {
    _feel.dispose();
    super.dispose();
  }

  void _save() {
    final e = widget.existing;
    if (e == null) {
      fit.addRehabLog(RehabLogEntry(
        id: 'r${DateTime.now().microsecondsSinceEpoch}',
        date: DateTime.now(),
        phase: _phase,
        light: _light,
        feel: _feel.text.trim(),
      ));
    } else {
      fit.updateRehabLog(RehabLogEntry(
        id: e.id,
        date: e.date,
        phase: _phase,
        light: _light,
        feel: _feel.text.trim(),
      ));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return Container(
      decoration: BoxDecoration(
        color: gc.bgRaised,
        border: Border.all(color: gc.border),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          const SizedBox(height: 12),
          Text(widget.existing == null ? t.logAddRehab : t.rehabHandHistory,
              style: AppTheme.f(19, weight: FontWeight.w800, color: gc.text)),
          const SizedBox(height: 14),
          RehabPick(
            phase: _phase,
            light: _light,
            onPhase: (p) => setState(() => _phase = p),
            onLight: (l) => setState(() => _light = l),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _feel,
            maxLines: 2,
            style: AppTheme.f(13, weight: FontWeight.w500, color: gc.text),
            decoration: InputDecoration(
              hintText: t.rehabHandFeel,
              hintStyle: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textTertiary),
              filled: true,
              fillColor: gc.mutedFill,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (widget.existing != null) ...[
                GhostButton(
                  label: t.rehabHandDelete,
                  icon: PhosphorIconsRegular.trash,
                  onTap: () {
                    fit.deleteRehabLog(widget.existing!.id);
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: PrimaryButton(label: t.rehabHandSaveLog, height: 48, onTap: _save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
