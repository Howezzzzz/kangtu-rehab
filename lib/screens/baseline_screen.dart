/*
 * 自测基线（Baseline Self-Test）—— 先测身体基础值，再据此给训练计划定起始强度。
 * v1：普通档 6 项、零器械；安全闸（PAR-Q+ 简版）前置；只存绝对值与趋势，不做优劣判定。
 * 免责：非医疗诊断。融合进 GymMane（GPLv3），随本体一同以 GPLv3 分发。
 */
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/baseline.dart';
import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import '../widgets/ui_kit.dart';

class BaselineScreen extends StatefulWidget {
  const BaselineScreen({super.key});

  @override
  State<BaselineScreen> createState() => _BaselineScreenState();
}

class _BaselineScreenState extends State<BaselineScreen> {
  final List<bool> _gate = [false, false, false, false];
  final Map<String, TextEditingController> _c = {
    for (final d in kBaselineFitness) d.code: TextEditingController(),
  };

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _gateOk => !_gate.any((e) => e);

  List<String> get _gateQ =>
      [t.baselineGateQ1, t.baselineGateQ2, t.baselineGateQ3, t.baselineGateQ4];

  List<BaselineItem> _collect() {
    final out = <BaselineItem>[];
    for (final d in kBaselineFitness) {
      final v = double.tryParse(_c[d.code]!.text.trim());
      if (v != null && v.isFinite && v >= d.min && v <= d.max) out.add(BaselineItem(d.code, v));
    }
    return out;
  }

  void _save() {
    final items = _collect();
    if (items.isEmpty) return;
    fit.saveBaseline(BaselineSession(
      id: 'b${DateTime.now().microsecondsSinceEpoch}',
      date: DateTime.now(),
      items: items,
    ));
    for (final c in _c.values) {
      c.clear();
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.baselineSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final last = fit.latestBaseline;
    final prev = fit.previousBaseline;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: t.baselineTitle,
              onBack: fit.backFromBaseline,
              titleSize: 22,
              subtitle: t.baselineSubtitle,
            ),
            const SizedBox(height: 16),
            // —— 安全闸（PAR-Q+ 简版）
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.baselineGateTitle,
                      style: AppTheme.f(15, weight: FontWeight.w800, color: gc.text)),
                  const SizedBox(height: 6),
                  for (var i = 0; i < _gateQ.length; i++)
                    Pressable(
                      onTap: () => setState(() => _gate[i] = !_gate[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(_gateQ[i],
                                  style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.text)),
                            ),
                            const SizedBox(width: 10),
                            TinySwitch(on: _gate[i]),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!_gateOk)
              SoftCard(
                child: Text(t.baselineGateFail,
                    style: AppTheme.f(12.5, weight: FontWeight.w600, color: gc.danger)),
              )
            else ...[
              for (final d in kBaselineFitness) _itemRow(gc, d, last, prev),
              const SizedBox(height: 4),
              Text(t.baselineDisclaimer,
                  style: AppTheme.f(11, weight: FontWeight.w500, color: gc.textTertiary)),
              const SizedBox(height: 12),
              PrimaryButton(label: t.baselineSave, onTap: _save),
            ],
            if (last != null) ...[
              const SizedBox(height: 24),
              _history(gc, last, prev),
            ],
          ],
        ),
      ),
    );
  }

  Widget _itemRow(GymColors gc, BaselineDef d, BaselineSession? last, BaselineSession? prev) {
    final lastV = last?.value(d.code);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_name(d.code),
                      style: AppTheme.f(14, weight: FontWeight.w700, color: gc.text)),
                ),
                if (lastV != null)
                  Text('${t.baselineLast}: ${_fmt(lastV)} ${d.unit}',
                      style: AppTheme.f(11.5, weight: FontWeight.w600, color: gc.textTertiary)),
              ],
            ),
            const SizedBox(height: 3),
            Text(_how(d.code),
                style: AppTheme.f(11.5, weight: FontWeight.w500, color: gc.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: _c[d.code],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppTheme.f(15, weight: FontWeight.w700, color: gc.text),
              decoration: InputDecoration(
                hintText: t.baselineInputHint,
                hintStyle: AppTheme.f(13, weight: FontWeight.w500, color: gc.textTertiary),
                suffixText: d.unit,
                filled: true,
                fillColor: gc.mutedFill,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _history(GymColors gc, BaselineSession last, BaselineSession? prev) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.baselineResultTitle.toUpperCase(),
            style: AppTheme.f(10.5, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.4)),
        const SizedBox(height: 10),
        for (final d in kBaselineFitness)
          Builder(builder: (_) {
            final series = [
              for (final b in fit.baselines)
                if (b.value(d.code) != null) b.value(d.code)!.toDouble(),
            ];
            final now = last.value(d.code);
            if (now == null) return const SizedBox.shrink();
            final was = prev?.value(d.code);
            final delta = was == null ? null : now - was;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(_name(d.code),
                              style: AppTheme.f(13, weight: FontWeight.w700, color: gc.text)),
                        ),
                        Text('${_fmt(now)} ${d.unit}',
                            style: AppTheme.f(14, weight: FontWeight.w800, color: gc.ember)),
                        if (delta != null && delta != 0) ...[
                          const SizedBox(width: 8),
                          Text('${delta > 0 ? '+' : ''}${_fmt(delta)}',
                              style: AppTheme.f(12,
                                  weight: FontWeight.w700,
                                  color: (delta > 0) == d.higherIsBetter ? gc.sage : gc.warn)),
                        ],
                      ],
                    ),
                    if (series.length >= 2) ...[
                      const SizedBox(height: 6),
                      Sparkline(values: series, height: 36, color: gc.ember),
                    ],
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 6),
        Text(t.baselineDisclaimer,
            style: AppTheme.f(11, weight: FontWeight.w500, color: gc.textTertiary)),
      ],
    );
  }

  String _name(String code) => switch (code) {
        'resting_hr' => t.baselineNmRestingHr,
        'step_2min' => t.baselineNmStep2,
        'chair_stand_30' => t.baselineNmChairStand,
        'single_leg_stand' => t.baselineNmSingleLeg,
        'sit_reach' => t.baselineNmSitReach,
        _ => t.baselineNmWaist,
      };

  String _how(String code) => switch (code) {
        'resting_hr' => t.baselineHowRestingHr,
        'step_2min' => t.baselineHowStep2,
        'chair_stand_30' => t.baselineHowChairStand,
        'single_leg_stand' => t.baselineHowSingleLeg,
        'sit_reach' => t.baselineHowSitReach,
        _ => t.baselineHowWaist,
      };

  String _fmt(double v) => !v.isFinite
      ? '—'
      : (v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1));
}
