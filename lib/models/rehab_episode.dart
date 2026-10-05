/*
 * 康复档案（Rehab Episode）—— 一个困扰 = 一个档案。
 * 融合进 GymMane（GPLv3），随本体一同以 GPLv3 分发。
 *
 * 参考 RehabFlow 的 Care Episode 概念做了本地化简化：
 * 问诊信息 + 安全门 + 训练计划 + AI 建议 + 备注，全部存在本地。
 */
class RehabEpisode {
  RehabEpisode({
    required this.id,
    required this.title,
    required this.createdAt,
    this.area = '',
    this.duration = '',
    this.pain = 0,
    this.redFlags = const [],
    this.factors = '',
    this.goals = const [],
    this.equipment = const [],
    this.daysPerWeek = 3,
    this.routineIds = const [],
    this.advice = '',
    this.notes = '',
    this.status = 'active',
  });

  final String id;

  /// 档案名（用户可改），默认由部位自动生成
  String title;

  final DateTime createdAt;

  /// 部位 key（见 rehab_intake.dart 的 kRehabAreas）
  String area;

  /// 病程 key（见 kRehabDurations）
  String duration;

  /// 疼痛/不适程度 0-10
  int pain;

  /// 命中的红旗征 key 列表；非空 = 未通过安全门
  List<String> redFlags;

  /// 加重/缓解因素（自由文本）
  String factors;

  /// 康复目标 key 列表
  List<String> goals;

  /// 可用器材（kEquipment 词表）
  List<String> equipment;

  /// 每周可训练天数
  int daysPerWeek;

  /// 关联的训练计划（Routine.id），由 AI 回复导入或手动建立
  List<String> routineIds;

  /// AI 回复里的注意事项/叫停规则（纯文本展示）
  String advice;

  /// 用户备注
  String notes;

  /// active | done
  String status;

  /// 安全门：没有红旗征才放行训练建议
  bool get safe => redFlags.isEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        't': title,
        'c': createdAt.toIso8601String(),
        'area': area,
        'dur': duration,
        'pain': pain,
        'rf': redFlags,
        'fac': factors,
        'goals': goals,
        'eq': equipment,
        'dpw': daysPerWeek,
        'rids': routineIds,
        'adv': advice,
        'note': notes,
        'st': status,
      };

  factory RehabEpisode.fromJson(Map<String, dynamic> j) => RehabEpisode(
        id: (j['id'] ?? '') as String,
        title: (j['t'] ?? '') as String,
        createdAt: DateTime.tryParse((j['c'] ?? '') as String) ?? DateTime.now(),
        area: (j['area'] ?? '') as String,
        duration: (j['dur'] ?? '') as String,
        pain: ((j['pain'] ?? 0) as num).toInt(),
        redFlags: [...((j['rf'] as List?) ?? const []).map((e) => '$e')],
        factors: (j['fac'] ?? '') as String,
        goals: [...((j['goals'] as List?) ?? const []).map((e) => '$e')],
        equipment: [...((j['eq'] as List?) ?? const []).map((e) => '$e')],
        daysPerWeek: ((j['dpw'] ?? 3) as num).toInt(),
        routineIds: [...((j['rids'] as List?) ?? const []).map((e) => '$e')],
        advice: (j['adv'] ?? '') as String,
        notes: (j['note'] ?? '') as String,
        status: (j['st'] ?? 'active') as String,
      );
}
