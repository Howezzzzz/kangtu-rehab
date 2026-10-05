/*
 * 康复档案列表 + 新建问诊表单 —— 纯本地。
 * 融合进 GymMane（GPLv3），随本体一同以 GPLv3 分发。
 */
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

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
    final gc = context.gc;
    final list = fit.rehabEpisodes;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(title: '康复档案', onBack: fit.backFromRehabEpisodes, titleSize: 22),
            const SizedBox(height: 16),
            SoftCard(
              radius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(PhosphorIconsRegular.shieldCheck, size: 18, color: gc.sage),
                    const SizedBox(width: 10),
                    Text('本地保存 · 不上传',
                        style: AppTheme.f(12, weight: FontWeight.w700, color: gc.sage, letterSpacing: 1.2)),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    '一个困扰 = 一个档案。填一次问诊信息，先过「安全门」筛查，'
                    '再让通用智能助手给出康复建议（复制提示词 → 贴给它 → 粘回套用），'
                    '计划、注意事项和备注都会留在这个档案里。',
                    style: AppTheme.f(13, weight: FontWeight.w500, color: gc.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: '新建康复档案', onTap: fit.newRehabEpisode),
            const SizedBox(height: 18),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 26),
                child: Text('还没有档案。比如「腰疼」「肩痛」都可以开一个。',
                    textAlign: TextAlign.center,
                    style: AppTheme.f(13, weight: FontWeight.w500, color: gc.textTertiary)),
              ),
            for (final ep in list) ...[
              _EpisodeCard(ep: ep),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
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
                child: Text(safe ? '已通过安全门' : '建议先就医',
                    style: AppTheme.f(10.5, weight: FontWeight.w700, color: color)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(
              '${rehabAreaLabel(ep.area)} · ${rehabDurationLabel(ep.duration)} · 不适 ${ep.pain}/10'
              ' · 计划 ${ep.routineIds.length} 个',
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
            ScreenHeader(title: '新建康复档案', onBack: fit.backFromRehabNew, titleSize: 22),
            const SizedBox(height: 16),
            _label(gc, '哪里不舒服'),
            _chips<String>(
              gc,
              kRehabAreas,
              {_area},
              false,
              (k) => setState(() => _area = k),
            ),
            const SizedBox(height: 18),
            _label(gc, '多久了'),
            _chips<String>(gc, kRehabDurations, {_duration}, false, (k) => setState(() => _duration = k)),
            const SizedBox(height: 18),
            _label(gc, '现在的不适程度：$_pain / 10'),
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
            _label(gc, '有没有下列情况（有就勾上，我们只做筛查不做诊断）'),
            for (final e in kRehabRedFlags.entries)
              _checkRow(gc, e.value, _flags.contains(e.key), () {
                setState(() => _flags.contains(e.key) ? _flags.remove(e.key) : _flags.add(e.key));
              }, warn: true),
            const SizedBox(height: 18),
            _label(gc, '什么情况会加重 / 缓解'),
            _text(gc, _factors, '例如：久坐后加重，躺下缓解；弯腰取物时疼'),
            const SizedBox(height: 18),
            _label(gc, '康复目标'),
            _chips<String>(gc, kRehabGoals, _goals, true, (k) => setState(() {
                  _goals.contains(k) ? _goals.remove(k) : _goals.add(k);
                })),
            const SizedBox(height: 18),
            _label(gc, '有什么器材'),
            _chips<String>(gc, {for (final g in _kWearableGear) g: g}, _gear, true, (k) => setState(() {
                  _gear.contains(k) ? _gear.remove(k) : _gear.add(k);
                })),
            const SizedBox(height: 18),
            _label(gc, '每周能练几天：$_days'),
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
            PrimaryButton(label: '保存并检查安全门', onTap: _save),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final ep = RehabEpisode(
      id: 're${DateTime.now().millisecondsSinceEpoch}',
      title: '${rehabAreaLabel(_area)}康复',
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
        title: '安全门未通过',
        body: '勾选的这些情况建议先找医生或康复治疗师当面评估。\n\n'
            '档案已保存，可以做记录、存医生建议，但本 App 不再提供训练建议。',
        confirmLabel: '知道了',
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
