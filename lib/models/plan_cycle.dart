/// 排期周期（Plan Cycle）—— 把训练计划从"每周固定周几"升级为"一个完整时间周期"。
/// 语义：起始日 + 总周数 + 每周次数（或钉死某几天）；App 自动均摊排训练日。
/// 纯数据 + 纯函数，无副作用；`weeklyPlan` 旧模式保留不动（无 cycle 字段 = 旧无限模式，零迁移）。
class PlanCycle {
  PlanCycle({
    required this.start,
    required this.weeks,
    required this.perWeek,
    this.pinnedDays = const [],
    this.round = 1,
  });

  final DateTime start; // 起始日（本地日历日，00:00 归一）
  final int weeks; // 总周期（周）
  final int perWeek; // 每周次数（pinnedDays 非空时忽略）
  final List<int> pinnedDays; // 钉死周几 1..7（可选）
  final int round; // 第几轮（续轮 +1）

  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  int get totalDays => weeks * 7;
  DateTime get endExclusive => start.add(Duration(days: totalDays)); // 到期日（不含）

  /// 每周训练日（1..7）。有钉日就用钉日，否则按 N 均摊。
  List<int> get weekdays => pinnedDays.isNotEmpty ? pinnedDays : evenlySpread(perWeek);

  static List<int> evenlySpread(int n) {
    final c = n.clamp(1, 7);
    final out = <int>[];
    for (var i = 0; i < c; i++) {
      final d = 1 + ((i * 7) ~/ c);
      if (!out.contains(d)) out.add(d);
    }
    return out;
  }

  bool coversDay(DateTime day) {
    final d = dayOnly(day);
    return !d.isBefore(start) && d.isBefore(endExclusive);
  }

  bool isTrainingDay(DateTime day) => coversDay(day) && weekdays.contains(day.weekday);

  /// 第几周（1 起）；不在周期内返回 null。
  int? weekIndex(DateTime day) {
    if (!coversDay(day)) return null;
    return (dayOnly(day).difference(start).inDays ~/ 7) + 1;
  }

  bool get expired => DateTime.now().isAfter(endExclusive.subtract(const Duration(days: 1)));

  PlanCycle nextRound() => PlanCycle(
        start: endExclusive,
        weeks: weeks,
        perWeek: perWeek,
        pinnedDays: pinnedDays,
        round: round + 1,
      );

  Map<String, dynamic> toJson() => {
        'start': start.toIso8601String(),
        'weeks': weeks,
        'perWeek': perWeek,
        if (pinnedDays.isNotEmpty) 'pinned': pinnedDays,
        'round': round,
      };

  factory PlanCycle.fromJson(Map<String, dynamic> j) => PlanCycle(
        start: dayOnly(DateTime.tryParse(j['start'] as String? ?? '') ?? DateTime.now()),
        weeks: ((j['weeks'] as num?)?.toInt() ?? 8).clamp(1, 104),
        perWeek: ((j['perWeek'] as num?)?.toInt() ?? 3).clamp(1, 7),
        pinnedDays: ((j['pinned'] as List?) ?? const [])
            .whereType<num>()
            .map((e) => e.toInt())
            .where((e) => e >= 1 && e <= 7)
            .toList(),
        round: (j['round'] as num?)?.toInt() ?? 1,
      );
}
