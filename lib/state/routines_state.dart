part of 'fit_state.dart';

const int kDefaultRoutineSets = 3;

mixin RoutinesState on FitCore, LibraryState {
  String? activeRoutineId;
  int _routineSeq = 0;
  final List<SavedPlan> savedPlans = [];
  String currentPlanId = '';

  SavedPlan _snapshot(String id, String name) => SavedPlan(
        id,
        name,
        Map.of(weeklyPlan),
        {for (final e in planExtras.entries) e.key: List.of(e.value)},
        multi: multiPlan,
      );

  List<SavedPlan> get savedPlansLive => [
        for (final p in savedPlans) p.id == currentPlanId ? _snapshot(p.id, p.name) : p,
      ];

  void _storeCurrentPlan() {
    final i = savedPlans.indexWhere((p) => p.id == currentPlanId);
    if (i >= 0) savedPlans[i] = _snapshot(currentPlanId, savedPlans[i].name);
  }

  void savePlanAs(String name, {bool empty = false}) {
    final n = name.trim();
    if (n.isEmpty) return;
    _storeCurrentPlan();
    if (empty && currentPlanId.isEmpty && weeklyPlan.isNotEmpty) {
      final mine = 'p${DateTime.now().microsecondsSinceEpoch}-${_routineSeq++}';
      savedPlans.add(_snapshot(mine, t.planMine));
    }
    final id = 'p${DateTime.now().microsecondsSinceEpoch}-${_routineSeq++}';
    if (empty) {
      weeklyPlan.clear();
      planExtras.clear();
    }
    savedPlans.add(_snapshot(id, n));
    currentPlanId = id;
    _planChanged();
  }

  void switchPlan(String id) {
    if (id == currentPlanId) return;
    final i = savedPlans.indexWhere((p) => p.id == id);
    if (i < 0) return;
    _storeCurrentPlan();
    final p = savedPlans[i];
    weeklyPlan
      ..clear()
      ..addAll(p.week);
    planExtras
      ..clear()
      ..addAll({for (final e in p.extras.entries) e.key: List.of(e.value)});
    multiPlan = p.multi;
    currentPlanId = id;
    _planChanged();
  }

  void renamePlan(String id, String name) {
    final n = name.trim();
    final i = savedPlans.indexWhere((p) => p.id == id);
    if (i < 0 || n.isEmpty) return;
    savedPlans[i].name = n;
    _persist();
    notifyListeners();
  }

  void deletePlan(String id) {
    savedPlans.removeWhere((p) => p.id == id);
    if (currentPlanId == id) currentPlanId = '';
    _persist();
    notifyListeners();
  }

  void goRoutines() => pushRoute('routines');

  void goAiPlan() => pushRoute('ai-plan');

  void backFromAiPlan() => popRoute(fallback: 'routines');

  void backFromRoutines() => popRoute();

  Routine? _routine(String id) {
    for (final r in routines) {
      if (r.id == id) return r;
    }
    return null;
  }

  Routine? get activeRoutine => activeRoutineId == null ? null : _routine(activeRoutineId!);

  List<Exercise> routineExercises(Routine r) {
    final out = <Exercise>[];
    for (final id in r.exerciseIds) {
      final e = exerciseById(id);
      if (e != null) out.add(e);
    }
    return out;
  }

  Routine? get todayRoutine => routineOn(DateTime.now());

  DateTime? lastDoneOf(String routineId) {
    DateTime? last;
    for (final s in sessions) {
      if (s.routineId == routineId && (last == null || s.date.isAfter(last))) last = s.date;
    }
    return last;
  }

  List<Routine> get activeRoutines => [for (final r in routines) if (!r.archived) r];

  List<Routine> get archivedRoutines => [for (final r in routines) if (r.archived) r];

  bool showArchivedRoutines = false;

  void toggleArchivedRoutines() {
    showArchivedRoutines = !showArchivedRoutines;
    notifyListeners();
  }

  VoidCallback? archiveRoutine(String id, bool on) {
    final r = _routine(id);
    if (r == null || r.archived == on) return null;
    final week = {...weeklyPlan};
    final extras = {for (final e in planExtras.entries) e.key: [...e.value]};
    final moves = {for (final e in planMoves.entries) e.key: [...e.value]};
    final rotation = [...rotationIds];
    final next = rotationNextId;
    r.archived = on;
    if (on) _unplanRoutine(id);
    _persist();
    syncTrainReminder();
    notifyListeners();
    if (!on) return null;
    return () {
      r.archived = false;
      weeklyPlan
        ..clear()
        ..addAll(week);
      planExtras
        ..clear()
        ..addAll(extras);
      planMoves
        ..clear()
        ..addAll(moves);
      rotationIds
        ..clear()
        ..addAll(rotation);
      rotationNextId = next;
      _persist();
      syncTrainReminder();
      notifyListeners();
    };
  }

  List<Routine> get routinesByLastDone {
    final active = activeRoutines;
    final last = {for (final r in active) r.id: lastDoneOf(r.id)};
    final order = {for (final (i, r) in active.indexed) r.id: i};
    return [...active]..sort((a, b) {
        final la = last[a.id], lb = last[b.id];
        if (la != null && lb != null && la != lb) return lb.compareTo(la);
        if ((la == null) != (lb == null)) return la == null ? 1 : -1;
        return order[a.id]!.compareTo(order[b.id]!);
      });
  }

  List<String> planIdsOn(int weekday) => [
        ?weeklyPlan[weekday],
        if (multiPlan) ...?planExtras[weekday],
      ];

  // ---- 排期周期（Plan Cycle）----
  PlanCycle? cycleOf(String routineId) => planCycles[routineId];

  void setCycle(String routineId, PlanCycle c) {
    planCycles[routineId] = c;
    persistNow();
    notifyListeners();
  }

  void clearCycle(String routineId) {
    if (planCycles.remove(routineId) == null) return;
    persistNow();
    notifyListeners();
  }

  /// 续一轮：新周期从上一轮到期日接续，轮次 +1。
  void advanceCycle(String routineId) {
    final c = planCycles[routineId];
    if (c == null) return;
    planCycles[routineId] = c.nextRound();
    persistNow();
    notifyListeners();
  }

  /// 本轮已完成次数（自本轮起始日以来的该计划训练记录）。
  int cycleDoneSessions(String routineId) {
    final c = planCycles[routineId];
    if (c == null) return 0;
    return sessions
        .where((s) => s.routineId == routineId && !PlanCycle.dayOnly(s.day).isBefore(c.start))
        .length;
  }

  int cycleExpected(String routineId) {
    final c = planCycles[routineId];
    return c == null ? 0 : c.weeks * c.perWeek;
  }

  static String _moveKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<String> planIdsFor(DateTime day) => planMoves[_moveKey(day)] ?? planIdsOn(day.weekday);

  bool movedOn(DateTime day) => planMoves.containsKey(_moveKey(day));

  Routine? routineById(String id) => _routine(id);

  bool get rotating => rotation && rotationRoutines.isNotEmpty;

  List<Routine> get rotationRoutines => [for (final id in rotationIds) ?_routine(id)];

  static bool isRestStep(String id) => id.startsWith('rest-');

  List<String> get rotationSteps => [
        for (final id in rotationIds)
          if (isRestStep(id) || _routine(id) != null) id,
      ];

  ({int index, DateTime? rest}) get _rotationCursor {
    final steps = rotationSteps;
    if (rotationRoutines.isEmpty) return (index: 0, rest: null);
    var i = steps.indexOf(rotationNextId);
    if (i < 0) i = 0;
    if (!isRestStep(steps[i])) return (index: i, rest: null);
    final today = _dayKey(DateTime.now());
    var day = _dayKey(rotationRestDay ?? today);
    while (isRestStep(steps[i]) && day.isBefore(today)) {
      i = (i + 1) % steps.length;
      day = shiftDays(day, 1);
    }
    return (index: i, rest: isRestStep(steps[i]) ? day : null);
  }

  Routine? get rotationNext {
    if (rotationRoutines.isEmpty) return null;
    final c = _rotationCursor;
    return c.rest == null ? _routine(rotationSteps[c.index]) : null;
  }

  Routine? get rotationUpcoming {
    final steps = rotationSteps;
    if (rotationRoutines.isEmpty) return null;
    var i = _rotationCursor.index;
    while (isRestStep(steps[i])) {
      i = (i + 1) % steps.length;
    }
    return _routine(steps[i]);
  }

  int get rotationStep => rotationRoutines.isEmpty ? 0 : _rotationCursor.index;

  bool get restingToday => rotationRestOn(DateTime.now());

  bool rotationRestOn(DateTime day) {
    if (!rotating) return false;
    final key = _dayKey(day);
    if (key.isBefore(_dayKey(DateTime.now())) || sessions.any((s) => _dayKey(s.day) == key)) return false;
    return _rotationOn(day).isEmpty;
  }

  List<Routine> _rotationOn(DateTime day) {
    final key = _dayKey(day);
    final today = _dayKey(DateTime.now());
    final done = [
      for (final s in sessions)
        if (_dayKey(s.day) == key && s.routineId != null && rotationIds.contains(s.routineId)) ?_routine(s.routineId!),
    ];
    if (key.isBefore(today) || done.isNotEmpty) return done;
    final steps = rotationSteps;
    final c = _rotationCursor;
    var rest = c.rest;
    if (rest == null) return [?_routine(steps[c.index])];
    var i = c.index;
    while (isRestStep(steps[i])) {
      if (!key.isAfter(rest!)) return const [];
      i = (i + 1) % steps.length;
      rest = shiftDays(rest, 1);
    }
    return [?_routine(steps[i])];
  }

  @override
  bool hasPlanOn(DateTime day) => routinesOn(day).isNotEmpty;

  /// 当日计划：轮转开启时按轮转返回；否则用（含改期覆盖的）周日计划 + 周期（Plan Cycle）补入。
  List<Routine> routinesOn(DateTime day) {
    if (rotating) return _rotationOn(day);
    final ids = [...planIdsFor(day)];
    for (final e in planCycles.entries) {
      if (e.value.isTrainingDay(day) && !ids.contains(e.key)) ids.add(e.key);
    }
    // ISS-151：归档例程不得再被 planCycles 补入（否则永久占位、当日永远打不了勾）
    return [for (final id in ids) ?_routine(id)].where((r) => !r.archived).toList();
  }
  void setRotation(bool on) {
    if (rotation == on) return;
    rotation = on;
    if (on && rotationIds.isEmpty) {
      for (var d = 1; d <= 7; d++) {
        for (final id in planIdsOn(d)) {
          if (!rotationIds.contains(id) && _routine(id) != null) rotationIds.add(id);
        }
      }
      rotationNextId = rotationIds.isEmpty ? '' : rotationIds.first;
    }
    _planChanged();
  }

  void addRotationRest() {
    var n = 1;
    while (rotationIds.contains('rest-$n')) {
      n++;
    }
    rotationIds.add('rest-$n');
    _planChanged();
  }

  void removeRotationRest(String id) {
    final steps = rotationSteps;
    final i = steps.indexOf(id);
    if (i < 0 || !isRestStep(id)) return;
    _settleRotation();
    if (rotationNextId == id) _pointRotation(steps[(i + 1) % steps.length]);
    rotationIds.remove(id);
    _fixRotationNext();
    _planChanged();
  }

  void _settleRotation() {
    if (rotationRoutines.isEmpty) return;
    final c = _rotationCursor;
    rotationNextId = rotationSteps[c.index];
    rotationRestDay = c.rest;
  }

  void _pointRotation(String id, [DateTime? rest]) {
    rotationNextId = id;
    rotationRestDay = isRestStep(id) ? _dayKey(rest ?? DateTime.now()) : null;
  }

  void toggleRotationRoutine(String id) {
    if (_routine(id) == null) return;
    _settleRotation();
    if (rotationIds.remove(id)) {
      if (rotationNextId == id) rotationNextId = '';
    } else {
      rotationIds.add(id);
    }
    _fixRotationNext();
    _planChanged();
  }

  void reorderRotation(int from, int to) {
    if (from < 0 || from >= rotationIds.length) return;
    _settleRotation();
    if (to > from) to -= 1;
    rotationIds.insert(to.clamp(0, rotationIds.length), rotationIds.removeAt(from));
    _planChanged();
  }

  void setRotationNext(String id) {
    if (!rotationIds.contains(id)) return;
    _pointRotation(id);
    _planChanged();
  }

  void skipRotation() {
    final steps = rotationSteps;
    if (rotationRoutines.isEmpty) return;
    _pointRotation(steps[(_rotationCursor.index + 1) % steps.length]);
    _planChanged();
  }

  void restartRotation() {
    final steps = rotationSteps;
    if (rotationRoutines.isEmpty) return;
    _pointRotation(steps.first);
    _planChanged();
  }

  void _advanceRotation(String? routineId, DateTime on) {
    if (!rotation || routineId == null) return;
    final steps = rotationSteps;
    final i = steps.indexOf(routineId);
    if (i < 0) return;
    _pointRotation(steps[(i + 1) % steps.length], shiftDays(on, 1));
  }

  void _fixRotationNext() {
    rotationIds.removeWhere((id) => !isRestStep(id) && _routine(id) == null);
    if (rotationIds.contains(rotationNextId)) return;
    _pointRotation(rotationIds.isEmpty ? '' : rotationIds.first);
  }

  VoidCallback? moveRoutineDay(String routineId, DateTime from, DateTime to) {
    final source = _dayKey(from), target = _dayKey(to);
    if (source == target) return null;
    final left = [...planIdsFor(source)];
    if (!left.remove(routineId)) return null;
    final arrive = [...planIdsFor(target)];
    if (!arrive.contains(routineId)) arrive.add(routineId);
    final a = _moveKey(source), b = _moveKey(target);
    final before = {a: planMoves[a], b: planMoves[b]};
    planMoves[a] = left;
    planMoves[b] = arrive;
    _pruneMoves();
    _planChanged();
    return () {
      for (final e in before.entries) {
        final was = e.value;
        if (was == null) {
          planMoves.remove(e.key);
        } else {
          planMoves[e.key] = was;
        }
      }
      _planChanged();
    };
  }

  void undoMoves(DateTime day) {
    if (planMoves.remove(_moveKey(day)) == null) return;
    _planChanged();
  }

  void _pruneMoves() {
    final cutoff = _moveKey(_dayKey(DateTime.now()).subtract(const Duration(days: 14)));
    planMoves.removeWhere((k, _) => k.compareTo(cutoff) < 0);
  }

  void _planChanged() {
    _persist();
    _refreshWidgets();
    syncTrainReminder();
    notifyListeners();
  }

  bool plannedOn(int weekday, String routineId) => planIdsOn(weekday).contains(routineId);

  List<Routine> pendingRoutinesOn(DateTime day) {
    final left = routinesOn(day);
    final key = _dayKey(day);
    var free = 0;
    for (final s in sessions.where((s) => _dayKey(s.day) == key)) {
      final id = s.routineId;
      if (id == null) {
        free++;
      } else {
        final i = left.indexWhere((r) => r.id == id);
        if (i >= 0) left.removeAt(i);
      }
    }
    return left.sublist(math.min(free, left.length));
  }

  Routine? routineOn(DateTime day) {
    final list = routinesOn(day);
    if (list.isEmpty) return null;
    final pending = pendingRoutinesOn(day);
    return pending.isEmpty ? list.last : pending.first;
  }

  void toggleMultiPlan() {
    multiPlan = !multiPlan;
    _persist();
    _refreshWidgets();
    syncTrainReminder();
    notifyListeners();
  }

  void togglePlanDay(int weekday, String routineId) {
    if (!multiPlan) return assignRoutineToDay(weekday, plannedOn(weekday, routineId) ? null : routineId);
    final extras = planExtras.putIfAbsent(weekday, () => []);
    if (weeklyPlan[weekday] == routineId) {
      if (extras.isEmpty) {
        weeklyPlan.remove(weekday);
      } else {
        weeklyPlan[weekday] = extras.removeAt(0);
      }
    } else if (!extras.remove(routineId)) {
      if (weeklyPlan[weekday] == null) {
        weeklyPlan[weekday] = routineId;
      } else {
        extras.add(routineId);
      }
    }
    if (extras.isEmpty) planExtras.remove(weekday);
    _persist();
    _refreshWidgets();
    syncTrainReminder();
    notifyListeners();
  }

  String createRoutine([String name = '']) {
    final id = 'r${DateTime.now().microsecondsSinceEpoch}-${_routineSeq++}';
    routines.add(Routine(id, name.trim(), []));
    refreshAwards();
    _persist();
    notifyListeners();
    return id;
  }

  void renameRoutine(String id, String name) {
    final r = _routine(id);
    if (r == null) return;
    r.name = name.trim();
    _persist();
    notifyListeners();
  }

  List<String> get routineGroups {
    final out = <String>[];
    for (final r in activeRoutines) {
      if (r.group.isNotEmpty && !out.contains(r.group)) out.add(r.group);
    }
    return out;
  }

  List<Routine> routinesInGroup(String group) =>
      routines.where((r) => r.group == group && !r.archived).toList();

  void setRoutineGroup(String id, String group) {
    final r = _routine(id);
    if (r == null) return;
    r.group = group.trim();
    _persist();
    notifyListeners();
  }

  void setRoutineColor(String id, int color) {
    final r = _routine(id);
    if (r == null) return;
    r.color = color;
    _persist();
    notifyListeners();
  }

  String duplicateRoutine(String id) {
    final source = _routine(id);
    if (source == null) return '';
    final copy = createRoutine(t.copySuffix(routineTitle(source)));
    final made = _routine(copy)!;
    made.exerciseIds.addAll(source.exerciseIds);
    made.sets.addAll(source.sets);
    made.chained.addAll(source.chained);
    made.plan.addAll({for (final e in source.plan.entries) e.key: [...e.value]});
    made.rest.addAll(source.rest);
    made.group = source.group;
    made.color = source.color;
    // RISK-045/049：连计划配置一起复制，并为其建独立进度实例（克隆源当前值，不归零）
    if (source.prog.isNotEmpty) {
      made.prog.addAll({for (final e in source.prog.entries) e.key: e.value.copyWith()});
      final srcInst = source.progInst == null ? null : programStates[source.progInst!];
      final nid = 'pi${DateTime.now().millisecondsSinceEpoch}x${programStates.length}';
      final clone = ProgState(
        tpl: srcInst?.tpl ?? '',
        week: srcInst?.week ?? 0,
        lastAdv: srcInst?.lastAdv ?? 0,
      );
      if (srcInst != null) {
        clone.w.addAll(srcInst.w);
        clone.tm.addAll(srcInst.tm);
        clone.fails.addAll(srcInst.fails);
        clone.reps.addAll(srcInst.reps);
        clone.tmSet.addAll(srcInst.tmSet);
      }
      programStates[nid] = clone;
      made.progInst = nid;
    }
    _persist();
    notifyListeners();
    return copy;
  }

  void renameGroup(String from, String to) {
    final name = to.trim();
    for (final r in routines) {
      if (r.group == from) r.group = name;
    }
    _persist();
    notifyListeners();
  }

  void deleteGroup(String group) {
    for (final id in [for (final r in routinesInGroup(group)) r.id]) {
      _dropRoutine(id);
    }
    _persist();
    notifyListeners();
  }

  void deleteRoutine(String id) {
    _dropRoutine(id);
    _persist();
    notifyListeners();
  }

  void _dropRoutine(String id) {
    final doomedInst = _routine(id)?.progInst;
    _unplanRoutine(id);
    routines.removeWhere((r) => r.id == id);
    planCycles.remove(id);
    if (doomedInst != null && !routines.any((r) => r.progInst == doomedInst)) {
      programStates.remove(doomedInst);
    }
    _fixRotationNext();
    for (final p in savedPlans) {
      p.drop(id);
    }
  }

  void _unplanRoutine(String id) {
    final i = rotationIds.indexOf(id);
    if (i >= 0) {
      if (rotationNextId == id) _pointRotation(rotationIds[(i + 1) % rotationIds.length]);
      rotationIds.removeAt(i);
    }
    _fixRotationNext();
    weeklyPlan.removeWhere((_, v) => v == id);
    for (final extras in planExtras.values) {
      extras.remove(id);
    }
    planExtras.removeWhere((_, v) => v.isEmpty);
    for (final ids in planMoves.values) {
      ids.remove(id);
    }
    for (final day in [...planExtras.keys]) {
      if (weeklyPlan[day] != null) continue;
      final extras = planExtras[day]!;
      weeklyPlan[day] = extras.removeAt(0);
      if (extras.isEmpty) planExtras.remove(day);
    }
    if (activeRoutineId == id) activeRoutineId = null;
  }

  void toggleRoutineExercise(String routineId, String exId) {
    final r = _routine(routineId);
    if (r == null) return;
    if (r.exerciseIds.remove(exId)) {
      r.sets.remove(exId);
      r.plan.remove(exId);
      r.rest.remove(exId);
      r.chained.remove(exId);
      r.prog.remove(exId); // 计划周期：移除动作时清 ProgSpec，避免孤儿 spec 继续写 plan（ISS-153）
      // RISK-055：若该动作已从本实例的所有例程移除，清掉实例里的残留状态
      // （否则换走再换回会带着过期 TM/重量/失败数复活，且 tmSet 会压掉校准提示）
      if (r.progInst != null) _pruneInstState(r.progInst!, exId);
    } else {
      r.exerciseIds.add(exId);
    }
    _persist();
    notifyListeners();
  }

  void replaceRoutineExercise(String routineId, String from, String to) {
    final r = _routine(routineId);
    if (r == null) return;
    final at = r.exerciseIds.indexOf(from);
    if (at < 0 || r.exerciseIds.contains(to)) return;
    r.exerciseIds[at] = to;
    final sets = r.sets.remove(from);
    if (sets != null) r.sets[to] = sets;
    final plan = r.plan.remove(from);
    if (plan != null) r.plan[to] = [for (final p in plan) PlannedSet(kind: p.kind)];
    final rest = r.rest.remove(from);
    if (rest != null) r.rest[to] = rest;
    if (r.chained.remove(from)) r.chained.add(to);
    // ISS-155：连 prog 一并迁移（否则新动作失去计划驱动、旧 spec 变孤儿继续写 plan）
    final prog = r.prog.remove(from);
    if (prog != null) {
      r.prog[to] = prog;
      final inst = r.progInst == null ? null : programStates[r.progInst!];
      if (inst != null) {
        // ISS-158：渐进状态一同播种到新动作 id（否则 cycle TM 回落 40、linear 计划重量为空）
        final w = inst.w[from];
        if (w != null) inst.w[to] = w;
        final tm = inst.tm[from];
        if (tm != null) inst.tm[to] = tm;
        final fails = inst.fails[from];
        if (fails != null) inst.fails[to] = fails;
        final reps = inst.reps[from];
        if (reps != null) inst.reps[to] = reps;
        if (inst.tmSet.contains(from)) inst.tmSet.add(to);
        buildInitialPlan(r, to, prog, inst);
      }
    }
    // RISK-055：换走的旧动作若已不再被本实例任何例程引用，清掉它的残留状态
    if (r.progInst != null) _pruneInstState(r.progInst!, from);
    _persist();
    notifyListeners();
  }

  /// 计划引擎(prog)的步进：取该动作所属（非归档）例程的 spec.stepKg（首个匹配）。
  double? progStepOf(String exId) {
    for (final r in routines) {
      if (r.archived) continue;
      final spec = r.prog[exId];
      if (spec != null) return spec.stepKg;
    }
    return null;
  }

  /// 调计划的"步进"（改 spec.stepKg，与上游 progressStep 解耦——ISS-155）。
  void bumpProgStep(String exId, int dir) {
    var changed = false;
    for (final r in routines) {
      if (r.archived) continue;
      final spec = r.prog[exId];
      if (spec == null) continue;
      final cur = toDisplayWeight(spec.stepKg);
      final next = (cur + dir * weightStep / 2).clamp(weightStep / 2, weightStep * 8);
      r.prog[exId] = spec.copyWith(stepKg: fromDisplayWeight(next));
      // 步进只影响“后续推进”，无需重建当前 plan（改后下次完训生效）
      changed = true;
    }
    if (changed) {
      _persist();
      notifyListeners();
    }
  }

  /// 周期(cycle)动作的训练最大值(kg)；无则返回 null。
  double? progTmOf(String exId) {
    for (final r in routines) {
      if (r.archived) continue;
      final spec = r.prog[exId];
      if (spec == null || !spec.isCycle) continue;
      final inst = r.progInst == null ? null : programStates[r.progInst!];
      if (inst != null) return inst.tm[exId] ?? estimateTrainingMax(this, exId) ?? 40;
    }
    return null;
  }

  /// 该 TM 是否还是“自动估算/默认 40”（未被用户确认过）→ UI 提示偏低、可手调。
  bool progTmUnconfirmed(String exId) {
    for (final r in routines) {
      if (r.archived) continue;
      final spec = r.prog[exId];
      if (spec == null || !spec.isCycle) continue;
      final inst = r.progInst == null ? null : programStates[r.progInst!];
      if (inst == null) return true;
      // 已确认（用户手调过）→ 确定；否则回落旧启发式，兼容升级前无 tmSet 的老数据（ISS-160）
      if (inst.tmSet.contains(exId)) return false;
      final tm = inst.tm[exId];
      if (tm == null || tm == 40) return true;
      final est = estimateTrainingMax(this, exId);
      return est != null && (tm - est).abs() < 0.01;
    }
    return false;
  }

  /// 手调周期动作的训练最大值，并同步重建该动作在各家族例程里的周期 plan。
  void bumpProgTm(String exId, int dir) {
    var changed = false;
    for (final r in routines) {
      if (r.archived) continue;
      final spec = r.prog[exId];
      if (spec == null || !spec.isCycle) continue;
      final inst = r.progInst == null ? null : programStates[r.progInst!];
      if (inst == null) continue;
      final cur = toDisplayWeight(inst.tm[exId] ?? estimateTrainingMax(this, exId) ?? 40);
      final next = (cur + dir * weightStep).clamp(weightStep, weightStep * 40);
      inst.tm[exId] = fromDisplayWeight(next);
      inst.tmSet.add(exId); // 用户已确认过
      changed = true;
      rebuildCyclePlan(r, exId, spec, inst);
    }
    if (changed) {
      _persist();
      notifyListeners();
    }
  }

  VoidCallback? removeRoutineExercise(String routineId, String exId) {
    final r = _routine(routineId);
    if (r == null) return null;
    final at = r.exerciseIds.indexOf(exId);
    if (at < 0) return null;
    final sets = r.sets[exId];
    final plan = r.plan[exId];
    final rest = r.rest[exId];
    final chained = r.chained.contains(exId);
    final prog = r.prog[exId];
    // RISK-055：toggle 移除时可能清掉实例残留；撤销需一并还原（否则撤销就丢状态）
    final instId = r.progInst;
    final instBefore = instId == null ? null : programStates[instId];
    final snapW = instBefore?.w[exId];
    final snapTm = instBefore?.tm[exId];
    final snapFails = instBefore?.fails[exId];
    final snapReps = instBefore?.reps[exId];
    final snapTmSet = instBefore?.tmSet.contains(exId) ?? false;
    toggleRoutineExercise(routineId, exId);
    return () {
      final back = _routine(routineId);
      if (back == null || back.exerciseIds.contains(exId)) return;
      back.exerciseIds.insert(at.clamp(0, back.exerciseIds.length), exId);
      if (sets != null) back.sets[exId] = sets;
      if (plan != null) back.plan[exId] = plan;
      if (rest != null) back.rest[exId] = rest;
      if (chained) back.chained.add(exId);
      if (prog != null) back.prog[exId] = prog; // ISS-155：撤销一并恢复 ProgSpec
      // RISK-055：还原被清掉的实例状态
      final inst = instId == null ? null : programStates[instId];
      if (inst != null) {
        if (snapW != null) inst.w[exId] = snapW;
        if (snapTm != null) inst.tm[exId] = snapTm;
        if (snapFails != null) inst.fails[exId] = snapFails;
        if (snapReps != null) inst.reps[exId] = snapReps;
        if (snapTmSet) inst.tmSet.add(exId);
      }
      _persist();
      notifyListeners();
    };
  }

  /// RISK-055：动作已从某渐进实例(progInst)的所有（非归档）例程移除后，
  /// 清掉它在实例中的残留状态（工作重量/训练最大值/失败数/目标次数/已确认标记）。
  /// 不清的话：换走再换回（或加进同实例的别的例程）会带着过期状态复活，
  /// 残留的 tmSet 还会压掉「TM 偏低、建议校准」的提示。
  void _pruneInstState(String instId, String exId) {
    for (final r in routines) {
      if (r.archived || r.progInst != instId) continue;
      if (r.exerciseIds.contains(exId) || r.prog.containsKey(exId)) return; // 仍有用例在使用
    }
    final inst = programStates[instId];
    if (inst == null) return;
    inst.w.remove(exId);
    inst.tm.remove(exId);
    inst.fails.remove(exId);
    inst.reps.remove(exId);
    inst.tmSet.remove(exId);
  }

  int routineSets(Routine r, String exId) {
    final planned = r.plan[exId];
    if (planned != null && planned.isNotEmpty) {
      final working = planned.where((p) => p.kind != SetKind.warmup).length;
      return working == 0 ? planned.length : working;
    }
    return r.sets[exId] ?? (modeOf(exId) == 'cardio' ? 1 : kDefaultRoutineSets);
  }

  List<PlannedSet> plannedSets(Routine r, String exId) => r.plan[exId] ?? const [];

  int? routineRest(String? routineId, String exId) =>
      routineId == null ? null : _routine(routineId)?.rest[exId];

  void setRoutineRest(String routineId, String exId, int? seconds) {
    final r = _routine(routineId);
    if (r == null || !r.exerciseIds.contains(exId)) return;
    if (seconds == null) {
      r.rest.remove(exId);
    } else {
      r.rest[exId] = seconds <= 0 ? 0 : seconds.clamp(15, 600);
    }
    _persist();
    notifyListeners();
  }

  void setRoutineSetCount(String routineId, String exId, int n) {
    final r = _routine(routineId);
    if (r == null || !r.exerciseIds.contains(exId)) return;
    // RISK-051：prog 驱动时同步写 spec.sets，否则下次 rebuild 被恢复
    final spec = r.prog[exId];
    if (spec != null) {
      if (spec.isCycle) return; // 周期动作组数由周表决定，编辑无效 → 直接忽略
      for (final rr in routines) {
        if (rr.archived) continue;
        final sp = rr.prog[exId];
        if (sp == null) continue;
        final sp2 = sp.copyWith(sets: n.clamp(1, 12));
        rr.prog[exId] = sp2;
        final inst = rr.progInst == null ? null : programStates[rr.progInst!];
        if (sp2.isCycle) {
          if (inst != null) rebuildCyclePlan(rr, exId, sp2, inst);
        } else {
          rebuildSimplePlan(rr, exId, sp2);
        }
      }
    }
    r.sets[exId] = n.clamp(1, 12);
    _persist();
    notifyListeners();
  }

  bool hasPlan(Routine r, String exId) => r.plan[exId]?.isNotEmpty ?? false;

  void setPlannedSets(String routineId, String exId, List<PlannedSet> sets) {
    final r = _routine(routineId);
    if (r == null || !r.exerciseIds.contains(exId)) return;
    if (sets.isEmpty) {
      r.plan.remove(exId);
    } else {
      r.plan[exId] = List.unmodifiable(sets.take(20));
      r.sets[exId] = sets.where((p) => p.kind != SetKind.warmup).length.clamp(1, 20);
    }
    _persist();
    notifyListeners();
  }

  bool chainsToNext(Routine r, String exId) {
    final i = r.exerciseIds.indexOf(exId);
    return i >= 0 && i < r.exerciseIds.length - 1 && r.chained.contains(exId);
  }

  void toggleChain(String routineId, String exId) {
    final r = _routine(routineId);
    if (r == null) return;
    if (!r.chained.remove(exId)) r.chained.add(exId);
    _persist();
    notifyListeners();
  }

  void bumpRoutineSets(String routineId, String exId, int delta) {
    final r = _routine(routineId);
    if (r == null || !r.exerciseIds.contains(exId)) return;
    // RISK-050/051：prog 驱动的动作其组数写回 spec.sets（否则 rebuild 会抹掉，且 531 各组数不同会被“删组”误砍）
    final spec = r.prog[exId];
    if (spec != null) {
      if (spec.isCycle) return; // 周期动作组数由周表决定，编辑无效 → 直接忽略
      final n = (spec.sets + delta).clamp(1, 12);
      if (n != spec.sets) {
        for (final rr in routines) {
          if (rr.archived) continue;
          final sp = rr.prog[exId];
          if (sp == null) continue;
          final sp2 = sp.copyWith(sets: n);
          rr.prog[exId] = sp2;
          rr.sets[exId] = n;
          // 立刻重建 plan，否则下次开练仍按旧组数（改了不生效）
          final inst = rr.progInst == null ? null : programStates[rr.progInst!];
          if (sp2.isCycle) {
            if (inst != null) rebuildCyclePlan(rr, exId, sp2, inst);
          } else {
            rebuildSimplePlan(rr, exId, sp2);
          }
        }
        _persist();
        notifyListeners();
      }
      return;
    }
    final planned = r.plan[exId];
    if (planned != null && planned.isNotEmpty) {
      final next = [...planned];
      if (delta > 0) {
        for (var i = 0; i < delta && next.length < 20; i++) {
          next.add(next
              .lastWhere((s) => s.kind != SetKind.warmup, orElse: () => const PlannedSet())
              .copyWith(kind: SetKind.normal));
        }
      } else {
        for (var i = 0; i < -delta; i++) {
          final last = next.lastIndexWhere((s) => s.kind != SetKind.warmup);
          if (last < 0 || next.where((s) => s.kind != SetKind.warmup).length <= 1) break;
          next.removeAt(last);
        }
      }
      setPlannedSets(routineId, exId, next);
      return;
    }
    r.sets[exId] = (routineSets(r, exId) + delta).clamp(1, 12);
    _persist();
    notifyListeners();
  }

  bool routineHas(String routineId, String exId) => _routine(routineId)?.exerciseIds.contains(exId) ?? false;

  void reorderRoutineExercise(String routineId, int from, int to) {
    final ids = _routine(routineId)?.exerciseIds;
    if (ids == null || from < 0 || from >= ids.length) return;
    if (to > from) to -= 1;
    ids.insert(to.clamp(0, ids.length), ids.removeAt(from));
    persistNow();
    notifyListeners();
  }

  void assignRoutineToDay(int weekday, String? routineId) {
    planExtras.remove(weekday);
    if (routineId == null) {
      weeklyPlan.remove(weekday);
    } else {
      weeklyPlan[weekday] = routineId;
    }
    _persist();
    syncTrainReminder();
    notifyListeners();
  }

  void openRoutine(String id) {
    activeRoutineId = id;
    pushRoute('routine-edit');
  }

  void addToRoutineAndEdit(String? routineId, String exId) {
    final id = routineId ?? createRoutine();
    if (!routineHas(id, exId)) toggleRoutineExercise(id, exId);
    activeRoutineId = id;
    pushRoute('routine-edit');
  }

  int routinesWith(String exId) => routines.where((r) => r.exerciseIds.contains(exId)).length;

  String routineTitle(Routine r) => r.name.isEmpty ? t.newRoutineName : r.name;

  void closeRoutineEdit() => popRoute(fallback: 'routines');
}
