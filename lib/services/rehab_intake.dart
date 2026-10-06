/*
 * 康复问诊内容 + 安全门规则 —— 纯本地，无网络。
 * 融合进 GymMane（GPLv3），随本体一同以 GPLv3 分发。
 *
 * 安全门参考 RehabFlow 的 Rehab Safety Gate：填完问诊后先跑红旗征筛查，
 * 命中任何一项就不给训练建议，只给「先就医」的引导。
 * 内容按通用运动康复常识整理，不构成医疗建议。
 */
import 'dart:convert';

/// 红旗征：命中任意一项 → 安全门不通过
const Map<String, String> kRehabRedFlags = {
  'bladder': '大小便控制异常、会阴部（鞍区）麻木',
  'weakness': '下肢进行性无力、走路发飘或拖步',
  'trauma': '近期有摔倒、撞击等外伤',
  'fever': '发热、寒战或局部红肿发热',
  'night': '夜间静息痛、不明原因消瘦',
  'cancer': '肿瘤、结核或严重骨质疏松病史',
  'pregnant': '已怀孕或产后早期',
  'surgery': '近 3 个月内做过手术',
};

/// 不适部位
const Map<String, String> kRehabAreas = {
  'lowback': '腰 / 下背',
  'neck': '颈 / 上背',
  'shoulder': '肩',
  'elbow': '肘 / 腕',
  'hip': '髋',
  'knee': '膝',
  'ankle': '踝 / 足',
  'other': '其他 / 说不清',
};

/// 病程
const Map<String, String> kRehabDurations = {
  'acute': '1 周以内',
  'sub': '1~4 周',
  'chronic': '1~3 个月',
  'long': '3 个月以上',
};

/// 康复目标
const Map<String, String> kRehabGoals = {
  'pain': '缓解疼痛',
  'mobility': '恢复活动度',
  'strength': '增强力量',
  'return': '回归运动 / 训练',
  'daily': '改善日常功能（久坐、弯腰、上下楼）',
};

/// 训练建议里必须包含的叫停规则（写进给 AI 的提示词，AI 需照抄并补充）
const String kRehabStopRules = '出现以下情况立即停止并就医：疼痛在训练中持续加重；'
    '出现下肢麻木、无力或大小便异常；头晕、胸闷、心慌；疼痛第二天仍明显加重。';

String rehabAreaLabel(String key) => kRehabAreas[key] ?? key;
String rehabDurationLabel(String key) => kRehabDurations[key] ?? key;
String rehabGoalLabel(String key) => kRehabGoals[key] ?? key;

/// 从 AI 回复里抠出第一个 JSON 对象（与训练计划导入共用同一套动作 JSON 结构）
Map<String, dynamic>? extractJsonObject(String raw) {
  final start = raw.indexOf('{');
  if (start < 0) return null;
  var depth = 0;
  for (var i = start; i < raw.length; i++) {
    final c = raw[i];
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) {
        try {
          final v = jsonDecode(raw.substring(start, i + 1));
          return v is Map ? v.cast<String, dynamic>() : null;
        } catch (_) {
          return null;
        }
      }
    }
  }
  return null;
}

/// 从 AI 回复里取「注意事项 / 叫停规则」文本。
/// 支持：顶层 advice / notes / cautions 字段，或 JSON 之后的纯文本段落。
String extractRehabAdvice(String raw) {
  final obj = extractJsonObject(raw);
  if (obj != null) {
    for (final k in const ['advice', 'notes', 'cautions', 'warnings', '注意事项']) {
      final v = obj[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is List) {
        final t = v.whereType<String>().where((s) => s.trim().isNotEmpty).toList();
        if (t.isNotEmpty) return t.join('\n');
      }
    }
  }
  // 退路：JSON 之外的非空文本行
  final lines = raw
      .split('\n')
      .where((l) => l.trim().isNotEmpty && !l.trim().startsWith('{') && !l.trim().startsWith('}'))
      .map((l) => l.trim())
      .where((l) => !l.startsWith('"') && !l.endsWith(','))
      .toList();
  return lines.length > 12 ? lines.sublist(lines.length - 12).join('\n') : lines.join('\n');
}

/// 单条计划调整指令（AI 回复里 adjust 数组的一项）。
/// 融合进 GymMane（GPLv3），随本体一同以 GPLv3 分发。
class RehabAdjust {
  const RehabAdjust({
    required this.action,
    this.target = '',
    required this.exercise,
    this.field = '',
    this.value,
    this.addSets,
    this.addReps,
    this.addWeight,
  });

  /// set | remove | add
  final String action;

  /// 目标计划名（空 = 应用到全部关联计划）
  final String target;

  /// 动作名（优先英文名，套用时按名字匹配动作库）
  final String exercise;

  /// set 的字段：weight | sets | reps | rest
  final String field;

  /// set 时的新值
  final num? value;

  /// add 时的组数 / 次数 / 重量
  final int? addSets;
  final int? addReps;
  final num? addWeight;

  static const _actions = {'set', 'remove', 'add'};
  static const _fields = {'weight', 'sets', 'reps', 'rest'};

  /// 解析一条指令；非法 / 字段残缺的条目返回 null（由调用方过滤）。
  static RehabAdjust? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final action = '${raw['action'] ?? ''}'.trim().toLowerCase();
    if (!_actions.contains(action)) return null;
    final exercise = '${raw['exercise'] ?? raw['name'] ?? ''}'.trim();
    if (exercise.isEmpty) return null;
    final target = '${raw['routine'] ?? raw['plan'] ?? ''}'.trim();
    if (action == 'add') {
      final sets = raw['sets'];
      final reps = raw['reps'];
      final weight = raw['weight'];
      return RehabAdjust(
        action: action,
        target: target,
        exercise: exercise,
        addSets: sets is num ? sets.toInt() : null,
        addReps: reps is num ? reps.toInt() : null,
        addWeight: weight is num ? weight : null,
      );
    }
    if (action == 'remove') {
      return RehabAdjust(action: action, target: target, exercise: exercise);
    }
    // set
    final field = '${raw['field'] ?? ''}'.trim().toLowerCase();
    if (!_fields.contains(field)) return null;
    final value = raw['value'];
    if (value is! num) return null;
    return RehabAdjust(action: action, target: target, exercise: exercise, field: field, value: value);
  }
}

/// 从 AI 回复里取计划调整指令（adjust / adjustments / changes 数组）。
/// 没有 / 非法条目一律过滤，返回空列表。
List<RehabAdjust> extractRehabAdjust(String raw) {
  final obj = extractJsonObject(raw);
  if (obj == null) return const [];
  final list = obj['adjust'] ?? obj['adjustments'] ?? obj['changes'];
  if (list is! List) return const [];
  return [for (final e in list) ?RehabAdjust.tryParse(e)];
}
