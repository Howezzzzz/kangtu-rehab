import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../catalog/program_templates.dart';
import '../l10n/l10n.dart';
import '../models/progression.dart';
import '../models/workout.dart';
import '../services/plan_pdf.dart';
import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/glass.dart';
import '../widgets/liquid_notch.dart';
import '../widgets/routine_folder.dart';
import '../widgets/svg_icon.dart';
import '../widgets/ui_kit.dart';
import 'plan_import_sheet.dart';

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: t.routines,
              onBack: fit.backFromRoutines,
              titleSize: 22,
              actions: [
                Semantics(
                  button: true,
                  label: t.importRoutines,
                  child: RoundAction(
                    onTap: () => showPlanImportSheet(context),
                    child: Icon(PhosphorIconsRegular.downloadSimple, size: 17, color: gc.text),
                  ),
                ),
                if (fit.activeRoutines.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: t.shareWeek,
                    child: RoundAction(
                      onTap: () => _shareMenu(context),
                      child: Icon(PhosphorIconsRegular.shareNetwork, size: 17, color: gc.text),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: Text(fit.rotation ? t.rotationTitle : t.weeklyPlan,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.f(12, weight: FontWeight.w600, color: gc.textSecondary, letterSpacing: 1.5)),
              ),
              const SizedBox(width: 8),
              SegToggle(
                [
                  SegOption(t.planFixedWeek, !fit.rotation, () => fit.setRotation(false)),
                  SegOption(t.planRotation, fit.rotation, () => fit.setRotation(true)),
                ],
                hPad: 10,
                vPad: 5,
                fontSize: 11,
              ),
            ]),
            const SizedBox(height: 10),
            if (fit.rotation)
              _rotationCard(context, gc)
            else
              SoftCard(
                radius: 20,
                borderColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Column(children: [for (int i = 0; i < 7; i++) _dayRow(context, gc, i)]),
              ),
            if (!fit.rotation && fit.activeRoutines.isNotEmpty) ...[
              const SizedBox(height: 10),
              _plansRow(context, gc),
            ],
            const SizedBox(height: 26),
            if (fit.planCycles.isNotEmpty) ...[
              Text(t.cycleTitle,
                  style: AppTheme.f(12,
                      weight: FontWeight.w600, color: gc.textSecondary, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              for (final e in fit.planCycles.entries) _cycleStatus(context, gc, e.key),
              const SizedBox(height: 26),
            ],
            Text(t.yourRoutines, style: AppTheme.f(12, weight: FontWeight.w600, color: gc.textSecondary, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            if (fit.activeRoutines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 26),
                child: Text(t.noRoutines,
                    textAlign: TextAlign.center, style: AppTheme.f(13, weight: FontWeight.w500, color: gc.textSecondary)),
              )
            else ...[
              for (final group in fit.routineGroups) ...[
                _groupHeader(context, gc, group, fit.routinesInGroup(group).length),
                _folders(context, fit.routinesInGroup(group)),
                const SizedBox(height: 10),
              ],
              _folders(context, fit.routinesInGroup('')),
            ],
            if (fit.archivedRoutines.isNotEmpty) ...[
              const SizedBox(height: 6),
              _archivedHeader(gc),
              if (fit.showArchivedRoutines) Opacity(opacity: 0.6, child: _folders(context, fit.archivedRoutines)),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              label: t.newRoutine,
              onTap: () => fit.openRoutine(fit.createRoutine()),
            ),
            const SizedBox(height: 10),
            GhostButton(
              label: t.templates,
              icon: PhosphorIconsRegular.stack,
              onTap: () => _openTemplates(context),
            ),
            const SizedBox(height: 10),
            GhostButton(
              label: t.importRoutines,
              icon: PhosphorIconsRegular.downloadSimple,
              onTap: () => showPlanImportSheet(context),
            ),
            const SizedBox(height: 10),
            GhostButton(
              label: t.aiRoutine,
              icon: PhosphorIconsRegular.sparkle,
              onTap: fit.goAiPlan,
            ),
          ],
        ),
      ),
    );
  }

  void _shareMenu(BuildContext context) {
    final gc = context.gc;
    final planned = fit.activeRoutines.where((r) => [for (var d = 1; d <= 7; d++) ...fit.planIdsOn(d)].contains(r.id)).toList();
    showAppSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheet) => Container(
        padding: sheetPad(sheet),
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.85),
        decoration: BoxDecoration(
          color: gc.bgRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              const SizedBox(height: 18),
              _shareOption(gc, PhosphorIconsRegular.calendarDots, t.shareWeek, t.shareWeekHint, () {
                Navigator.pop(sheet);
                sharePlan(planned.isEmpty ? fit.activeRoutines : [
                  ...planned,
                  ...fit.activeRoutines.where((r) => !planned.contains(r)),
                ], title: t.weeklyPlan);
              }),
              _shareOption(gc, PhosphorIconsRegular.filePdf, t.pdfPlan, t.pdfPlanHint, () {
                Navigator.pop(sheet);
                sharePlanPdf(planned.isEmpty ? fit.activeRoutines : [
                  ...planned,
                  ...fit.activeRoutines.where((r) => !planned.contains(r)),
                ], week: true);
              }),
              const SizedBox(height: 14),
              Text(t.shareRoutine.toUpperCase(),
                  style: AppTheme.f(10.5, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.3)),
              const SizedBox(height: 8),
              for (final r in [
                for (final group in fit.routineGroups) ...fit.routinesInGroup(group),
                ...fit.routinesInGroup(''),
              ])
                _shareOption(
                  gc,
                  PhosphorIconsRegular.listChecks,
                  fit.routineTitle(r),
                  [if (r.group.isNotEmpty) r.group, t.exerciseCount(r.exerciseIds.length)].join(' · '),
                  () {
                    Navigator.pop(sheet);
                    sharePlan([r]);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _plansRow(BuildContext context, GymColors gc) {
    Widget chip(String label, bool active, VoidCallback onTap, {IconData? icon}) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: active ? gc.ember : gc.bgRaised,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active ? gc.ember : gc.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: gc.textSecondary),
                const SizedBox(width: 5),
              ],
              Text(label,
                  style: AppTheme.f(12.5,
                      weight: FontWeight.w600, color: active ? gc.onEmber : (icon != null ? gc.textSecondary : gc.text))),
            ]),
          ),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final p in fit.savedPlans) ...[
          chip(p.name, p.id == fit.currentPlanId, () {
            if (p.id == fit.currentPlanId) return _planMenu(context, p);
            HapticFeedback.selectionClick();
            fit.switchPlan(p.id);
          }),
          const SizedBox(width: 8),
        ],
        chip(t.planNew, false, () => _newPlanSheet(context), icon: PhosphorIconsBold.plus),
      ]),
    );
  }

  Future<void> _namePlan(BuildContext context, {required bool empty}) async {
    final name = await askText(context, title: t.planName, hint: t.planNameHint);
    if (name != null && name.trim().isNotEmpty) fit.savePlanAs(name, empty: empty);
  }

  void _newPlanSheet(BuildContext context) {
    final gc = context.gc;
    showAppSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheet) => Container(
        padding: sheetPad(sheet),
        decoration: BoxDecoration(
          color: gc.bgRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 16),
            SheetTitle(t.planNew, subtitle: t.plansHint),
            const SizedBox(height: 14),
            _shareOption(gc, PhosphorIconsRegular.floppyDisk, t.planSaveWeek, t.planSaveWeekHint, () {
              Navigator.pop(sheet);
              _namePlan(context, empty: false);
            }, trailing: PhosphorIconsRegular.caretRight),
            _shareOption(gc, PhosphorIconsRegular.calendarBlank, t.planEmptyWeek, t.planEmptyWeekHint, () {
              Navigator.pop(sheet);
              _namePlan(context, empty: true);
            }, trailing: PhosphorIconsRegular.caretRight),
          ],
        ),
      ),
    );
  }

  void _planMenu(BuildContext context, SavedPlan p) {
    final gc = context.gc;
    showAppSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheet) => Container(
        padding: sheetPad(sheet),
        decoration: BoxDecoration(
          color: gc.bgRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 16),
            SheetTitle(p.name, subtitle: t.plansHint),
            const SizedBox(height: 14),
            OptionGroup([
              OptionItem(t.planRename, icon: PhosphorIconsRegular.pencilSimple, onTap: () async {
                Navigator.pop(sheet);
                final name = await askText(context, title: t.planName, initial: p.name, hint: t.planNameHint);
                if (name != null) fit.renamePlan(p.id, name);
              }),
              OptionItem(t.planDelete, icon: PhosphorIconsRegular.trash, danger: true, onTap: () async {
                Navigator.pop(sheet);
                final ok = await askConfirm(context,
                    title: t.planDelete, body: t.planDeleteBody, confirmLabel: t.delete, danger: true);
                if (ok) fit.deletePlan(p.id);
              }),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _shareOption(GymColors gc, IconData icon, String title, String hint, VoidCallback onTap,
      {IconData trailing = PhosphorIconsRegular.shareNetwork}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: gc.bgRaised2, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: gc.emberSoft, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 19, color: gc.ember),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.f(14, weight: FontWeight.w600, color: gc.text)),
                const SizedBox(height: 2),
                Text(hint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.f(11.5, weight: FontWeight.w500, color: gc.textSecondary)),
              ],
            ),
          ),
          Icon(trailing, size: 16, color: gc.textSecondary),
        ]),
      ),
    );
  }

  void _openTemplates(BuildContext context) {
    final gc = context.gc;
    showAppSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheet) => Container(
        padding: sheetPad(sheet),
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.85),
        decoration: BoxDecoration(
          color: gc.bgRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              const SizedBox(height: 16),
              SheetTitle(t.templates, subtitle: t.templatesHint),
              const SizedBox(height: 16),
              for (final template in kProgramTemplates)
                _templateCard(context, gc, sheet, template),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _templateCard(
      BuildContext context, GymColors gc, BuildContext sheet, ProgramTemplate template) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.pop(sheet);
        _templateDetail(context, template);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: gc.bgRaised2,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: gc.emberSoft, borderRadius: BorderRadius.circular(12)),
              child: Icon(PhosphorIconsRegular.stack, size: 20, color: gc.ember),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(t.templateName(template.id, template.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.f(15, weight: FontWeight.w700, color: gc.text, letterSpacing: 0.5)),
                    ),
                    if (template.pro) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: gc.sage.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(PhosphorIconsFill.lightning, size: 9, color: gc.sage),
                          const SizedBox(width: 3),
                          Text(t.progBadge,
                              style: AppTheme.f(9, weight: FontWeight.w700, color: gc.sage, letterSpacing: 0.3)),
                        ]),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(t.templateBlurb(template.id),
                      style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textSecondary, height: 1.35)),
                  const SizedBox(height: 4),
                  Text(t.dayCount(template.days.length),
                      style: AppTheme.f(11, weight: FontWeight.w500, color: gc.textTertiary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(PhosphorIconsRegular.plus, size: 16, color: gc.textSecondary),
          ],
        ),
      ),
    );
  }

  // ---- 计划详情页(融合式:展示周结构/组次/渐进规则,一键开始) ----

  void _templateDetail(BuildContext context, ProgramTemplate template) {
    final gc = context.gc;
    // 同名训练日合并展示(如 5×5 的 A 日周一/周五)
    final dayNames = <String>[];
    final dayWds = <String, List<int>>{};
    final dayExs = <String, List<ProgramExercise>>{};
    for (final d in template.days) {
      if (!dayExs.containsKey(d.name)) {
        dayNames.add(d.name);
        dayExs[d.name] = d.exercises;
        dayWds[d.name] = [];
      }
      if (d.weekday != null) dayWds[d.name]!.add(d.weekday!);
    }
    showAppSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheet) => Container(
        padding: sheetPad(sheet),
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.88),
        decoration: BoxDecoration(
          color: gc.bgRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              const SizedBox(height: 16),
              SheetTitle(t.templateName(template.id, template.name),
                  subtitle: t.templateBlurb(template.id)),
              const SizedBox(height: 14),
              if (template.pro) ...[_progBadges(context, gc, template), const SizedBox(height: 14)],
              for (final name in dayNames) ...[
                _dayDetailCard(context, gc, name, dayWds[name]!, dayExs[name]!),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
              PrimaryButton(
                label: t.tplStart,
                onTap: () => _startProgram(context, sheet, template),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progBadges(BuildContext context, GymColors gc, ProgramTemplate template) {
    final kinds = <ProgKind>{};
    for (final d in template.days) {
      for (final e in d.exercises) {
        if (e.spec != null) kinds.add(e.spec!.kind);
      }
    }
    String label(ProgKind k) => switch (k) {
          ProgKind.linear => t.progLinShort,
          ProgKind.dbl => t.progDblShort,
          ProgKind.reps => t.progRepsShort,
          ProgKind.cycle => t.progCycleShort,
        };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: gc.sage.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(PhosphorIconsFill.lightning, size: 14, color: gc.sage),
          const SizedBox(width: 6),
          Text(t.progBadge, style: AppTheme.f(13, weight: FontWeight.w700, color: gc.sage)),
        ]),
        const SizedBox(height: 6),
        for (final k in kinds)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('· ${label(k)}',
                style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textSecondary, height: 1.4)),
          ),
      ]),
    );
  }

  Widget _dayDetailCard(
      BuildContext context, GymColors gc, String dayName, List<int> weekdays, List<ProgramExercise> exs) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: gc.bgRaised2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(dayName,
                style: AppTheme.f(14, weight: FontWeight.w700, color: gc.text)),
          ),
          if (weekdays.isNotEmpty)
            Text(weekdays.map((w) => t.weekdayShort(w)).join(' · '),
                style: AppTheme.f(11, weight: FontWeight.w600, color: gc.ember)),
        ]),
        const SizedBox(height: 8),
        for (final pe in exs)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(children: [
              Expanded(
                child: Text(_tplExerciseName(pe.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.f(13, weight: FontWeight.w500, color: gc.textSecondary)),
              ),
              const SizedBox(width: 8),
              Text(_schemeLabel(pe),
                  style: AppTheme.f(12, weight: FontWeight.w700, color: gc.text, letterSpacing: 0.3)),
            ]),
          ),
      ]),
    );
  }

  String _tplExerciseName(String name) {
    final ex = fit.matchExerciseByName(name);
    if (ex == null) return name;
    return t.catalogName(ex.id, ex.name);
  }

  String _schemeLabel(ProgramExercise pe) {
    final s = pe.spec;
    if (s == null) return '${pe.sets} ×';
    return switch (s.kind) {
      ProgKind.linear => '${s.sets}×${s.reps}',
      ProgKind.dbl || ProgKind.reps => '${s.sets}×${s.repMin}-${s.repMax}',
      ProgKind.cycle => t.progCycleWeeks(s.weeks.length),
    };
  }

  Future<void> _startProgram(
      BuildContext context, BuildContext sheet, ProgramTemplate template) async {
    Map<String, double>? tm;
    if (template.hasCycle) {
      tm = await _askTrainingMax(context, template);
      if (tm == null) return;
    }
    final made = fit.applyTemplate(template, tm: tm);
    if (!context.mounted) return;
    Navigator.pop(sheet);
    if (made == 0) return;
    showNotchToast(context, t.templateAdded(made),
        subtitle: t.templateName(template.id, template.name),
        icon: PhosphorIconsFill.stack,
        accent: context.gc.sage);
  }

  Future<Map<String, double>?> _askTrainingMax(
      BuildContext context, ProgramTemplate template) {
    final gc = context.gc;
    final lifts = template.cycleLifts;
    final controllers = <String, TextEditingController>{};
    for (final name in lifts) {
      final ex = fit.matchExerciseByName(name);
      final est = ex == null ? null : estimateTrainingMax(fit, ex.id);
      final shown = fit.toDisplayWeight(est ?? 40);
      controllers[name] = TextEditingController(
          text: shown == shown.roundToDouble()
              ? shown.toStringAsFixed(0)
              : shown.toStringAsFixed(1));
    }
    return showDialog<Map<String, double>>(
      context: context,
      builder: (dlg) => AlertDialog(
        backgroundColor: gc.bgRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.tmTitle,
            style: AppTheme.f(16, weight: FontWeight.w700, color: gc.text)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.tmHint(fit.units),
                  style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textSecondary, height: 1.45)),
              const SizedBox(height: 14),
              for (final name in lifts) ...[
                Text(_tplExerciseName(name),
                    style: AppTheme.f(13, weight: FontWeight.w600, color: gc.text)),
                const SizedBox(height: 4),
                TextField(
                  controller: controllers[name],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTheme.f(14, weight: FontWeight.w600, color: gc.text),
                  decoration: InputDecoration(
                    isDense: true,
                    suffixText: fit.units,
                    suffixStyle: AppTheme.f(12, color: gc.textTertiary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: gc.bgRaised2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlg),
            child: Text(t.cancel,
                style: AppTheme.f(13, weight: FontWeight.w600, color: gc.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final out = <String, double>{};
              for (final e in controllers.entries) {
                final v = double.tryParse(e.value.text.trim().replaceAll(',', '.'));
                if (v != null && v > 0) out[e.key] = fit.fromDisplayWeight(v);
              }
              Navigator.pop(dlg, out);
            },
            child: Text(t.done,
                style: AppTheme.f(13, weight: FontWeight.w700, color: gc.ember)),
          ),
        ],
      ),
    ).whenComplete(() {
      for (final c in controllers.values) {
        c.dispose();
      }
    });
  }

  Widget _cycleStatus(BuildContext context, GymColors gc, String routineId) {
    final c = fit.cycleOf(routineId);
    final r = fit.routines.where((x) => x.id == routineId).firstOrNull;
    if (c == null || r == null) return const SizedBox.shrink();
    final wk = c.weekIndex(DateTime.now());
    final done = fit.cycleDoneSessions(routineId);
    final whole = c.weeks * c.perWeek;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name, style: AppTheme.f(14, weight: FontWeight.w800, color: gc.text)),
                  const SizedBox(height: 2),
                  Text(
                    '${wk == null ? t.cycleComplete : t.cycleWeekXY('$wk', '${c.weeks}')}'
                    ' · ${t.cycleDone('$done', '$whole')}'
                    '${c.round > 1 ? ' · ${t.cycleRound(c.round)}' : ''}',
                    style: AppTheme.f(11.5, weight: FontWeight.w500, color: gc.textSecondary),
                  ),
                ],
              ),
            ),
            if (c.expired)
              TextButton(
                onPressed: () => fit.advanceCycle(routineId),
                child: Text(t.cycleRenew,
                    style: AppTheme.f(12.5, weight: FontWeight.w700, color: gc.ember)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _rotationCard(BuildContext context, GymColors gc) {
    final list = fit.rotationSteps;
    final step = fit.rotationStep;
    final routines = fit.rotationRoutines;
    return SoftCard(
      radius: 20,
      borderColor: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(routines.isEmpty ? t.rotationEmpty : t.rotationHint,
                style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textSecondary, height: 1.35)),
          ),
          if (list.length > 1) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      height: 5,
                      decoration: BoxDecoration(
                        color: i < step
                            ? gc.sage
                            : i == step
                                ? gc.ember
                                : gc.bgRaised2,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(t.rotationProgress(step, list.length),
                  style: AppTheme.f(11.5, weight: FontWeight.w600, color: gc.textTertiary)),
            ),
          ],
          const SizedBox(height: 8),
          ReorderableListView(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            physics: const NeverScrollableScrollPhysics(),
            proxyDecorator: liftedRow(14),
            onReorderStart: reorderPicked,
            onReorderEnd: reorderDropped,
            onReorder: fit.reorderRotation,
            children: [
              for (var i = 0; i < list.length; i++)
                if (RoutinesState.isRestStep(list[i]))
                  _rotationRestRow(context, gc, list[i], i, i == step)
                else
                  _rotationRow(context, gc, fit.routineById(list[i])!, i, i == step,
                      routines.indexWhere((r) => r.id == list[i])),
            ],
          ),
          _rotationAddRow(gc, PhosphorIconsBold.plus, t.rotationAdd, () => _pickRotation(context)),
          if (routines.isNotEmpty)
            _rotationAddRow(gc, PhosphorIconsRegular.bed, t.rotationAddRest, () {
              HapticFeedback.selectionClick();
              fit.addRotationRest();
            }),
          if (list.length > 1) ...[
            Divider(height: 1, thickness: 1, indent: 12, endIndent: 12, color: gc.border),
            Row(children: [
              Expanded(child: _rotationAction(gc, PhosphorIconsRegular.skipForward, t.rotationSkip, fit.skipRotation)),
              Container(width: 1, height: 18, color: gc.border),
              Expanded(
                child: _rotationAction(
                    gc, PhosphorIconsRegular.arrowCounterClockwise, t.rotationRestart, fit.restartRotation),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _rotationAddRow(GymColors gc, IconData icon, String label, VoidCallback onTap) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: gc.border, width: 1.5),
              ),
              child: Icon(icon, size: 13, color: gc.textSecondary),
            ),
            const SizedBox(width: 12),
            Text(label, style: AppTheme.f(14, weight: FontWeight.w600, color: gc.textSecondary)),
          ]),
        ),
      );

  Widget _rotationRestRow(BuildContext context, GymColors gc, String id, int i, bool isNext) {
    final done = i < fit.rotationStep;
    final today = isNext && fit.restingToday;
    return Container(
      key: ValueKey('rot-$id'),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isNext ? gc.sageSoft : gc.bgRaised,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _rotationRestMenu(context, id, isNext),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
              child: Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isNext ? gc.sage : (done ? gc.sageSoft : gc.bgRaised2),
                    shape: BoxShape.circle,
                  ),
                  child: done
                      ? Icon(PhosphorIconsBold.check, size: 13, color: gc.sage)
                      : Icon(PhosphorIconsFill.bed, size: 14, color: isNext ? gc.bg : gc.textSecondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.restDayShort,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.f(14.5, weight: FontWeight.w700, color: gc.text)),
                      const SizedBox(height: 1),
                      Text(
                        [
                          if (today) t.rotationRestToday else if (isNext) t.rotationNext,
                          t.rotationRestHint,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.f(11.5,
                            weight: isNext ? FontWeight.w700 : FontWeight.w500,
                            color: isNext ? gc.sage : gc.textTertiary),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
        ReorderableDragStartListener(
          index: i,
          child: Semantics(
            label: t.reorderHandle(t.restDayShort),
            child: SizedBox(
              width: 40,
              height: 48,
              child: Icon(PhosphorIconsRegular.dotsSixVertical, size: 18, color: gc.textTertiary),
            ),
          ),
        ),
      ]),
    );
  }

  void _rotationRestMenu(BuildContext context, String id, bool isNext) {
    final gc = context.gc;
    showAppSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheet) => Container(
        padding: sheetPad(sheet),
        decoration: BoxDecoration(
          color: gc.bgRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 16),
            SheetTitle(t.restDayShort, subtitle: t.rotationRestHint),
            const SizedBox(height: 14),
            OptionGroup([
              if (isNext)
                OptionItem(t.rotationSkipRest, icon: PhosphorIconsRegular.skipForward, onTap: () {
                  Navigator.pop(sheet);
                  fit.skipRotation();
                })
              else
                OptionItem(t.rotationMakeNext, icon: PhosphorIconsRegular.flagPennant, onTap: () {
                  Navigator.pop(sheet);
                  fit.setRotationNext(id);
                }),
              OptionItem(t.rotationRemove, icon: PhosphorIconsRegular.minusCircle, danger: true, onTap: () {
                Navigator.pop(sheet);
                fit.removeRotationRest(id);
              }),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _rotationAction(GymColors gc, IconData icon, String label, VoidCallback onTap) => Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 14, color: gc.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: FitText(label, style: AppTheme.f(12, weight: FontWeight.w600, color: gc.textSecondary)),
              ),
            ]),
          ),
        ),
      );

  Widget _rotationRow(BuildContext context, GymColors gc, Routine r, int i, bool isNext, int order) {
    final letter = String.fromCharCode(65 + order % 26);
    final done = i < fit.rotationStep;
    return Container(
      key: ValueKey('rot-${r.id}'),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isNext ? gc.emberSoft : gc.bgRaised,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _rotationMenu(context, r, isNext),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
              child: Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isNext ? gc.ember : (done ? gc.sageSoft : gc.bgRaised2),
                    shape: BoxShape.circle,
                  ),
                  child: done
                      ? Icon(PhosphorIconsBold.check, size: 13, color: gc.sage)
                      : Text(letter,
                          style: AppTheme.f(13, weight: FontWeight.w800, color: isNext ? gc.onEmber : gc.text)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fit.routineTitle(r),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.f(14.5, weight: FontWeight.w700, color: gc.text)),
                      const SizedBox(height: 1),
                      Text(
                        [
                          if (isNext) t.rotationNext,
                          t.exerciseCount(r.exerciseIds.length),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.f(11.5,
                            weight: isNext ? FontWeight.w700 : FontWeight.w500,
                            color: isNext ? gc.ember : gc.textTertiary),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
        ReorderableDragStartListener(
          index: i,
          child: Semantics(
            label: t.reorderHandle(fit.routineTitle(r)),
            child: SizedBox(
              width: 40,
              height: 48,
              child: Icon(PhosphorIconsRegular.dotsSixVertical, size: 18, color: gc.textTertiary),
            ),
          ),
        ),
      ]),
    );
  }

  void _rotationMenu(BuildContext context, Routine r, bool isNext) {
    final gc = context.gc;
    showAppSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheet) => Container(
        padding: sheetPad(sheet),
        decoration: BoxDecoration(
          color: gc.bgRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 16),
            SheetTitle(fit.routineTitle(r), subtitle: t.exerciseCount(r.exerciseIds.length)),
            const SizedBox(height: 14),
            OptionGroup([
              if (!isNext)
                OptionItem(t.rotationMakeNext, icon: PhosphorIconsRegular.flagPennant, onTap: () {
                  Navigator.pop(sheet);
                  fit.setRotationNext(r.id);
                }),
              if (r.exerciseIds.isNotEmpty)
                OptionItem(titleCase(t.startWorkout), icon: PhosphorIconsRegular.play, onTap: () {
                  Navigator.pop(sheet);
                  fit.startRoutine(r);
                }),
              OptionItem(t.editEntry, icon: PhosphorIconsRegular.pencilSimple, onTap: () {
                Navigator.pop(sheet);
                fit.openRoutine(r.id);
              }),
              OptionItem(t.rotationRemove, icon: PhosphorIconsRegular.minusCircle, danger: true, onTap: () {
                Navigator.pop(sheet);
                fit.toggleRotationRoutine(r.id);
              }),
            ]),
          ],
        ),
      ),
    );
  }

  void _pickRotation(BuildContext context) {
    final gc = context.gc;
    final routines = [
      for (final group in fit.routineGroups) ...fit.routinesInGroup(group),
      ...fit.routinesInGroup(''),
    ];
    if (routines.isEmpty) {
      fit.openRoutine(fit.createRoutine());
      return;
    }
    showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => AnimatedBuilder(
        animation: fit,
        builder: (sheet, _) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.72),
          padding: sheetPad(sheet),
          decoration: BoxDecoration(
            color: gc.bgRaised,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              const SizedBox(height: 16),
              SheetTitle(t.rotationAdd, subtitle: t.rotationPickHint),
              const SizedBox(height: 14),
              Flexible(
                child: OptionGroup(
                  scroll: true,
                  [
                    for (final r in routines)
                      OptionItem(
                        fit.routineTitle(r),
                        detail: fit.rotationIds.contains(r.id)
                            ? String.fromCharCode(65 + fit.rotationRoutines.indexOf(r) % 26)
                            : (r.group.isEmpty ? null : r.group),
                        selected: fit.rotationIds.contains(r.id),
                        onTap: () => fit.toggleRotationRoutine(r.id),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              PrimaryButton(label: t.done, onTap: () => Navigator.pop(sheet)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayRow(BuildContext context, GymColors gc, int i) {
    final weekday = fit.weekdayAt(i);
    final day = fit.dateForWeekday(i);
    final assigned = fit.routinesOn(day);
    final isToday = DateTime.now().weekday == weekday;
    final moved = fit.movedOn(day);
    return GestureDetector(
      onTap: () => _pickRoutine(context, weekday, day),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Text(t.weekdayShort(weekday),
                maxLines: 1,
                softWrap: false,
                style: AppTheme.f(14, weight: FontWeight.w600, color: isToday ? gc.ember : gc.text)),
            const SizedBox(width: 14),
            if (moved) ...[
              Icon(PhosphorIconsBold.arrowsLeftRight, size: 12, color: gc.brass),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(assigned.isEmpty ? t.restDayShort : assigned.map(fit.routineTitle).join(' + '),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.f(14, weight: FontWeight.w500, color: assigned.isNotEmpty ? gc.text : gc.textTertiary)),
            ),
            const SizedBox(width: 8),
            SvgPathIcon(Ic.chevronRight, size: 14, color: gc.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _archivedHeader(GymColors gc) {
    final open = fit.showArchivedRoutines;
    return Semantics(
      button: true,
      expanded: open,
      label: t.archivedRoutines,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: fit.toggleArchivedRoutines,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4, top: 4),
          child: Row(
            children: [
              Icon(PhosphorIconsRegular.archive, size: 15, color: gc.textTertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t.archivedRoutines,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.f(13, weight: FontWeight.w700, color: gc.textSecondary, letterSpacing: 1)),
              ),
              Text('${fit.archivedRoutines.length}',
                  style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textTertiary)),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: open ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(PhosphorIconsBold.caretDown, size: 14, color: gc.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupHeader(BuildContext context, GymColors gc, String name, int count) {
    return Semantics(
      button: true,
      label: name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _groupMenu(context, name, count),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4, top: 4),
          child: Row(
            children: [
              Icon(PhosphorIconsRegular.folderSimple, size: 15, color: gc.brass),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.f(13, weight: FontWeight.w700, color: gc.text, letterSpacing: 1)),
              ),
              Text('$count', style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textTertiary)),
              const SizedBox(width: 6),
              Icon(PhosphorIconsBold.dotsThree, size: 18, color: gc.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  void _groupMenu(BuildContext context, String name, int count) {
    final gc = context.gc;
    showAppSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheet) => Container(
        padding: sheetPad(sheet),
        decoration: BoxDecoration(
          color: gc.bgRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 16),
            SheetTitle(name, subtitle: t.routineCount(count)),
            const SizedBox(height: 14),
            OptionGroup([
              OptionItem(t.groupRename, icon: PhosphorIconsRegular.pencilSimple, onTap: () async {
                Navigator.pop(sheet);
                final next = await askText(context, title: t.groupRename, initial: name, hint: t.groupNameHint);
                if (next != null && next != name) fit.renameGroup(name, next);
              }),
              OptionItem(t.groupUngroup, icon: PhosphorIconsRegular.folderSimpleMinus, onTap: () {
                Navigator.pop(sheet);
                fit.renameGroup(name, '');
              }),
              OptionItem(t.groupDeleteAll, icon: PhosphorIconsRegular.trash, danger: true, onTap: () async {
                Navigator.pop(sheet);
                final ok = await askConfirm(
                  context,
                  title: t.groupDeleteTitle(name),
                  body: t.groupDeleteBody(t.routineCount(count)),
                  confirmLabel: t.delete,
                  danger: true,
                );
                if (ok) fit.deleteGroup(name);
              }),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _folders(BuildContext context, List<Routine> list) {
    return Column(children: [
      for (var i = 0; i < list.length; i += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: RoutineFolder(routine: list[i], onMenu: () => showRoutineMenu(context, list[i]))),
            const SizedBox(width: 12),
            Expanded(
              child: i + 1 < list.length
                  ? RoutineFolder(routine: list[i + 1], onMenu: () => showRoutineMenu(context, list[i + 1]))
                  : const SizedBox.shrink(),
            ),
          ]),
        ),
    ]);
  }

  void _pickRoutine(BuildContext context, int weekday, DateTime day) {
    final gc = context.gc;
    final routines = [
      for (final group in fit.routineGroups) ...fit.routinesInGroup(group),
      ...fit.routinesInGroup(''),
    ];
    showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => AnimatedBuilder(
        animation: fit,
        builder: (sheet, _) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.72),
        padding: sheetPad(sheet),
        decoration: BoxDecoration(
          color: gc.bgRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 16),
            SheetTitle(titleCase(t.setDay(t.weekday(weekday).toUpperCase()))),
            if (fit.multiPlan) ...[
              const SizedBox(height: 4),
              Text(t.multiPlanHint, style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textSecondary)),
            ],
            if (fit.movedOn(day)) ...[
              const SizedBox(height: 14),
              OptionGroup([
                OptionItem(
                  t.backToPlan,
                  icon: PhosphorIconsRegular.arrowCounterClockwise,
                  detail: fit.routinesOn(day).map(fit.routineTitle).join(' + '),
                  onTap: () {
                    fit.undoMoves(day);
                    Navigator.pop(sheet);
                  },
                ),
              ]),
            ],
            const SizedBox(height: 14),
            Flexible(
              child: OptionGroup(
                scroll: true,
                [
                  OptionItem(
                    t.restDayShort,
                    icon: PhosphorIconsRegular.moonStars,
                    selected: fit.planIdsOn(weekday).isEmpty,
                    onTap: () {
                      fit.assignRoutineToDay(weekday, null);
                      Navigator.pop(sheet);
                    },
                  ),
                  for (final r in routines)
                    OptionItem(
                      fit.routineTitle(r),
                      detail: r.group.isEmpty ? null : r.group,
                      selected: fit.plannedOn(weekday, r.id),
                      onTap: () {
                        if (fit.multiPlan) return fit.togglePlanDay(weekday, r.id);
                        fit.assignRoutineToDay(weekday, r.id);
                        Navigator.pop(sheet);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

void showTodayPlanMenu(BuildContext context, Routine r) {
  final gc = context.gc;
  showAppSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheet) => Container(
      padding: sheetPad(sheet),
      decoration: BoxDecoration(
        color: gc.bgRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          const SizedBox(height: 16),
          SheetTitle(fit.routineTitle(r), subtitle: t.exerciseCount(r.exerciseIds.length)),
          const SizedBox(height: 14),
          OptionGroup([
            if (fit.rotating)
              OptionItem(t.rotationSkip, icon: PhosphorIconsRegular.skipForward, onTap: () {
                Navigator.pop(sheet);
                fit.skipRotation();
              })
            else
              OptionItem(t.moveToDay, icon: PhosphorIconsRegular.calendarDots, detail: t.moveToDayHint, onTap: () {
                Navigator.pop(sheet);
                showMoveDaySheet(context, r);
              }),
            OptionItem(t.editEntry, icon: PhosphorIconsRegular.pencilSimple, onTap: () {
              Navigator.pop(sheet);
              fit.openRoutine(r.id);
            }),
            OptionItem(fit.rotating ? t.planRotation : sentenceCase(t.weeklyPlan),
                icon: PhosphorIconsRegular.listChecks, onTap: () {
              Navigator.pop(sheet);
              fit.goRoutines();
            }),
          ]),
        ],
      ),
    ),
  );
}

void showMoveDaySheet(BuildContext context, Routine r) {
  final gc = context.gc;
  final today = DateTime.now();
  final days = [for (var i = 1; i <= 7; i++) DateTime(today.year, today.month, today.day + i)];
  showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheet) => Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.8),
      padding: sheetPad(sheet),
      decoration: BoxDecoration(
        color: gc.bgRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          const SizedBox(height: 16),
          SheetTitle(t.moveToDay, subtitle: fit.routineTitle(r)),
          const SizedBox(height: 4),
          Text(t.moveToDayHint,
              textAlign: TextAlign.center, style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textSecondary)),
          const SizedBox(height: 14),
          Flexible(
            child: OptionGroup(
              scroll: true,
              [
                for (final (i, d) in days.indexed)
                  OptionItem(
                    i == 0 ? t.tomorrow : '${titleCase(t.weekday(d.weekday))} ${d.day}',
                    icon: PhosphorIconsRegular.calendarBlank,
                    detail: () {
                      final there = fit.routinesOn(d);
                      return there.isEmpty ? t.restDayShort : there.map(fit.routineTitle).join(' + ');
                    }(),
                    onTap: () {
                      Navigator.pop(sheet);
                      final undo = fit.moveRoutineDay(r.id, today, d);
                      if (undo == null) return;
                      HapticFeedback.lightImpact();
                      showNotchToast(context, t.movedToast,
                          subtitle: '${fit.routineTitle(r)} → ${i == 0 ? t.tomorrow : titleCase(t.weekday(d.weekday))}',
                          icon: PhosphorIconsFill.calendarCheck,
                          accent: context.gc.brass,
                          action: t.undo,
                          onTap: undo);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void showRoutineMenu(BuildContext context, Routine r) {
  final gc = context.gc;
  showAppSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheet) => Container(
      padding: sheetPad(sheet),
      decoration: BoxDecoration(
        color: gc.bgRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          const SizedBox(height: 16),
          SheetTitle(fit.routineTitle(r), subtitle: t.exerciseCount(r.exerciseIds.length)),
          const SizedBox(height: 14),
          OptionGroup([
            OptionItem(t.editEntry, icon: PhosphorIconsRegular.pencilSimple, onTap: () {
              Navigator.pop(sheet);
              fit.openRoutine(r.id);
            }),
            if (r.exerciseIds.isNotEmpty)
              OptionItem(titleCase(t.startWorkout), icon: PhosphorIconsRegular.play, onTap: () {
                Navigator.pop(sheet);
                fit.startRoutine(r);
              }),
            OptionItem(t.shareRoutine, icon: PhosphorIconsRegular.shareNetwork, onTap: () {
              Navigator.pop(sheet);
              sharePlan([r]);
            }),
            if (r.exerciseIds.isNotEmpty)
              OptionItem(t.pdfExport, icon: PhosphorIconsRegular.filePdf, onTap: () {
                Navigator.pop(sheet);
                sharePlanPdf([r]);
              }),
            OptionItem(t.duplicateRoutine, icon: PhosphorIconsRegular.copy, onTap: () {
              Navigator.pop(sheet);
              fit.duplicateRoutine(r.id);
            }),
            OptionItem(r.archived ? t.restoreExercise : t.archiveRoutine,
                icon: r.archived ? PhosphorIconsRegular.arrowUUpLeft : PhosphorIconsRegular.archive, onTap: () {
              Navigator.pop(sheet);
              final undo = fit.archiveRoutine(r.id, !r.archived);
              if (undo == null) return;
              showNotchToast(
                context,
                t.routineArchived,
                icon: PhosphorIconsFill.archive,
                accent: gc.brass,
                action: t.undo,
                onTap: undo,
                duration: const Duration(milliseconds: 3600),
              );
            }),
            OptionItem(t.delete, icon: PhosphorIconsRegular.trash, danger: true, onTap: () async {
              Navigator.pop(sheet);
              final ok = await askConfirm(
                context,
                title: t.deleteRoutine,
                body: fit.routineTitle(r),
                confirmLabel: t.delete,
                danger: true,
              );
              if (ok) fit.deleteRoutine(r.id);
            }),
          ]),
        ],
      ),
    ),
  );
}
