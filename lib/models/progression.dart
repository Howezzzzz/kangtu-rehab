/// ── 命名/持久化边界（勿混，2026-10-24 并存后补记）──
/// 本文件含两套独立概念，共存但无关：
///  • PlanCycle（排期周期，见 models/plan_cycle.dart + FitState.planCycles，按 routineId）
///    ——「哪些天练」，与「练多重/多少组」无关。
///  • ProgKind.cycle + CycleSet（531 波浪周）——「每组次数×%TM 的周期表」，属渐进引擎。
/// Routine JSON 键：'p'=plan（目标组次）、'pr'=prog（ProgSpec 表）、'pi'=progInst。
/// FitState JSON 键：'progress'=进展步长、'progressRules'=上游规则、'progStates'=ProgState、'planCycles'=排期周期。
///
/// 自动渐进引擎的数据模型。
///
/// 四种渐进规则(参考公开训练方法论,原生实现):
/// - linear: 线性渐进 —— 全部达标次数 → 重量 +step;连续失败 failLimit 次 → 重量 ×deloadPct(降载)
/// - dbl:    双渐进 —— 次数在 [repMin, repMax] 区间逐次 +1,到顶后加重量、次数回落到 repMin
/// - cycle:  百分比周期 —— 按训练最大值(TM)的百分比排每周组次(531 式),整轮结束 TM +step
/// - reps:   纯次数递增(自重动作)—— 达标 → 目标次数 +1,到 repMax 提示换更难变式
enum ProgKind { linear, dbl, cycle, reps }

ProgKind progKindFrom(Object? raw) {
  final i = (raw as num?)?.toInt() ?? 0;
  return ProgKind.values[i.clamp(0, ProgKind.values.length - 1)];
}

/// 周期计划中的一组:次数 + 占训练最大值的百分比(0.65 = 65% TM)。
class CycleSet {
  const CycleSet(this.reps, this.pct);
  final int reps;
  final double pct;

  Map<String, dynamic> toJson() => {'r': reps, 'p': pct};
  factory CycleSet.fromJson(Map<String, dynamic> j) =>
      CycleSet((j['r'] as num).toInt(), (j['p'] as num).toDouble());
}

/// 单个动作的渐进规则(声明式,随 Routine 持久化)。
class ProgSpec {
  const ProgSpec({
    required this.kind,
    this.sets = 3,
    this.reps = 5,
    this.stepKg = 2.5,
    this.failLimit = 3,
    this.deloadPct = 0.9,
    this.repMin = 8,
    this.repMax = 12,
    this.weeks = const [],
  });

  final ProgKind kind;

  /// 工作组数(写进 plan 的组数)
  final int sets;

  /// linear 的每组目标次数
  final int reps;

  /// linear/dbl: 每次成功加的重量(kg);cycle: 每轮周期 TM 增量(kg)
  final double stepKg;

  /// linear: 连续失败多少次触发降载(0 = 不降载)
  final int failLimit;

  /// 降载系数(0.9 = 降到 90%)
  final double deloadPct;

  /// dbl/reps 的次数区间
  final int repMin;
  final int repMax;

  /// cycle: 每周的组次表(按周循环)
  final List<List<CycleSet>> weeks;

  bool get isCycle => kind == ProgKind.cycle && weeks.isNotEmpty;

  ProgSpec copyWith({
    ProgKind? kind,
    int? sets,
    int? reps,
    double? stepKg,
    int? failLimit,
    double? deloadPct,
    int? repMin,
    int? repMax,
    List<List<CycleSet>>? weeks,
  }) =>
      ProgSpec(
        kind: kind ?? this.kind,
        sets: sets ?? this.sets,
        reps: reps ?? this.reps,
        stepKg: stepKg ?? this.stepKg,
        failLimit: failLimit ?? this.failLimit,
        deloadPct: deloadPct ?? this.deloadPct,
        repMin: repMin ?? this.repMin,
        repMax: repMax ?? this.repMax,
        weeks: weeks ?? this.weeks,
      );

  Map<String, dynamic> toJson() => {
        'k': kind.index,
        if (sets != 3) 's': sets,
        if (reps != 5) 'r': reps,
        if (stepKg != 2.5) 'w': stepKg,
        if (failLimit != 3) 'f': failLimit,
        if (deloadPct != 0.9) 'd': deloadPct,
        if (kind == ProgKind.dbl || kind == ProgKind.reps) ...{'a': repMin, 'b': repMax},
        if (isCycle) 'c': [for (final w in weeks) [for (final s in w) s.toJson()]],
      };

  factory ProgSpec.fromJson(Map<String, dynamic> j) => ProgSpec(
        kind: progKindFrom(j['k']),
        sets: (j['s'] as num?)?.toInt() ?? 3,
        reps: (j['r'] as num?)?.toInt() ?? 5,
        stepKg: (j['w'] as num?)?.toDouble() ?? 2.5,
        failLimit: (j['f'] as num?)?.toInt() ?? 3,
        deloadPct: (j['d'] as num?)?.toDouble() ?? 0.9,
        repMin: (j['a'] as num?)?.toInt() ?? 8,
        repMax: (j['b'] as num?)?.toInt() ?? 12,
        weeks: ((j['c'] as List?) ?? const [])
            .map((w) => (w as List)
                .map((s) => CycleSet.fromJson((s as Map).cast<String, dynamic>()))
                .toList())
            .toList(),
      );
}

/// 一个「计划实例」的运行时状态。
/// 同一次应用模板生成的多个 Routine(如 531 的四个训练日)共享一个实例,
/// 周期周数、训练最大值、失败计数在实例级同步。
class ProgState {
  ProgState({this.tpl = '', this.week = 0, this.lastAdv = 0});

  /// 来源模板 id
  final String tpl;

  /// 周期计划的当前周序号(0 起)
  int week;

  /// 周期计划上一次推进周的毫秒时间戳(每 6 天推进一周)
  int lastAdv;

  /// 每个动作当前工作重量(kg;linear/dbl)
  final Map<String, double> w = {};

  /// 每个动作的训练最大值(kg;cycle)
  final Map<String, double> tm = {};

  /// 每个动作连续失败次数(linear)
  final Map<String, int> fails = {};

  /// 每个动作当前目标次数(dbl/reps)
  final Map<String, int> reps = {};

  /// 用户手动确认过训练最大值的动作（≠自动估算/默认）
  final Set<String> tmSet = {};

  Map<String, dynamic> toJson() => {
        't': tpl,
        if (week != 0) 'k': week,
        if (lastAdv != 0) 'v': lastAdv,
        if (w.isNotEmpty) 'w': w,
        if (tm.isNotEmpty) 'm': tm,
        if (fails.isNotEmpty) 'f': fails,
        if (reps.isNotEmpty) 'r': reps,
        if (tmSet.isNotEmpty) 'q': tmSet.toList(),
      };

  factory ProgState.fromJson(Map<String, dynamic> j) {
    final s = ProgState(
      tpl: j['t'] as String? ?? '',
      week: (j['k'] as num?)?.toInt() ?? 0,
      lastAdv: (j['v'] as num?)?.toInt() ?? 0,
    );
    s.w.addAll(((j['w'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, (v as num).toDouble())));
    s.tm.addAll(((j['m'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, (v as num).toDouble())));
    s.fails.addAll(((j['f'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, (v as num).toInt())));
    s.reps.addAll(((j['r'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, (v as num).toInt())));
    s.tmSet.addAll(((j['q'] as List?) ?? const []).whereType<String>());
    return s;
  }
}

/// 重量取整到 0.5kg
double roundHalf(double kg) => (kg * 2).roundToDouble() / 2;

enum ProgressKind { manual, linear, double, volume, amrap }

class ProgressRule {
  const ProgressRule({
    this.kind = ProgressKind.linear,
    this.low = 8,
    this.high = 12,
    this.sets = 3,
    this.maxSets = 5,
    this.fails = 3,
    this.deloadPct = 10,
  });

  final ProgressKind kind;
  final int low;
  final int high;
  final int sets;
  final int maxSets;
  final int fails;
  final int deloadPct;

  bool get usesRange => kind == ProgressKind.double || kind == ProgressKind.volume;

  ProgressRule copyWith({
    ProgressKind? kind,
    int? low,
    int? high,
    int? sets,
    int? maxSets,
    int? fails,
    int? deloadPct,
  }) {
    final lo = (low ?? this.low).clamp(1, 50);
    final hi = (high ?? this.high).clamp(lo + 1, 60);
    final base = (sets ?? this.sets).clamp(1, 10);
    return ProgressRule(
      kind: kind ?? this.kind,
      low: lo,
      high: hi,
      sets: base,
      maxSets: (maxSets ?? this.maxSets).clamp(base + 1, 12),
      fails: (fails ?? this.fails).clamp(1, 6),
      deloadPct: (deloadPct ?? this.deloadPct).clamp(5, 30),
    );
  }

  Map<String, dynamic> toJson() => {
        'k': kind.index,
        'lo': low,
        'hi': high,
        's': sets,
        'ms': maxSets,
        'f': fails,
        'd': deloadPct,
      };

  factory ProgressRule.fromJson(Map<String, dynamic> j) {
    final k = (j['k'] as num?)?.toInt() ?? 1;
    return const ProgressRule().copyWith(
      kind: ProgressKind.values[k.clamp(0, ProgressKind.values.length - 1)],
      low: (j['lo'] as num?)?.toInt(),
      high: (j['hi'] as num?)?.toInt(),
      sets: (j['s'] as num?)?.toInt(),
      maxSets: (j['ms'] as num?)?.toInt(),
      fails: (j['f'] as num?)?.toInt(),
      deloadPct: (j['d'] as num?)?.toInt(),
    );
  }
}

enum NextMove { up, reps, addSet, hold, deload }
