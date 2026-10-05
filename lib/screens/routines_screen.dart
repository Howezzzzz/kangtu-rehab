import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../catalog/program_templates.dart';
import '../l10n/l10n.dart';
import '../models/progression.dart';
import '../models/workout.dart';
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
                if (fit.routines.isNotEmpty) ...[
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
            Text(t.weeklyPlan, style: AppTheme.f(12, weight: FontWeight.w600, color: gc.textSecondary, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            SoftCard(
              radius: 20,
              borderColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(children: [for (int i = 0; i < 7; i++) _dayRow(context, gc, i)]),
            ),
            const SizedBox(height: 26),
            Text(t.yourRoutines, style: AppTheme.f(12, weight: FontWeight.w600, color: gc.textSecondary, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            if (fit.routines.isEmpty)
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
    final planned = fit.routines.where((r) => [for (var d = 1; d <= 7; d++) ...fit.planIdsOn(d)].contains(r.id)).toList();
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
                sharePlan(planned.isEmpty ? fit.routines : [
                  ...planned,
                  ...fit.routines.where((r) => !planned.contains(r)),
                ], title: t.weeklyPlan);
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

  Widget _shareOption(GymColors gc, IconData icon, String title, String hint, VoidCallback onTap) {
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
          Icon(PhosphorIconsRegular.shareNetwork, size: 16, color: gc.textSecondary),
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

  Widget _dayRow(BuildContext context, GymColors gc, int i) {
    final weekday = fit.weekdayAt(i);
    final day = fit.dateForWeekday(i);
    final assigned = fit.routinesOn(day);
    final isToday = DateTime.now().weekday == weekday;
    return GestureDetector(
      onTap: () => _pickRoutine(context, weekday),
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
            Expanded(child: RoutineFolder(routine: list[i], onMenu: () => _routineMenu(context, list[i]))),
            const SizedBox(width: 12),
            Expanded(
              child: i + 1 < list.length
                  ? RoutineFolder(routine: list[i + 1], onMenu: () => _routineMenu(context, list[i + 1]))
                  : const SizedBox.shrink(),
            ),
          ]),
        ),
    ]);
  }

  void _routineMenu(BuildContext context, Routine r) {
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
              OptionItem(t.duplicateRoutine, icon: PhosphorIconsRegular.copy, onTap: () {
                Navigator.pop(sheet);
                fit.duplicateRoutine(r.id);
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

  void _pickRoutine(BuildContext context, int weekday) {
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
