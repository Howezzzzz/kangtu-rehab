/*
 * 康复档案列表 + 新建问诊表单 —— 纯本地。
 * 融合进 GymMane（GPLv3），随本体一同以 GPLv3 分发。
 */
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../l10n/l10n.dart';
import '../models/rehab_episode.dart';
import '../services/rehab_intake.dart';
import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/ui_kit.dart';

const _kWearableGear = [
  'Bodyweight', 'Band', 'Dumbbell', 'Barbell', 'Kettlebell', 'Machine', 'Cable', 'Rings', 'Other'
];

class RehabEpisodesScreen extends StatelessWidget {
  const RehabEpisodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(title: t.rehabArchiveTitle, onBack: fit.backFromRehabEpisodes, titleSize: 22),
            const SizedBox(height: 16),
            const RehabEpisodesBody(),
          ],
        ),
      ),
    );
  }
}

/// 康复档案主体（介绍 + 新建 + 列表）——「康复」模块首页与档案页共用。
class RehabEpisodesBody extends StatelessWidget {
  const RehabEpisodesBody({super.key});

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final list = fit.rehabEpisodes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoftCard(
              radius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(PhosphorIconsRegular.shieldCheck, size: 18, color: gc.sage),
                    const SizedBox(width: 10),
                    Text(t.rehabKeepLocal,
                        style: AppTheme.f(12, weight: FontWeight.w700, color: gc.sage, letterSpacing: 1.2)),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    t.rehabIntro,
                    style: AppTheme.f(13, weight: FontWeight.w500, color: gc.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: t.rehabNew, onTap: fit.newRehabEpisode),
            const SizedBox(height: 18),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 26),
                child: Text(t.rehabEmpty,
                    textAlign: TextAlign.center,
                    style: AppTheme.f(13, weight: FontWeight.w500, color: gc.textTertiary)),
              ),
            for (final ep in list) ...[
              _EpisodeCard(ep: ep),
              const SizedBox(height: 10),
            ],
      ],
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({required this.ep});
  final RehabEpisode ep;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final safe = ep.safe;
    final color = safe ? gc.sage : gc.danger;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => fit.openRehabEpisode(ep.id),
      child: SoftCard(
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(ep.title,
                    style: AppTheme.f(15.5, weight: FontWeight.w800, color: gc.text)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(100)),
                child: Text(safe ? t.rehabSafePass : t.rehabSeeDoctor,
                    style: AppTheme.f(10.5, weight: FontWeight.w700, color: color)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(
              t.rehabEpisodeMeta(rehabAreaLabel(ep.area), rehabDurationLabel(ep.duration), ep.pain,
                  ep.routineIds.length),
              style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 新建问诊
// ---------------------------------------------------------------------------

class RehabNewEpisodeScreen extends StatefulWidget {
  const RehabNewEpisodeScreen({super.key});

  @override
  State<RehabNewEpisodeScreen> createState() => _RehabNewEpisodeScreenState();
}

class _RehabNewEpisodeScreenState extends State<RehabNewEpisodeScreen> {
  String _area = 'lowback';
  String _duration = 'sub';
  int _pain = 3;
  final Set<String> _flags = {};
  final TextEditingController _factors = TextEditingController();
  final Set<String> _goals = {'pain'};
  final Set<String> _gear = {'Bodyweight'};
  int _days = 3;

  @override
  void dispose() {
    _factors.dispose();
    super.dispose();
  }

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
            ScreenHeader(title: t.rehabNew, onBack: fit.backFromRehabNew, titleSize: 22),
            const SizedBox(height: 16),
            _label(gc, t.rehabLabelArea),
            _chips<String>(
              gc,
              {for (final k in kRehabAreaIds) k: t.rehabArea(k)},
              {_area},
              false,
              (k) => setState(() => _area = k),
            ),
            const SizedBox(height: 18),
            _label(gc, t.rehabLabelDuration),
            _chips<String>(gc, {for (final k in kRehabDurationIds) k: t.rehabDuration(k)}, {_duration}, false,
                (k) => setState(() => _duration = k)),
            const SizedBox(height: 18),
            _label(gc, t.rehabPainNow(_pain)),
            Slider(
              value: _pain.toDouble(),
              min: 0,
              max: 10,
              divisions: 10,
              activeColor: gc.ember,
              label: '$_pain',
              onChanged: (v) => setState(() => _pain = v.round()),
            ),
            const SizedBox(height: 10),
            _label(gc, t.rehabLabelRedFlags),
            for (final id in kRehabRedFlagIds)
              _checkRow(gc, t.rehabRedFlag(id), _flags.contains(id), () {
                setState(() => _flags.contains(id) ? _flags.remove(id) : _flags.add(id));
              }, warn: true),
            const SizedBox(height: 18),
            _label(gc, t.rehabLabelFactors),
            _text(gc, _factors, t.rehabFactorsHint),
            const SizedBox(height: 18),
            _label(gc, t.rehabLabelGoals),
            _chips<String>(gc, {for (final k in kRehabGoalIds) k: t.rehabGoal(k)}, _goals, true, (k) => setState(() {
                  _goals.contains(k) ? _goals.remove(k) : _goals.add(k);
                })),
            const SizedBox(height: 18),
            _label(gc, t.rehabLabelGear),
            _chips<String>(gc, {for (final g in _kWearableGear) g: t.equipment(g)}, _gear, true, (k) => setState(() {
                  _gear.contains(k) ? _gear.remove(k) : _gear.add(k);
                })),
            const SizedBox(height: 18),
            _label(gc, t.rehabLabelDays(_days)),
            Row(children: [
              for (final d in [2, 3, 4, 5, 6])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _days = d),
                    child: Container(
                      width: 40,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _days == d ? gc.ember : gc.bgRaised,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('$d',
                          style: AppTheme.f(13.5,
                              weight: FontWeight.w700, color: _days == d ? gc.onEmber : gc.text)),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 24),
            PrimaryButton(label: t.rehabSaveGate, onTap: _save),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final ep = RehabEpisode(
      id: 're${DateTime.now().millisecondsSinceEpoch}',
      title: t.rehabAutoTitle(rehabAreaLabel(_area)),
      createdAt: DateTime.now(),
      area: _area,
      duration: _duration,
      pain: _pain,
      redFlags: _flags.toList(),
      factors: _factors.text.trim(),
      goals: _goals.toList(),
      equipment: _gear.toList(),
      daysPerWeek: _days,
    );
    fit.createEpisode(ep);
    if (!mounted) return;
    if (!ep.safe) {
      await askConfirm(
        context,
        title: t.rehabGateFailTitle,
        body: t.rehabGateFailBody,
        confirmLabel: t.rehabOk,
      );
    }
    if (!mounted) return;
    fit.openRehabEpisode(ep.id);
  }

  Widget _label(GymColors gc, String s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(s, style: AppTheme.f(13, weight: FontWeight.w700, color: gc.text)),
      );

  Widget _text(GymColors gc, TextEditingController c, String hint) => TextField(
        controller: c,
        minLines: 2,
        maxLines: 4,
        style: AppTheme.f(13, weight: FontWeight.w500, color: gc.text),
        cursorColor: gc.ember,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textTertiary),
          filled: true,
          fillColor: gc.bgRaised,
          contentPadding: const EdgeInsets.all(14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
      );

  Widget _chips<K>(GymColors gc, Map<K, String> map, Set<K> sel, bool multi, void Function(K) tap) {
    final entries = map.entries.toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in entries)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => tap(e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: sel.contains(e.key) ? gc.ember : gc.bgRaised,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(e.value,
                  style: AppTheme.f(12.5,
                      weight: FontWeight.w600,
                      color: sel.contains(e.key) ? gc.onEmber : gc.text)),
            ),
          ),
      ],
    );
  }

  Widget _checkRow(GymColors gc, String text, bool on, VoidCallback tap, {bool warn = false}) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? (warn ? gc.danger : gc.ember) : Colors.transparent,
                border: Border.all(color: on ? Colors.transparent : gc.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: on ? Icon(PhosphorIconsRegular.check, size: 12, color: gc.onEmber) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.text, height: 1.35)),
            ),
          ]),
        ),
      );
}
