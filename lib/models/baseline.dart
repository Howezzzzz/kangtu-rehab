/// 自测基线（Baseline Self-Test）—— 先测身体基础值，再据此给训练计划定起始强度。
/// v1 只做「普通档（fitness）」6 项、零器械；分龄参考值表与康复档（ODI/RMDQ/NPRS）留 v2。
class BaselineDef {
  const BaselineDef(this.code, this.unit, {this.higherIsBetter = true, this.safeForBack = true});
  final String code;
  final String unit;
  final bool higherIsBetter; // 越大越好？（静息心率、腰围为 false）
  final bool safeForBack; // 腰痛者是否可做（跑跳类禁用）
}

/// v1 普通档 6 项（覆盖 ACSM 四要素：心肺/力量/柔韧/平衡/体成分）。
const List<BaselineDef> kBaselineFitness = [
  BaselineDef('resting_hr', 'bpm', higherIsBetter: false), // 心肺
  BaselineDef('step_2min', '次'), // 心肺（Rikli & Jones 2 分钟原地踏步）
  BaselineDef('chair_stand_30', '次'), // 下肢力量（30 秒坐站）
  BaselineDef('single_leg_stand', '秒'), // 平衡（单脚站立·睁眼）
  BaselineDef('sit_reach', 'cm'), // 柔韧（坐位体前屈）
  BaselineDef('waist', 'cm', higherIsBetter: false), // 体成分
];

BaselineDef? baselineDef(String code) {
  for (final d in kBaselineFitness) {
    if (d.code == code) return d;
  }
  return null;
}

class BaselineItem {
  BaselineItem(this.code, this.value);
  final String code;
  final double value;

  Map<String, dynamic> toJson() => {'code': code, 'value': value};
  factory BaselineItem.fromJson(Map<String, dynamic> j) =>
      BaselineItem('${j['code']}', (j['value'] as num?)?.toDouble() ?? 0);
}

class BaselineSession {
  BaselineSession({required this.id, required this.date, this.type = 'fitness', required this.items});
  final String id;
  final DateTime date;
  final String type; // 'fitness' | 'rehab'（v1 只用 fitness）
  final List<BaselineItem> items;

  double? value(String code) {
    for (final it in items) {
      if (it.code == code) return it.value;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'd': date.toIso8601String(),
        'type': type,
        'items': items.map((e) => e.toJson()).toList(),
      };
  factory BaselineSession.fromJson(Map<String, dynamic> j) => BaselineSession(
        id: (j['id'] as String?) ?? 'b${DateTime.now().microsecondsSinceEpoch}',
        date: DateTime.tryParse(j['d'] as String? ?? '') ?? DateTime.now(),
        type: (j['type'] as String?) ?? 'fitness',
        items: ((j['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => BaselineItem.fromJson(m.cast<String, dynamic>()))
            .toList(),
      );
}
