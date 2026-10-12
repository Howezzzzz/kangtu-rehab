/// 康复日志条目（并入统一「日志」后，从 prefs 迁进 fit 状态持久化）。
/// 记录：日期 + 所处阶段（0..3 为阶段，4=维持）+ 当日状态（绿/黄/红）+ 感受文字。
class RehabLogEntry {
  RehabLogEntry({
    required this.id,
    required this.date,
    required this.phase,
    required this.light,
    this.feel = '',
  });

  final String id;
  final DateTime date;
  final int phase; // 0..3 阶段；4 = 维持
  final String light; // 'g' 绿 | 'y' 黄 | 'r' 红
  final String feel;

  bool get isMaintain => phase >= 4;

  Map<String, dynamic> toJson() => {
        'id': id,
        'd': date.toIso8601String(),
        'p': phase,
        'l': light,
        if (feel.isNotEmpty) 'f': feel,
      };

  factory RehabLogEntry.fromJson(Map<String, dynamic> j) {
    final d = DateTime.tryParse(j['d'] as String? ?? '') ?? DateTime.now();
    return RehabLogEntry(
      id: (j['id'] as String?) ?? 'r${d.millisecondsSinceEpoch}',
      date: d,
      phase: (j['p'] as num?)?.toInt() ?? 0,
      light: (j['l'] as String?) ?? 'g',
      feel: (j['f'] as String?) ?? '',
    );
  }
}
