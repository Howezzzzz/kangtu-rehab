/*
 * 康复档案详情 —— 安全门 + 问诊摘要 + AI 建议闭环 + 训练计划 + 备注。
 * 融合进 GymMane（GPLv3），随本体一同以 GPLv3 分发。
 */
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/rehab_episode.dart';
import '../services/rehab_intake.dart';
import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/liquid_notch.dart';
import '../widgets/ui_kit.dart';
import '../l10n/l10n.dart';

class RehabEpisodeScreen extends StatefulWidget {
  const RehabEpisodeScreen({super.key});

  @override
  State<RehabEpisodeScreen> createState() => _RehabEpisodeScreenState();
}

class _RehabEpisodeScreenState extends State<RehabEpisodeScreen> {
  final TextEditingController _reply = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  String? _epId;
  int _added = 0;
  int _routines = 0;
  int _adjusted = 0;
  List<String> _missed = const [];
  bool _unreadable = false;

  @override
  void dispose() {
    _reply.dispose();
    _notes.dispose();
    super.dispose();
  }

  RehabEpisode? get _ep => fit.activeEpisode;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final ep = _ep;
    if (ep == null) {
      // 档案被删或路由异常，直接回列表
      WidgetsBinding.instance.addPostFrameCallback((_) => fit.backFromRehabEpisode());
      return const SizedBox.shrink();
    }
    if (_epId != ep.id) {
      _epId = ep.id;
      _notes.text = ep.notes;
    }
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(title: ep.title, onBack: fit.backFromRehabEpisode, titleSize: 22),
            const SizedBox(height: 16),
            _gateBanner(gc, ep),
            const SizedBox(height: 14),
            _summary(gc, ep),
            const SizedBox(height: 14),
            if (ep.safe) ...[
              _aiCard(gc, ep),
              const SizedBox(height: 14),
            ],
            _planCard(gc, ep),
            const SizedBox(height: 14),
            _notesCard(gc, ep),
            const SizedBox(height: 18),
            GhostButton(
              label: t.rehabDeleteFile,
              icon: PhosphorIconsRegular.trash,
              onTap: () => _delete(ep),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 安全门 ----
  Widget _gateBanner(GymColors gc, RehabEpisode ep) {
    final safe = ep.safe;
    final color = safe ? gc.sage : gc.danger;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(safe ? PhosphorIconsRegular.shieldCheck : PhosphorIconsRegular.warning,
                size: 18, color: color),
            const SizedBox(width: 10),
            Text(safe ? t.rehabSafePass : t.rehabGateFailedShort,
                style: AppTheme.f(14, weight: FontWeight.w800, color: color)),
          ]),
          const SizedBox(height: 8),
          Text(
            safe
                ? t.rehabGatePassedNote
                : t.rehabGateFailedNote,
            style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.text, height: 1.45),
          ),
          if (!safe)
            for (final f in ep.redFlags) ...[
              const SizedBox(height: 6),
              Text('· ${t.rehabRedFlag(f)}',
                  style: AppTheme.f(12.5, weight: FontWeight.w600, color: gc.text)),
            ],
        ],
      ),
    );
  }

  // ---- 问诊摘要 ----
  Widget _summary(GymColors gc, RehabEpisode ep) {
    final rows = <(String, String)>[
      (t.rehabFieldArea, rehabAreaLabel(ep.area)),
      (t.rehabFieldDuration, rehabDurationLabel(ep.duration)),
      (t.rehabFieldPain, '${ep.pain}/10'),
      if (ep.factors.trim().isNotEmpty) (t.rehabFieldFactors, ep.factors.trim()),
      if (ep.goals.isNotEmpty) (t.rehabFieldGoals, ep.goals.map(rehabGoalLabel).join('、')),
      (t.rehabFieldGear, ep.equipment.isEmpty ? t.rehabGearBodyweight : ep.equipment.join('、')),
      (t.rehabFieldDays, t.rehabDaysCount(ep.daysPerWeek)),
    ];
    return SoftCard(
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(gc, t.rehabMySituation),
          for (final r in rows) ...[
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 84,
                child: Text(r.$1, style: AppTheme.f(12.5, weight: FontWeight.w600, color: gc.textTertiary)),
              ),
              Expanded(
                child: Text(r.$2,
                    style: AppTheme.f(13, weight: FontWeight.w500, color: gc.text, height: 1.4)),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  // ---- AI 建议闭环 ----
  Widget _aiCard(GymColors gc, RehabEpisode ep) {
    return SoftCard(
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(gc, t.rehabAiTitle),
          Text(
            '${t.rehabAiSteps}\n'
            '${t.rehabAiBlurb}',
            style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 12),
          PrimaryButton(label: t.rehabCopyPrompt, onTap: () => _copy(ep)),
          const SizedBox(height: 8),
          GhostButton(
              label: t.rehabExportPrompt,
              icon: PhosphorIconsRegular.shareNetwork,
              onTap: () => _export(ep)),
          const SizedBox(height: 14),
          TextField(
            controller: _reply,
            minLines: 5,
            maxLines: 12,
            keyboardType: TextInputType.multiline,
            onChanged: (_) => setState(() {}),
            style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.text, height: 1.35),
            cursorColor: gc.ember,
            decoration: InputDecoration(
              hintText: t.rehabPasteHint,
              hintStyle: AppTheme.f(13, weight: FontWeight.w500, color: gc.textTertiary),
              filled: true,
              fillColor: gc.bgRaised,
              contentPadding: const EdgeInsets.all(14),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _chip(gc, PhosphorIconsRegular.clipboardText, t.rehabPaste, _paste),
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showFormat = !_showFormat),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(t.rehabSeeFormat,
                    style: AppTheme.f(12.5, weight: FontWeight.w600, color: gc.ember)),
              ),
            ),
          ]),
          if (_showFormat) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: gc.bgRaised, borderRadius: BorderRadius.circular(14)),
              child: SelectableText(FitState.planTemplate,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: gc.textSecondary, height: 1.4)),
            ),
          ],
          const SizedBox(height: 12),
          PrimaryButton(
            label: t.rehabImportAdvice,
            bg: _reply.text.trim().isEmpty ? gc.bgRaised2 : gc.ember,
            fg: _reply.text.trim().isEmpty ? gc.textTertiary : gc.onEmber,
            onTap: () => _import(ep),
          ),
          if (_unreadable || _added > 0 || _adjusted > 0 || _missed.isNotEmpty) ...[
            const SizedBox(height: 12),
            _importResult(gc),
          ],
          if (ep.advice.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(t.rehabCautions,
                style: AppTheme.f(12.5, weight: FontWeight.w700, color: gc.text)),
            const SizedBox(height: 6),
            SelectableText(ep.advice,
                style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textSecondary, height: 1.5)),
          ],
        ],
      ),
    );
  }

  bool _showFormat = false;

  Widget _importResult(GymColors gc) {
    final good = _added > 0 || _adjusted > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: gc.bgRaised,
        border: Border.all(color: good ? gc.sage : gc.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _unreadable
                ? t.rehabUnreadable
                : good
                    ? t.rehabRoutinesMade(_routines, _added, _adjusted)
                    : t.rehabNoPlan,
            style: AppTheme.f(13, weight: FontWeight.w600, color: good ? gc.sage : gc.text),
          ),
          if (_missed.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(t.rehabMissedActions(_missed.join(' · ')),
                style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textTertiary, height: 1.4)),
          ],
        ],
      ),
    );
  }

  // ---- 训练计划 ----
  Widget _planCard(GymColors gc, RehabEpisode ep) {
    final rs = fit.routines.where((r) => ep.routineIds.contains(r.id)).toList();
    return SoftCard(
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(gc, t.rehabRehabPlans),
          if (rs.isEmpty)
            Text(ep.safe ? t.rehabNoAdviceYet : t.rehabGateBlocksPlan,
                style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textSecondary))
          else
            for (final r in rs) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => fit.openRoutine(r.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Icon(PhosphorIconsRegular.listChecks, size: 16, color: gc.ember),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(r.name, style: AppTheme.f(13.5, weight: FontWeight.w600, color: gc.text)),
                    ),
                    Text(t.rehabExerciseCount(r.exerciseIds.length),
                        style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textTertiary)),
                    const SizedBox(width: 6),
                    Icon(PhosphorIconsRegular.caretRight, size: 14, color: gc.textTertiary),
                  ]),
                ),
              ),
            ],
        ],
      ),
    );
  }

  // ---- 备注 ----
  Widget _notesCard(GymColors gc, RehabEpisode ep) {
    return SoftCard(
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(gc, t.rehabNotes),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 6,
            style: AppTheme.f(13, weight: FontWeight.w500, color: gc.text),
            cursorColor: gc.ember,
            decoration: InputDecoration(
              hintText: t.rehabNotesHint,
              hintStyle: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textTertiary),
              filled: true,
              fillColor: gc.bgRaised,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          GhostButton(
            label: t.rehabSaveNotes,
            icon: PhosphorIconsRegular.floppyDisk,
            onTap: () {
              ep.notes = _notes.text.trim();
              fit.updateEpisode(ep);
              showNotchToast(context, t.rehabNotesSaved, icon: PhosphorIconsFill.checkCircle, accent: gc.sage);
            },
          ),
        ],
      ),
    );
  }

  Widget _title(GymColors gc, String s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(s, style: AppTheme.f(14.5, weight: FontWeight.w800, color: gc.text)),
      );

  Widget _chip(GymColors gc, IconData icon, String label, VoidCallback onTap) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(color: gc.bgRaised, borderRadius: BorderRadius.circular(100)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: gc.text),
            const SizedBox(width: 7),
            Text(label, style: AppTheme.f(12.5, weight: FontWeight.w600, color: gc.text)),
          ]),
        ),
      );

  Future<void> _copy(RehabEpisode ep) async {
    await Clipboard.setData(ClipboardData(text: fit.rehabPromptText(ep)));
    if (!mounted) return;
    showNotchToast(context, t.rehabPromptCopied, subtitle: t.rehabPromptCopiedHint,
        icon: PhosphorIconsFill.copy, accent: context.gc.sage);
  }

  Future<void> _export(RehabEpisode ep) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/kangtu-rehab-prompt.txt');
      await file.writeAsString(fit.rehabPromptText(ep));
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: ep.title));
    } catch (_) {}
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty || !mounted) return;
    setState(() => _reply.text = text);
  }

  void _import(RehabEpisode ep) {
    final raw = _reply.text;
    if (raw.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    final res = fit.applyRehabReply(ep.id, raw);
    setState(() {
      _unreadable = res.routines == 0 && res.added == 0 && res.adjusted == 0;
      _routines = res.routines;
      _added = res.added;
      _adjusted = res.adjusted;
      _missed = res.missed;
      _epId = null; // 触发下一次 build 重新读档案（advice 可能已更新）
    });
  }

  Future<void> _delete(RehabEpisode ep) async {
    final ok = await askConfirm(
      context,
      title: t.rehabDeleteTitle,
      body: t.rehabDeleteBody,
      confirmLabel: t.rehabDelete,
      danger: true,
    );
    if (!ok || !mounted) return;
    fit.deleteEpisode(ep.id);
    fit.backFromRehabEpisode();
  }
}
