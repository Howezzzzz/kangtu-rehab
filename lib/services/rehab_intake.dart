/*
 * 康复问诊内容 + 安全门规则 —— 纯本地，无网络。
 * 融合进 GymMane（GPLv3），随本体一同以 GPLv3 分发。
 *
 * 安全门参考 RehabFlow 的 Rehab Safety Gate：填完问诊后先跑红旗征筛查，
 * 命中任何一项就不给训练建议，只给「先就医」的引导。
 * 内容按通用运动康复常识整理，不构成医疗建议。
 */
import 'dart:convert';

import '../l10n/l10n.dart';

/// 红旗征 id（命中任意一项 → 安全门不通过）—— 文案见 l10n 的 rehabFlag*。
const List<String> kRehabRedFlagIds = [
  'bladder',
  'weakness',
  'trauma',
  'fever',
  'night',
  'cancer',
  'pregnant',
  'surgery',
];

/// 不适部位 id
const List<String> kRehabAreaIds = [
  'lowback',
  'neck',
  'shoulder',
  'elbow',
  'hip',
  'knee',
  'ankle',
  'other',
];

/// 病程 id
const List<String> kRehabDurationIds = ['acute', 'sub', 'chronic', 'long'];

/// 康复目标 id
const List<String> kRehabGoalIds = ['pain', 'mobility', 'strength', 'return', 'daily'];

String rehabAreaLabel(String key) => t.rehabArea(key);
String rehabDurationLabel(String key) => t.rehabDuration(key);
String rehabGoalLabel(String key) => t.rehabGoal(key);
String rehabFlagLabel(String key) => t.rehabRedFlag(key);

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
