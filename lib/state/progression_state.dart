part of 'fit_state.dart';

/// 自动渐进引擎(顶层函数,与 fit_state 同库)。
///
/// 训练结束(finishSession)时调用:根据本次实际完成情况推进渐进状态,
/// 并把「下一次的目标组次重量」写回 routine.plan —— 下一次开练时
/// _openingSets 会直接用这份 plan,无需改训练流程。
/// 反馈文案写进 fit.progFeedback,完成页展示。
void runProgression(WorkoutState fit, Routine r, LoggedSession s) {
  final inst = r.progInst == null ? null : fit.programStates[r.progInst!];
  if (r.prog.isEmpty || inst == null) return;

  final fam = [for (final x in fit.routines) if (x.progInst == r.progInst) x];

  // ---- 周期计划:按时间推进波浪周(每 6 天 +1 周),整轮结束 TM 上调 ----
  final cycleSpecs = <String, ProgSpec>{
    for (final e in r.prog.entries)
      if (e.value.isCycle) e.key: e.value,
  };
  if (cycleSpecs.isNotEmpty) {
    final now = DateTime.now().millisecondsSinceEpoch;
    const day6 = 6 * 24 * 3600 * 1000;
    if (inst.lastAdv == 0) {
      inst.lastAdv = now;
    } else if (now - inst.lastAdv >= day6) {
      final len = cycleSpecs.values.first.weeks.length;
      inst.week = (inst.week + 1) % len;
      inst.lastAdv = now;
      if (inst.week == 0) {
        for (final e in cycleSpecs.entries) {
          final cur = inst.tm[e.key] ?? 40;
          final next = roundHalf(cur + e.value.stepKg);
          inst.tm[e.key] = next;
          fit.progFeedback.add(t.progTmUp(_progName(fit, e.key), fit.weightLabel(next)));
        }
      }
      fit.progFeedback.add(t.progWeekN(inst.week + 1));
    }
    // 周期动作:全部家族 routine 的 plan 同步到当前周
    for (final rt in fam) {
      for (final e in rt.prog.entries) {
        if (e.value.isCycle) rebuildCyclePlan(rt, e.key, e.value, inst);
      }
    }
  }

  // ---- 本次实际完成的动作:评估并推进 ----
  for (final le in s.exercises) {
    final spec = r.prog[le.id];
    if (spec == null || spec.isCycle) continue;
    final working = le.workingSets;
    if (working.isEmpty) continue;
    final name = _progName(fit, le.id, fallback: le.name);
    final step = fit.progressStep[le.id] ?? spec.stepKg;
    final topWeight = working.map((x) => x.weight).reduce(math.max);

    switch (spec.kind) {
      case ProgKind.linear:
        final planned = (r.plan[le.id] ?? const [])
            .where((p) => p.kind != SetKind.warmup && (p.reps ?? 0) > 0)
            .toList();
        final targetReps = planned.isNotEmpty ? planned.first.reps! : spec.reps;
        final hit = working.every((x) => x.reps >= targetReps);
        final base = inst.w[le.id] ?? topWeight;
        var w = base;
        if (hit) {
          w = roundHalf(base + step);
          inst.fails.remove(le.id);
          fit.progFeedback.add(t.progNext(name, '${fit.weightLabel(w)} × $targetReps'));
        } else {
          final fails = (inst.fails[le.id] ?? 0) + 1;
          if (spec.failLimit > 0 && fails >= spec.failLimit) {
            w = roundHalf(base * spec.deloadPct);
            inst.fails.remove(le.id);
            fit.progFeedback.add(t.progDeloadFb(name, fit.weightLabel(w)));
          } else {
            inst.fails[le.id] = fails;
            fit.progFeedback.add(t.progMiss(name, fails, spec.failLimit));
          }
        }
        if (w > 0) inst.w[le.id] = w;
        for (final rt in fam) {
          if (!rt.prog.containsKey(le.id)) continue;
          rebuildSimplePlan(rt, le.id, rt.prog[le.id]!,
              repsTarget: targetReps, weight: w > 0 ? w : null);
        }

      case ProgKind.dbl:
        final cur = inst.reps[le.id] ?? spec.repMin;
        final hit = working.every((x) => x.reps >= cur);
        final base = inst.w[le.id] ?? topWeight;
        var target = cur;
        var w = base;
        if (hit) {
          if (cur < spec.repMax) {
            target = cur + 1;
            fit.progFeedback.add(t.progRepsNext(name, target));
          } else if (base > 0) {
            w = roundHalf(base + step);
            target = spec.repMin;
            fit.progFeedback.add(t.progNext(name, '${fit.weightLabel(w)} × $target'));
          } else {
            fit.progFeedback.add(t.progVarHint(name, cur));
          }
        }
        inst.reps[le.id] = target;
        if (w > 0) inst.w[le.id] = w;
        for (final rt in fam) {
          if (!rt.prog.containsKey(le.id)) continue;
          rebuildSimplePlan(rt, le.id, rt.prog[le.id]!,
              repsTarget: target, weight: w > 0 ? w : null);
        }

      case ProgKind.reps:
        final cur = inst.reps[le.id] ?? spec.repMin;
        final hit = working.every((x) => x.reps >= cur);
        var target = cur;
        if (hit) {
          if (cur < spec.repMax) {
            target = cur + 1;
            fit.progFeedback.add(t.progRepsNext(name, target));
          } else {
            fit.progFeedback.add(t.progVarHint(name, cur));
          }
        }
        inst.reps[le.id] = target;
        for (final rt in fam) {
          if (!rt.prog.containsKey(le.id)) continue;
          rebuildSimplePlan(rt, le.id, rt.prog[le.id]!, repsTarget: target);
        }

      case ProgKind.cycle:
        break; // 上面统一处理
    }
  }
}

String _progName(LibraryState fit, String exId, {String? fallback}) {
  final ex = fit.exerciseById(exId);
  return t.catalogName(exId, fallback ?? ex?.name ?? exId);
}

/// 线性/双渐进/纯次数:按当前状态重写下次目标组。
void rebuildSimplePlan(Routine r, String exId, ProgSpec spec,
    {int? repsTarget, double? weight}) {
  final reps = repsTarget ?? (spec.kind == ProgKind.linear ? spec.reps : spec.repMin);
  final sets = List<PlannedSet>.generate(
    spec.sets,
    (_) => PlannedSet(reps: reps, weightKg: (weight ?? 0) > 0 ? weight : null),
  );
  r.plan[exId] = List.unmodifiable(sets);
  r.sets[exId] = spec.sets;
}

/// 周期计划:按当前波浪周 + TM 重写下次目标组。
void rebuildCyclePlan(Routine r, String exId, ProgSpec spec, ProgState inst) {
  final wk = spec.weeks[inst.week % spec.weeks.length];
  final tm = inst.tm[exId] ?? 40;
  final sets = [for (final c in wk) PlannedSet(reps: c.reps, weightKg: roundHalf(c.pct * tm))];
  r.plan[exId] = List.unmodifiable(sets);
  r.sets[exId] = sets.length;
}

/// 应用模板时的初始 plan(周期计划需要 TM;其余重量留空,首次训练沿用历史/默认)。
void buildInitialPlan(Routine r, String exId, ProgSpec spec, ProgState inst) {
  if (spec.isCycle) {
    rebuildCyclePlan(r, exId, spec, inst);
  } else {
    rebuildSimplePlan(r, exId, spec);
  }
}

/// 从历史记录估算训练最大值(最佳 1RM × 0.9);无记录返回 null。
double? estimateTrainingMax(FitCore fit, String exId) {
  var best = 0.0;
  for (final s in fit.sessions) {
    for (final e in s.exercises) {
      if (e.id != exId) continue;
      final orm = e.bestOneRm;
      if (orm > best) best = orm;
    }
  }
  return best > 0 ? roundHalf(best * 0.9) : null;
}
