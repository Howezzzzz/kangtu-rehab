/*
 * 「康复」模块界面 —— 12 周腰痛康复手册（离线）。
 * 设计沿用 GymMane 的组件与配色（AppTheme / GymColors / ui_kit）。
 * 合并进 GymMane（GPLv3），随本体一同以 GPLv3 分发。
 */
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/rehab_data.dart';
import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import '../l10n/l10n.dart';

const _kLogKey = 'rehab_log_v1';

class RehabScreen extends StatefulWidget {
  const RehabScreen({super.key});

  @override
  State<RehabScreen> createState() => _RehabScreenState();
}

class _RehabScreenState extends State<RehabScreen> {
  int _tab = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    RehabData.load().whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final labels = [t.rehabTabToday, t.rehabTabPlan, t.rehabTabLog, t.rehabTabBook];
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: t.rehabBookTitle,
              onBack: fit.backFromRehabBook,
              titleSize: 22,
              subtitle: RehabData.meta()['subtitle']?.toString(),
            ),
            const SizedBox(height: 16),
            SegToggle([
              for (var i = 0; i < labels.length; i++)
                SegOption(labels[i], _tab == i, () => setState(() => _tab = i)),
            ], fontSize: 11.5, hPad: 10),
            const SizedBox(height: 18),
            switch (_tab) {
              0 => const _TodaySection(),
              1 => const _PlanSection(),
              2 => const _LogSection(),
              _ => const _BookSection(),
            },
            const SizedBox(height: 20),
            Text(
              RehabData.meta()['disclaimer']?.toString() ?? '',
              textAlign: TextAlign.center,
              style: AppTheme.f(11, weight: FontWeight.w500, color: gc.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 共用小组件
// ---------------------------------------------------------------------------

class _SectionHead extends StatelessWidget {
  const _SectionHead(this.no, this.title, {this.sub});
  final String no;
  final String title;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(no,
              style: AppTheme.f(12,
                  weight: FontWeight.w800, color: gc.ember, letterSpacing: 1)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.f(16, weight: FontWeight.w800, color: gc.text)),
                if (sub != null)
                  Text(sub!,
                      style: AppTheme.f(11.5, weight: FontWeight.w500, color: gc.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 渲染内容里带 <b> 的内联富文本（极简：粗体分段）。
class _Rich extends StatelessWidget {
  const _Rich(this.text, {this.size = 13, this.color});
  final String text;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final parts = text.split(RegExp(r'</?b>'));
    return RichText(
      text: TextSpan(
        style: AppTheme.f(size, weight: FontWeight.w500, color: color ?? gc.textSecondary, height: 1.5),
        children: [
          for (var i = 0; i < parts.length; i++)
            TextSpan(
              text: parts[i].replaceAll(RegExp(r'<[^>]+>'), ''),
              style: i.isOdd
                  ? AppTheme.f(size, weight: FontWeight.w800, color: color ?? gc.text)
                  : null,
            ),
        ],
      ),
    );
  }
}

Widget _rehabImg(String rel, {double? height}) {
  final p = RehabData.imgPath(rel);
  if (p.isEmpty) return const SizedBox.shrink();
  return ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Image.asset(p, fit: BoxFit.contain, height: height,
        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final c = color ?? gc.textSecondary;
    return Container(
      margin: const EdgeInsets.only(right: 6, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: AppTheme.f(11, weight: FontWeight.w700, color: c)),
    );
  }
}

// ---------------------------------------------------------------------------
// 今天
// ---------------------------------------------------------------------------

class _TodaySection extends StatelessWidget {
  const _TodaySection();

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final meta = RehabData.meta();
    final story = RehabData.a('story');
    final stats = meta['stats'] is List ? meta['stats'] as List : const [];
    final paused = meta['paused'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (paused)
          SoftCard(
            color: gc.warn.withValues(alpha: 0.12),
            borderColor: gc.warn.withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${meta['pauseTitle'] ?? '计划暂停中'} · ${meta['pauseDate'] ?? ''}',
                    style: AppTheme.f(14, weight: FontWeight.w800, color: gc.warn)),
                const SizedBox(height: 6),
                _Rich(meta['pauseText']?.toString() ?? '', size: 12.5),
              ],
            ),
          ),
        if (paused) const SizedBox(height: 12),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.rehabHandTarget, style: AppTheme.f(14, weight: FontWeight.w800, color: gc.text)),
              const SizedBox(height: 4),
              _Rich(meta['target']?.toString() ?? ''),
              const Divider(height: 22),
              Text(t.rehabHandGoal, style: AppTheme.f(14, weight: FontWeight.w800, color: gc.text)),
              const SizedBox(height: 4),
              _Rich(meta['goals']?.toString() ?? ''),
              const Divider(height: 22),
              Text(t.rehabHandPrinciple, style: AppTheme.f(14, weight: FontWeight.w800, color: gc.text)),
              const SizedBox(height: 4),
              _Rich(meta['principle']?.toString() ?? ''),
            ],
          ),
        ),
        if (stats.isNotEmpty) ...[
          const SizedBox(height: 12),
          SoftCard(
            child: Row(
              children: [
                for (final s in stats)
                  Expanded(
                    child: Column(
                      children: [
                        Text('${(s as Map)['n'] ?? ''}',
                            style: AppTheme.f(22, weight: FontWeight.w800, color: gc.ember)),
                        const SizedBox(height: 2),
                        Text('${s['l'] ?? ''}',
                            style: AppTheme.f(11, weight: FontWeight.w500, color: gc.textSecondary)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (story.isNotEmpty) ...[
          _SectionHead('01', t.rehabHandTimeline, sub: t.rehabHandTimelineSub),
          SoftCard(
            child: Column(
              children: [
                for (var i = 0; i < story.length; i++)
                  _storyRow(context, story[i] as Map, i == story.length - 1),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _storyRow(BuildContext context, Map s, bool last) {
    final gc = context.gc;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: gc.ember, shape: BoxShape.circle),
              ),
              if (!last)
                Expanded(child: Container(width: 2, color: gc.ember.withValues(alpha: 0.25))),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${s['when'] ?? ''}',
                      style: AppTheme.f(11, weight: FontWeight.w700, color: gc.textSecondary)),
                  Text('${s['t'] ?? ''}',
                      style: AppTheme.f(13.5, weight: FontWeight.w800, color: gc.text)),
                  if ('${s['d'] ?? ''}'.isNotEmpty)
                    Text('${s['d']}',
                        style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 课表
// ---------------------------------------------------------------------------

class _PlanSection extends StatelessWidget {
  const _PlanSection();

  static String _short(String iso) {
    final p = iso.split('-');
    if (p.length != 3) return iso;
    return '${int.tryParse(p[1]) ?? p[1]}/${int.tryParse(p[2]) ?? p[2]}';
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final phases = RehabData.a('phases');
    final trainDays = RehabData.o('trainDays');
    final evalDays = RehabData.a('evalDays');
    final sessions = RehabData.a('sessions');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHead('02', t.rehabHandSchedule, sub: t.rehabHandScheduleSub),
        for (final p in phases) ...[
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${(p as Map)['stage'] ?? ''}',
                    style: AppTheme.f(14, weight: FontWeight.w800, color: gc.text)),
                const SizedBox(height: 4),
                Text('${p['dose'] ?? ''}',
                    style: AppTheme.f(11.5, weight: FontWeight.w600, color: gc.ember)),
                const SizedBox(height: 6),
                _Rich('${p['desc'] ?? ''}', size: 12.5),
                if ((trainDays['${p['c']}'] is List)) ...[
                  const SizedBox(height: 10),
                  Wrap(children: [
                    for (final d in (trainDays['${p['c']}'] as List))
                      _Chip(_short('$d'),
                          color: evalDays.contains(d) ? gc.ember : gc.textSecondary),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        _SectionHead('03', t.rehabHandPhaseDetail, sub: t.rehabHandExpand),
        for (final s in sessions) ...[
          _sessionCard(context, s as Map),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _sessionCard(BuildContext context, Map s) {
    final gc = context.gc;
    final cols = s['cols'] is List ? s['cols'] as List : const [];
    final rows = s['rows'] is List ? s['rows'] as List : const [];
    return SoftCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          iconColor: gc.textSecondary,
          collapsedIconColor: gc.textSecondary,
          title: Text('${t.rehabLogStage('${s['phase']}')} · ${s['title'] ?? ''}',
              style: AppTheme.f(13.5, weight: FontWeight.w800, color: gc.text)),
          subtitle: Text('${s['range'] ?? ''} · ${s['meta'] ?? ''}',
              style: AppTheme.f(11, weight: FontWeight.w500, color: gc.textSecondary)),
          children: [
            if ('${s['dayLabel'] ?? ''}'.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text('${s['dayLabel']}：${s['dayNote'] ?? ''}',
                    style: AppTheme.f(11.5, weight: FontWeight.w600, color: gc.ember)),
              ),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < cols.length; i++)
                      Expanded(
                        flex: i == 1 ? 3 : 2,
                        child: Text('${(r as List)[i] ?? ''}',
                            style: AppTheme.f(11.5,
                                weight: i == 0 ? FontWeight.w800 : FontWeight.w500,
                                color: i == 0 ? gc.ember : gc.textSecondary)),
                      ),
                  ],
                ),
              ),
            if ('${s['note'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(alignment: Alignment.centerLeft, child: _Rich('${s['note']}', size: 11.5)),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 日志（本地存储）
// ---------------------------------------------------------------------------

class _LogSection extends StatefulWidget {
  const _LogSection();

  @override
  State<_LogSection> createState() => _LogSectionState();
}

class _LogSectionState extends State<_LogSection> {
  List<Map<String, dynamic>> _entries = [];
  final _feel = TextEditingController();
  String _light = 'g';
  int _phase = 1;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _feel.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLogKey);
    var list = <Map<String, dynamic>>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is List) {
          list = d.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _entries = list);
  }

  Future<void> _save() async {
    final e = <String, dynamic>{
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'phase': _phase,
      'light': _light,
      'feel': _feel.text.trim(),
    };
    setState(() {
      _entries.insert(0, e);
      _feel.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLogKey, jsonEncode(_entries));
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHead('08', t.rehabHandTraffic, sub: t.rehabHandTrafficSub),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 6, children: [
                for (final ph in const [0, 1, 2, 3, 4])
                  _Chip(ph == 4 ? t.rehabHandMaintain : t.rehabPhaseN('$ph'),
                      color: _phase == ph ? gc.ember : gc.textTertiary),
              ]),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {},
                child: Row(children: [
                  for (final l in const ['g', 'y', 'r'])
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _light = l),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: _light == l ? gc.ember : gc.mutedFill,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(_lightLabel(l),
                                style: AppTheme.f(12,
                                    weight: FontWeight.w800,
                                    color: _light == l ? gc.onEmber : gc.textSecondary)),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _feel,
                maxLines: 2,
                style: AppTheme.f(13, weight: FontWeight.w500, color: gc.text),
                decoration: InputDecoration(
                  hintText: t.rehabHandFeel,
                  hintStyle: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textTertiary),
                  filled: true,
                  fillColor: gc.mutedFill,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(label: t.rehabHandSaveLog, onTap: _save),
              ),
            ],
          ),
        ),
        _SectionHead('09', t.rehabHandHistory,
            sub: _entries.isEmpty ? t.rehabHandNoLog : t.rehabLogCount(_entries.length)),
        for (var i = 0; i < _entries.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SoftCard(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: _lightColor(_entries[i]['light']?.toString()), shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_entries[i]['date']} · ${t.rehabLogStage('${_entries[i]['phase']}')} · ${_lightLabel('${_entries[i]['light']}')}'
                    '${'${_entries[i]['feel'] ?? ''}'.isEmpty ? '' : ' · ${_entries[i]['feel']}'}',
                    style: AppTheme.f(12, weight: FontWeight.w600, color: gc.text),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    setState(() => _entries.removeAt(i));
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(_kLogKey, jsonEncode(_entries));
                  },
                  child: Text(t.rehabHandDelete, style: AppTheme.f(12, weight: FontWeight.w700, color: gc.danger)),
                ),
              ]),
            ),
          ),
      ],
    );
  }

  String _lightLabel(String c) => c == 'g' ? t.rehabHandTrafficGreen : (c == 'y' ? t.rehabHandTrafficYellow : t.rehabHandTrafficRed);

  Color _lightColor(String? c) {
    final gc = context.gc;
    return c == 'g' ? gc.sage : (c == 'y' ? gc.warn : gc.danger);
  }
}

// ---------------------------------------------------------------------------
// 手册
// ---------------------------------------------------------------------------

class _BookSection extends StatelessWidget {
  const _BookSection();

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final mustread = RehabData.o('mustread');
    final baseline = RehabData.o('baseline');
    final daily = RehabData.o('daily');
    final monitor = RehabData.o('monitor');
    final faq = RehabData.a('faq');
    final muscles = RehabData.o('muscles');
    final lights = mustread['lights'] is List ? mustread['lights'] as List : const [];
    final steps = baseline['steps'] is List ? baseline['steps'] as List : const [];
    final cards = daily['cards'] is List ? daily['cards'] as List : const [];
    final weekly = monitor['weekly'] is List ? monitor['weekly'] as List : const [];
    final verdicts = monitor['verdicts'] is List ? monitor['verdicts'] as List : const [];
    final rows = muscles['rows'] is List ? muscles['rows'] as List : const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHead('10', '${mustread['title'] ?? '训练前必读'}'),
        SoftCard(child: _Rich('${mustread['lead'] ?? ''}', size: 12.5)),
        const SizedBox(height: 10),
        for (final l in lights) ...[
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${(l as Map)['t'] ?? ''}',
                    style: AppTheme.f(13, weight: FontWeight.w800, color: gc.text)),
                const SizedBox(height: 3),
                _Rich('${l['d'] ?? ''}', size: 12.5),
                const SizedBox(height: 3),
                Text('${l['a'] ?? ''}',
                    style: AppTheme.f(11.5, weight: FontWeight.w700, color: gc.ember)),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        _SectionHead('11', '${baseline['title'] ?? ''}'),
        for (final s in steps) ...[
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${(s as Map)['n'] ?? ''} ${s['h'] ?? ''}',
                    style: AppTheme.f(13, weight: FontWeight.w800, color: gc.text)),
                if (s['items'] is List)
                  for (final it in (s['items'] as List))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _Rich('· $it', size: 12.5),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        _SectionHead('12', '${daily['title'] ?? ''}'),
        for (final c in cards) ...[
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${(c as Map)['h'] ?? ''}',
                    style: AppTheme.f(13, weight: FontWeight.w800, color: gc.text)),
                const SizedBox(height: 8),
                _rehabImg('${c['img'] ?? ''}'),
                const SizedBox(height: 8),
                _Rich('${c['text'] ?? ''}', size: 12.5),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        _SectionHead('13', '${monitor['title'] ?? ''}'),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${monitor['weeklyTitle'] ?? ''}',
                  style: AppTheme.f(13, weight: FontWeight.w800, color: gc.text)),
              const SizedBox(height: 6),
              for (final q in weekly)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('· $q',
                      style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textSecondary)),
                ),
              const Divider(height: 20),
              for (final v in verdicts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: _Rich(
                      '<b>${(v as List)[1]}</b> — ${(v)[2]}',
                      size: 12.5),
                ),
            ],
          ),
        ),
        _SectionHead('14', t.rehabHandFaq),
        for (final f in faq) ...[
          SoftCard(
            padding: EdgeInsets.zero,
            clip: true,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                iconColor: gc.textSecondary,
                collapsedIconColor: gc.textSecondary,
                title: Text('${(f as List)[0]}',
                    style: AppTheme.f(12.5, weight: FontWeight.w700, color: gc.text)),
                children: [
                  Align(alignment: Alignment.centerLeft, child: _Rich('${f[1]}', size: 12.5)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        _SectionHead('15', '${muscles['title'] ?? ''}'),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${(r as List)[0]}',
                          style: AppTheme.f(12.5, weight: FontWeight.w800, color: gc.ember)),
                      const SizedBox(height: 3),
                      _Rich('${r[1]}', size: 12.5),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
