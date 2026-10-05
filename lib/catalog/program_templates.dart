import '../models/progression.dart';

/// 计划模板中的一个动作:名字(经 matchExerciseByName 模糊匹配到动作库)+ 组数 + 渐进规则。
class ProgramExercise {
  const ProgramExercise(this.name, this.sets, {this.spec});

  final String name;

  /// 组数(spec 为 null 时生效;有 spec 时用 spec.sets)
  final int sets;

  /// 自动渐进规则;null = 简单模板(手动加减重量)
  final ProgSpec? spec;
}

class ProgramDay {
  const ProgramDay(this.name, this.exercises, {this.weekday});

  final String name;
  final List<ProgramExercise> exercises;
  final int? weekday;
}

class ProgramTemplate {
  const ProgramTemplate(this.id, this.name, this.days, {this.pro = false});

  final String id;
  final String name;
  final List<ProgramDay> days;

  /// 是否带自动渐进(专业计划徽标)
  final bool pro;

  /// 是否含百分比周期(需要填训练最大值 TM)
  bool get hasCycle =>
      days.any((d) => d.exercises.any((e) => e.spec?.isCycle ?? false));

  /// 周期计划的主项动作名(去重,TM 对话框用)
  List<String> get cycleLifts {
    final out = <String>[];
    for (final d in days) {
      for (final e in d.exercises) {
        if (e.spec?.isCycle ?? false) {
          if (!out.contains(e.name)) out.add(e.name);
        }
      }
    }
    return out;
  }
}

// ---- 渐进规则快捷构造 ----

/// 线性渐进:达标 +step kg;连续失败 fail 次 → ×0.9 降载
ProgSpec lin({int sets = 3, int reps = 5, double step = 2.5, int fail = 3}) =>
    ProgSpec(kind: ProgKind.linear, sets: sets, reps: reps, stepKg: step, failLimit: fail);

/// 双渐进:次数 a→b 逐次递增,到顶 +step kg 并回落到 a
ProgSpec dbl({int sets = 3, int a = 8, int b = 12, double step = 2.5}) =>
    ProgSpec(kind: ProgKind.dbl, sets: sets, repMin: a, repMax: b, stepKg: step);

/// 纯次数递增(自重):达标 +1 次,到 b 提示换更难变式
ProgSpec repsProg({int sets = 3, int a = 6, int b = 12}) =>
    ProgSpec(kind: ProgKind.reps, sets: sets, repMin: a, repMax: b);

/// 百分比周期(531 式):weeks 为每周组次表(循环),tmStep 为每轮 TM 增量
ProgSpec cycle(List<List<CycleSet>> weeks, {double tmStep = 2.5}) =>
    ProgSpec(kind: ProgKind.cycle, weeks: weeks, stepKg: tmStep);

CycleSet cs(int reps, double pct) => CycleSet(reps, pct);

/// 5/3/1 + Boring But Big 的四波浪周期:
/// 第1周 3×5(65/75/85%)、第2周 3×3(70/80/90%)、第3周 5/3/1(75/85/95%)、第4周减载 3×5(40/50/60%)
/// 主项后接 BBB 补充组 5×10@50%(减载周 3×10@40%)
List<List<CycleSet>> wave531bbb() => [
      [cs(5, .65), cs(5, .75), cs(5, .85), cs(10, .5), cs(10, .5), cs(10, .5), cs(10, .5), cs(10, .5)],
      [cs(3, .70), cs(3, .80), cs(3, .90), cs(10, .5), cs(10, .5), cs(10, .5), cs(10, .5), cs(10, .5)],
      [cs(5, .75), cs(3, .85), cs(1, .95), cs(10, .5), cs(10, .5), cs(10, .5), cs(10, .5), cs(10, .5)],
      [cs(5, .40), cs(5, .50), cs(5, .60), cs(10, .4), cs(10, .4), cs(10, .4)],
    ];

final List<ProgramTemplate> kProgramTemplates = [
  // ---- 专业计划(带自动渐进) ----
  ProgramTemplate('stronglifts', 'StrongLifts 5×5', [
    ProgramDay('Workout A', [
      ProgramExercise('Barbell Squat', 5, spec: lin(sets: 5, reps: 5)),
      ProgramExercise('Barbell Bench Press', 5, spec: lin(sets: 5, reps: 5)),
      ProgramExercise('Barbell Bent Over Row', 5, spec: lin(sets: 5, reps: 5)),
    ], weekday: 1),
    ProgramDay('Workout B', [
      ProgramExercise('Barbell Squat', 5, spec: lin(sets: 5, reps: 5)),
      ProgramExercise('Barbell Standing Close Grip Military Press', 5, spec: lin(sets: 5, reps: 5)),
      ProgramExercise('Barbell Deadlift', 1, spec: lin(sets: 1, reps: 5)),
    ], weekday: 3),
    ProgramDay('Workout A', [
      ProgramExercise('Barbell Squat', 5, spec: lin(sets: 5, reps: 5)),
      ProgramExercise('Barbell Bench Press', 5, spec: lin(sets: 5, reps: 5)),
      ProgramExercise('Barbell Bent Over Row', 5, spec: lin(sets: 5, reps: 5)),
    ], weekday: 5),
  ], pro: true),
  ProgramTemplate('startingstrength', 'Starting Strength', [
    ProgramDay('Workout A', [
      ProgramExercise('Barbell Squat', 3, spec: lin(sets: 3, reps: 5)),
      ProgramExercise('Barbell Bench Press', 3, spec: lin(sets: 3, reps: 5)),
      ProgramExercise('Barbell Deadlift', 1, spec: lin(sets: 1, reps: 5)),
    ], weekday: 1),
    ProgramDay('Workout B', [
      ProgramExercise('Barbell Squat', 3, spec: lin(sets: 3, reps: 5)),
      ProgramExercise('Barbell Standing Close Grip Military Press', 3, spec: lin(sets: 3, reps: 5)),
      ProgramExercise('power clean', 3, spec: lin(sets: 3, reps: 5)),
    ], weekday: 3),
    ProgramDay('Workout A', [
      ProgramExercise('Barbell Squat', 3, spec: lin(sets: 3, reps: 5)),
      ProgramExercise('Barbell Bench Press', 3, spec: lin(sets: 3, reps: 5)),
      ProgramExercise('Barbell Deadlift', 1, spec: lin(sets: 1, reps: 5)),
    ], weekday: 5),
  ], pro: true),
  ProgramTemplate('gzclp', 'GZCLP', [
    ProgramDay('Day 1 · Heavy Squat', [
      ProgramExercise('Barbell Squat', 5, spec: lin(sets: 5, reps: 3)),
      ProgramExercise('Barbell Bench Press', 3, spec: dbl(sets: 3, a: 8, b: 12)),
      ProgramExercise('Barbell Bent Over Row', 3, spec: dbl(sets: 3, a: 12, b: 15)),
    ], weekday: 1),
    ProgramDay('Day 2 · Heavy Press', [
      ProgramExercise('Barbell Standing Close Grip Military Press', 5, spec: lin(sets: 5, reps: 3)),
      ProgramExercise('Barbell Deadlift', 3, spec: lin(sets: 3, reps: 5)),
      ProgramExercise('Pull-up', 3, spec: repsProg(sets: 3, a: 5, b: 12)),
    ], weekday: 3),
    ProgramDay('Day 3 · Volume', [
      ProgramExercise('Barbell Front Squat', 3, spec: dbl(sets: 3, a: 8, b: 10)),
      ProgramExercise('Barbell Incline Bench Press', 3, spec: dbl(sets: 3, a: 8, b: 12)),
      ProgramExercise('Wide-Grip Lat Pulldown', 3, spec: dbl(sets: 3, a: 12, b: 15, step: 1)),
    ], weekday: 5),
  ], pro: true),
  ProgramTemplate('bbb531', '5/3/1 Boring But Big', [
    ProgramDay('Squat Day', [
      ProgramExercise('Barbell Squat', 8, spec: cycle(wave531bbb(), tmStep: 5)),
      ProgramExercise('Dumbbell Lunge', 3, spec: dbl(sets: 3, a: 10, b: 12, step: 1)),
      ProgramExercise('Barbell Standing Calf Raise', 3, spec: dbl(sets: 3, a: 10, b: 15, step: 1)),
    ], weekday: 1),
    ProgramDay('Bench Day', [
      ProgramExercise('Barbell Bench Press', 8, spec: cycle(wave531bbb())),
      ProgramExercise('Triceps Dip', 3, spec: repsProg(sets: 3, a: 8, b: 15)),
      ProgramExercise('Face Pull', 3, spec: repsProg(sets: 3, a: 12, b: 20)),
    ], weekday: 2),
    ProgramDay('Deadlift Day', [
      ProgramExercise('Barbell Deadlift', 8, spec: cycle(wave531bbb(), tmStep: 5)),
      ProgramExercise('Cable Seated Row', 3, spec: dbl(sets: 3, a: 10, b: 12)),
      ProgramExercise('Hanging Leg Raise', 3, spec: repsProg(sets: 3, a: 8, b: 15)),
    ], weekday: 4),
    ProgramDay('Press Day', [
      ProgramExercise('Barbell Standing Close Grip Military Press', 8, spec: cycle(wave531bbb())),
      ProgramExercise('Pull-up', 3, spec: repsProg(sets: 3, a: 5, b: 12)),
      ProgramExercise('Dumbbell Lateral Raise', 3, spec: dbl(sets: 3, a: 12, b: 15, step: 1)),
    ], weekday: 5),
  ], pro: true),
  ProgramTemplate('ppl6', 'PPL 6-Day', [
    ProgramDay('Push A', [
      ProgramExercise('Barbell Bench Press', 4, spec: lin(sets: 4, reps: 5)),
      ProgramExercise('Barbell Incline Bench Press', 3, spec: dbl(sets: 3, a: 8, b: 12)),
      ProgramExercise('Dumbbell Lateral Raise', 3, spec: dbl(sets: 3, a: 12, b: 15, step: 1)),
      ProgramExercise('Barbell Lying Triceps Extension', 3, spec: dbl(sets: 3, a: 8, b: 12, step: 1)),
    ], weekday: 1),
    ProgramDay('Pull A', [
      ProgramExercise('Barbell Deadlift', 3, spec: lin(sets: 3, reps: 5)),
      ProgramExercise('Pull-up', 4, spec: repsProg(sets: 4, a: 6, b: 12)),
      ProgramExercise('Barbell Bent Over Row', 3, spec: dbl(sets: 3, a: 8, b: 12)),
      ProgramExercise('Face Pull', 3, spec: repsProg(sets: 3, a: 12, b: 20)),
      ProgramExercise('Dumbbell Hammer Curl', 3, spec: dbl(sets: 3, a: 8, b: 12, step: 1)),
    ], weekday: 2),
    ProgramDay('Legs A', [
      ProgramExercise('Barbell Squat', 4, spec: lin(sets: 4, reps: 5)),
      ProgramExercise('Leg Press', 3, spec: dbl(sets: 3, a: 10, b: 12)),
      ProgramExercise('Lying Leg Curl', 3, spec: dbl(sets: 3, a: 10, b: 15, step: 1)),
      ProgramExercise('Barbell Standing Calf Raise', 4, spec: dbl(sets: 4, a: 10, b: 15, step: 1)),
    ], weekday: 3),
    ProgramDay('Push B', [
      ProgramExercise('Barbell Standing Close Grip Military Press', 4, spec: lin(sets: 4, reps: 5)),
      ProgramExercise('Dumbbell Incline Bench Press', 3, spec: dbl(sets: 3, a: 8, b: 12, step: 1)),
      ProgramExercise('Flat Bench Cable Fly', 3, spec: dbl(sets: 3, a: 12, b: 15, step: 1)),
      ProgramExercise('Dumbbell Lateral Raise', 3, spec: dbl(sets: 3, a: 12, b: 15, step: 1)),
      ProgramExercise('Triceps Pushdown', 3, spec: dbl(sets: 3, a: 10, b: 15, step: 1)),
    ], weekday: 4),
    ProgramDay('Pull B', [
      ProgramExercise('Barbell Pendlay Row', 4, spec: lin(sets: 4, reps: 6)),
      ProgramExercise('Wide-Grip Lat Pulldown', 3, spec: dbl(sets: 3, a: 10, b: 12)),
      ProgramExercise('Cable Seated Row', 3, spec: dbl(sets: 3, a: 10, b: 12)),
      ProgramExercise('Face Pull', 3, spec: repsProg(sets: 3, a: 12, b: 20)),
      ProgramExercise('Barbell Curl', 3, spec: dbl(sets: 3, a: 8, b: 12, step: 1)),
    ], weekday: 5),
    ProgramDay('Legs B', [
      ProgramExercise('Barbell Front Squat', 3, spec: dbl(sets: 3, a: 8, b: 10)),
      ProgramExercise('Bulgarian Split Squat', 3, spec: dbl(sets: 3, a: 8, b: 12, step: 1)),
      ProgramExercise('Seated Leg Curl', 3, spec: dbl(sets: 3, a: 10, b: 15, step: 1)),
      ProgramExercise('Leg Press Calf Raise', 4, spec: dbl(sets: 4, a: 12, b: 15, step: 1)),
      ProgramExercise('Hanging Leg Raise', 3, spec: repsProg(sets: 3, a: 10, b: 15)),
    ], weekday: 6),
  ], pro: true),
  ProgramTemplate('phul', 'PHUL', [
    ProgramDay('Upper Power', [
      ProgramExercise('Barbell Bench Press', 4, spec: lin(sets: 4, reps: 5)),
      ProgramExercise('Barbell Bent Over Row', 4, spec: lin(sets: 4, reps: 5)),
      ProgramExercise('Barbell Standing Close Grip Military Press', 3, spec: dbl(sets: 3, a: 6, b: 10)),
      ProgramExercise('Barbell Curl', 3, spec: dbl(sets: 3, a: 6, b: 10, step: 1)),
      ProgramExercise('Barbell Lying Triceps Extension', 3, spec: dbl(sets: 3, a: 6, b: 10, step: 1)),
    ], weekday: 1),
    ProgramDay('Lower Power', [
      ProgramExercise('Barbell Squat', 4, spec: lin(sets: 4, reps: 5)),
      ProgramExercise('Barbell Deadlift', 3, spec: lin(sets: 3, reps: 5)),
      ProgramExercise('Leg Press', 3, spec: dbl(sets: 3, a: 6, b: 10)),
      ProgramExercise('Lying Leg Curl', 3, spec: dbl(sets: 3, a: 6, b: 10, step: 1)),
      ProgramExercise('Barbell Standing Calf Raise', 3, spec: dbl(sets: 3, a: 6, b: 10, step: 1)),
    ], weekday: 2),
    ProgramDay('Upper Hypertrophy', [
      ProgramExercise('Barbell Incline Bench Press', 4, spec: dbl(sets: 4, a: 8, b: 12)),
      ProgramExercise('Wide-Grip Lat Pulldown', 4, spec: dbl(sets: 4, a: 8, b: 12)),
      ProgramExercise('Flat Bench Cable Fly', 3, spec: dbl(sets: 3, a: 10, b: 15, step: 1)),
      ProgramExercise('Dumbbell Lateral Raise', 3, spec: dbl(sets: 3, a: 10, b: 15, step: 1)),
      ProgramExercise('Dumbbell Hammer Curl', 3, spec: dbl(sets: 3, a: 10, b: 15, step: 1)),
      ProgramExercise('Triceps Pushdown', 3, spec: dbl(sets: 3, a: 10, b: 15, step: 1)),
    ], weekday: 4),
    ProgramDay('Lower Hypertrophy', [
      ProgramExercise('Barbell Front Squat', 4, spec: dbl(sets: 4, a: 8, b: 12)),
      ProgramExercise('Dumbbell Lunge', 3, spec: dbl(sets: 3, a: 8, b: 12, step: 1)),
      ProgramExercise('Seated Leg Curl', 3, spec: dbl(sets: 3, a: 10, b: 15, step: 1)),
      ProgramExercise('Leg Press Calf Raise', 4, spec: dbl(sets: 4, a: 10, b: 15, step: 1)),
      ProgramExercise('Hanging Leg Raise', 3, spec: repsProg(sets: 3, a: 10, b: 15)),
    ], weekday: 5),
  ], pro: true),

  // ---- 简单模板(手动管理重量,行为同旧版) ----
  ProgramTemplate('fullbody', 'Full Body', [
    ProgramDay('Full Body', [
      ProgramExercise('Barbell Squat', 3),
      ProgramExercise('Barbell Bench Press', 3),
      ProgramExercise('Barbell Row', 3),
      ProgramExercise('Overhead Press', 3),
      ProgramExercise('Romanian Deadlift', 3),
      ProgramExercise('Plank', 3),
    ], weekday: 1),
    ProgramDay('Full Body', [
      ProgramExercise('Barbell Squat', 3),
      ProgramExercise('Barbell Bench Press', 3),
      ProgramExercise('Barbell Row', 3),
      ProgramExercise('Overhead Press', 3),
      ProgramExercise('Romanian Deadlift', 3),
      ProgramExercise('Plank', 3),
    ], weekday: 3),
    ProgramDay('Full Body', [
      ProgramExercise('Barbell Squat', 3),
      ProgramExercise('Barbell Bench Press', 3),
      ProgramExercise('Barbell Row', 3),
      ProgramExercise('Overhead Press', 3),
      ProgramExercise('Romanian Deadlift', 3),
      ProgramExercise('Plank', 3),
    ], weekday: 5),
  ]),
  ProgramTemplate('ppl', 'Push Pull Legs', [
    ProgramDay('Push', [
      ProgramExercise('Barbell Bench Press', 4),
      ProgramExercise('Incline Dumbbell Press', 3),
      ProgramExercise('Overhead Press', 3),
      ProgramExercise('Lateral Raise', 3),
      ProgramExercise('Triceps Pushdown', 3),
    ], weekday: 1),
    ProgramDay('Pull', [
      ProgramExercise('Pull Up', 4),
      ProgramExercise('Barbell Row', 4),
      ProgramExercise('Lat Pulldown', 3),
      ProgramExercise('Face Pull', 3),
      ProgramExercise('Barbell Curl', 3),
    ], weekday: 3),
    ProgramDay('Legs', [
      ProgramExercise('Barbell Squat', 4),
      ProgramExercise('Romanian Deadlift', 3),
      ProgramExercise('Leg Press', 3),
      ProgramExercise('Leg Curl', 3),
      ProgramExercise('Standing Calf Raise', 4),
    ], weekday: 5),
  ]),
  ProgramTemplate('upperlower', 'Upper Lower', [
    ProgramDay('Upper', [
      ProgramExercise('Barbell Bench Press', 4),
      ProgramExercise('Barbell Row', 4),
      ProgramExercise('Overhead Press', 3),
      ProgramExercise('Lat Pulldown', 3),
      ProgramExercise('Barbell Curl', 3),
      ProgramExercise('Triceps Pushdown', 3),
    ], weekday: 1),
    ProgramDay('Lower', [
      ProgramExercise('Barbell Squat', 4),
      ProgramExercise('Romanian Deadlift', 3),
      ProgramExercise('Leg Press', 3),
      ProgramExercise('Leg Curl', 3),
      ProgramExercise('Standing Calf Raise', 4),
    ], weekday: 2),
    ProgramDay('Upper', [
      ProgramExercise('Incline Dumbbell Press', 4),
      ProgramExercise('Pull Up', 4),
      ProgramExercise('Dumbbell Standing Overhead Press', 3),
      ProgramExercise('Seated Cable Row', 3),
      ProgramExercise('Hammer Curl', 3),
      ProgramExercise('Triceps Dip', 3),
    ], weekday: 4),
    ProgramDay('Lower', [
      ProgramExercise('Deadlift', 3),
      ProgramExercise('Front Squat', 3),
      ProgramExercise('Leg Extension', 3),
      ProgramExercise('Leg Curl', 3),
      ProgramExercise('Standing Calf Raise', 4),
    ], weekday: 5),
  ]),
  ProgramTemplate('abcd', 'ABCD Split', [
    ProgramDay('A · Chest & Triceps', [
      ProgramExercise('Barbell Bench Press', 4),
      ProgramExercise('Incline Dumbbell Press', 4),
      ProgramExercise('Cable Fly', 3),
      ProgramExercise('Triceps Pushdown', 3),
      ProgramExercise('Skull Crushers', 3),
    ], weekday: 1),
    ProgramDay('B · Back & Biceps', [
      ProgramExercise('Pull Up', 4),
      ProgramExercise('Barbell Row', 4),
      ProgramExercise('Lat Pulldown', 3),
      ProgramExercise('Barbell Curl', 3),
      ProgramExercise('Hammer Curl', 3),
    ], weekday: 2),
    ProgramDay('C · Legs', [
      ProgramExercise('Barbell Squat', 4),
      ProgramExercise('Romanian Deadlift', 3),
      ProgramExercise('Leg Press', 3),
      ProgramExercise('Leg Curl', 3),
      ProgramExercise('Standing Calf Raise', 4),
    ], weekday: 4),
    ProgramDay('D · Shoulders & Abs', [
      ProgramExercise('Overhead Press', 4),
      ProgramExercise('Lateral Raise', 4),
      ProgramExercise('Face Pull', 3),
      ProgramExercise('Hanging Leg Raise', 3),
      ProgramExercise('Plank', 3),
    ], weekday: 5),
  ]),
  ProgramTemplate('abcde', 'ABCDE Split', [
    ProgramDay('A · Chest', [
      ProgramExercise('Barbell Bench Press', 4),
      ProgramExercise('Incline Dumbbell Press', 4),
      ProgramExercise('Cable Fly', 3),
      ProgramExercise('Triceps Dip', 3),
    ], weekday: 1),
    ProgramDay('B · Back', [
      ProgramExercise('Deadlift', 3),
      ProgramExercise('Pull Up', 4),
      ProgramExercise('Barbell Row', 4),
      ProgramExercise('Seated Cable Row', 3),
    ], weekday: 2),
    ProgramDay('C · Legs', [
      ProgramExercise('Barbell Squat', 4),
      ProgramExercise('Leg Press', 4),
      ProgramExercise('Leg Extension', 3),
      ProgramExercise('Leg Curl', 3),
      ProgramExercise('Standing Calf Raise', 4),
    ], weekday: 3),
    ProgramDay('D · Shoulders', [
      ProgramExercise('Overhead Press', 4),
      ProgramExercise('Dumbbell Standing Overhead Press', 3),
      ProgramExercise('Lateral Raise', 4),
      ProgramExercise('Face Pull', 3),
    ], weekday: 4),
    ProgramDay('E · Arms', [
      ProgramExercise('Barbell Curl', 4),
      ProgramExercise('Skull Crushers', 4),
      ProgramExercise('Hammer Curl', 3),
      ProgramExercise('Triceps Pushdown', 3),
    ], weekday: 5),
  ]),
  ProgramTemplate('rr', 'Recommended Routine', [
    ProgramDay('Recommended Routine', [
      ProgramExercise('Negative Pull-up', 3),
      ProgramExercise('Bodyweight Squat', 3),
      ProgramExercise('Negative Dip', 3),
      ProgramExercise('Bodyweight Romanian Deadlift', 3),
      ProgramExercise('Incline Row', 3),
      ProgramExercise('Incline Push-up', 3),
      ProgramExercise('Plank', 3),
      ProgramExercise('Banded Pallof Press', 3),
      ProgramExercise('Reverse Hyperextension', 3),
    ], weekday: 1),
    ProgramDay('Recommended Routine', [
      ProgramExercise('Negative Pull-up', 3),
      ProgramExercise('Bodyweight Squat', 3),
      ProgramExercise('Negative Dip', 3),
      ProgramExercise('Bodyweight Romanian Deadlift', 3),
      ProgramExercise('Incline Row', 3),
      ProgramExercise('Incline Push-up', 3),
      ProgramExercise('Plank', 3),
      ProgramExercise('Banded Pallof Press', 3),
      ProgramExercise('Reverse Hyperextension', 3),
    ], weekday: 3),
    ProgramDay('Recommended Routine', [
      ProgramExercise('Negative Pull-up', 3),
      ProgramExercise('Bodyweight Squat', 3),
      ProgramExercise('Negative Dip', 3),
      ProgramExercise('Bodyweight Romanian Deadlift', 3),
      ProgramExercise('Incline Row', 3),
      ProgramExercise('Incline Push-up', 3),
      ProgramExercise('Plank', 3),
      ProgramExercise('Banded Pallof Press', 3),
      ProgramExercise('Reverse Hyperextension', 3),
    ], weekday: 5),
  ]),
  ProgramTemplate('home', 'No Kit', [
    ProgramDay('Home A', [
      ProgramExercise('Push Up', 3),
      ProgramExercise('Pull Up', 3),
      ProgramExercise('Bodyweight Squat', 3),
      ProgramExercise('Plank', 3),
    ], weekday: 2),
    ProgramDay('Home B', [
      ProgramExercise('Triceps Dip', 3),
      ProgramExercise('Chin Up', 3),
      ProgramExercise('Lunge', 3),
      ProgramExercise('Hanging Leg Raise', 3),
    ], weekday: 5),
  ]),
];
