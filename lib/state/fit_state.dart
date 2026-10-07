import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show PlatformDispatcher;

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../catalog/exercise_catalog.dart';
import '../catalog/exercises_ext.dart';
import '../catalog/exercises_rep.dart';
import '../catalog/program_templates.dart';
import '../l10n/l10n.dart';
import '../models/exercise.dart';
import '../models/live_session.dart';
import '../models/measure.dart';
import '../models/note.dart';
import '../models/place.dart';
import '../models/profile.dart';
import '../models/progression.dart';
import '../models/progress_shot.dart';
import '../models/rehab_episode.dart';
import '../models/workout.dart';
import '../services/alarm_store.dart';
import '../services/beeper.dart';
import '../services/exercise_match.dart';
import '../services/local_store.dart';
import '../services/media_store.dart';
import '../services/merged_ids.dart';
import '../services/progress_reminder.dart';
import '../services/rehab_intake.dart';
import '../services/plan_share.dart';
import '../services/rest_alarm.dart';
import '../services/train_reminder.dart';
import '../services/workout_import.dart';

part 'awards_state.dart';
part 'fit_core.dart';
part 'library_state.dart';
part 'measures_state.dart';
part 'moments_state.dart';
part 'notes_state.dart';
part 'places_state.dart';
part 'progression_state.dart';
part 'rehab_state.dart';
part 'routines_state.dart';
part 'settings_state.dart';
part 'stats_state.dart';
part 'timeline_state.dart';
part 'tools_state.dart';
part 'workout_state.dart';

class FitState extends FitCore
    with ToolsState, LibraryState, SettingsState, NotesState, PlacesState, MeasuresState, MomentsState, TimelineState, StatsState, AwardsState, RoutinesState, WorkoutState, RehabState {
  void loadFromStore() {
    final data = withMergedExercises(Store.instance.load());
    _loading = true;
    if (data['rehabEp'] is List) {
      rehabEpisodes
        ..clear()
        ..addAll((data['rehabEp'] as List)
            .whereType<Map>()
            .map((m) => RehabEpisode.fromJson(m.cast<String, dynamic>())));
    }
    if (data['language'] == null) _adoptDeviceLanguage();
    if (data.isNotEmpty) {
      profile = Profile.fromJson((data['profile'] as Map?)?.cast<String, dynamic>() ?? {});
      if (const {'Athlete', 'Atleta', 'Name'}.contains(profile.name)) {
        profile.name = kDefaultName;
      }

      themePref = _themeFrom(data, fallback: 'dark');
      units = data['units'] as String? ?? 'kg';

      _applyLanguage(data['language'] as String? ?? language);
      restSeconds = (data['rest'] as num?)?.toInt() ?? 90;
      alarmSound = data['alarmSound'] as String?;
      alarmSoundName = data['alarmSoundName'] as String?;
      RestAlarm.instance.customSoundPath = alarmSoundPath;

      if (alarmSoundPath == null) {
        alarmSound = null;
        alarmSoundName = null;
      }
      bgPattern = data['bg'] as String? ?? 'dots';
      heatTone = data['heatTone'] as String? ?? 'ember';
      _loadToggles(data);
      alarmAskedAt = (data['alarmAskedAt'] as num?)?.toInt();
      onboarded = data['onboarded'] as bool? ?? false;
      favorites
        ..clear()
        ..addAll(((data['favorites'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, v as bool)));
      _loadNotes(data);
      _loadPlaces(data);
      checkins
        ..clear()
        ..addAll(((data['checkins'] as List?) ?? []).cast<String>());
      routines
        ..clear()
        ..addAll(((data['routines'] as List?) ?? [])
            .map((e) => Routine.fromJson((e as Map).cast<String, dynamic>())));
      weeklyPlan
        ..clear()
        ..addAll(((data['weeklyPlan'] as Map?) ?? {})
            .map((k, v) => MapEntry(int.parse(k as String), v as String)));
      _loadPlanExtras(data);
      customExercises
        ..clear()
        ..addAll(((data['custom'] as List?) ?? [])
            .map((e) => Exercise.fromJson((e as Map).cast<String, dynamic>())));
      _loadMedia(data);
      _loadRepsOnly(data);
      _loadExerciseRest(data);
      sessions
        ..clear()
        ..addAll(((data['sessions'] as List?) ?? [])
            .map((e) => LoggedSession.fromJson((e as Map).cast<String, dynamic>())));
      bodyweight
        ..clear()
        ..addAll(((data['bodyweight'] as List?) ?? [])
            .map((e) => BodyweightEntry.fromJson((e as Map).cast<String, dynamic>())));
      _loadMeasures(data);
      _loadShots(data);
      awards
        ..clear()
        ..addAll(((data['awards'] as Map?) ?? const {}).map((k, v) =>
            MapEntry(k as String, DateTime.tryParse(v as String? ?? '') ?? DateTime.now())));
      awardsSeen
        ..clear()
        ..addAll(((data['awardsSeen'] as List?) ?? const []).cast<String>());
      moments
        ..clear()
        ..addAll(((data['moments'] as List?) ?? const [])
            .map((e) => Moment.fromJson((e as Map).cast<String, dynamic>())));
      photoIntervalDays = (data['photoEvery'] as num?)?.toInt() ?? 30;
      bodyTimeline = data['bodyTl'] as bool? ?? false;
      _restoreLiveSession(data);
    }
    _stampMemberSince();
    _seedCalculatorsFromProfile();
    _loading = false;
    refreshAwards(silent: true);
    pendingAwards.clear();
    if (gamification) pendingAwards.addAll(unseenAwards);
    notifyListeners();
  }

  void _stampMemberSince() {
    if (profile.since != null) return;
    var first = DateTime.now();
    for (final s in sessions) {
      if (s.date.isBefore(first)) first = s.date;
    }
    profile.since = DateTime(first.year, first.month, first.day);
  }

  static String _themeFrom(Map<String, dynamic> data, {required String fallback}) {
    final pref = data['theme'];
    if (pref is String && const ['system', 'dark', 'light'].contains(pref)) return pref;
    final dark = data['dark'];
    if (dark is bool) return dark ? 'dark' : 'light';
    return fallback;
  }

  void _loadToggles(Map<String, dynamic> data) {
    demoSize = data['demo'] as String? ?? 'large';
    demoLoop = data['demoLoop'] as String? ?? 'always';
    alarmStyle = data['alarmStyle'] as String? ?? 'quiet';
    RestAlarm.instance.style = alarmStyle;
    Beeper.instance.loud = alarmStyle == 'loud';
    noSuggest
      ..clear()
      ..addAll(((data['noSuggest'] as List?) ?? const []).cast<String>());
    archived
      ..clear()
      ..addAll(((data['archived'] as List?) ?? const []).cast<String>());
    levelStay
      ..clear()
      ..addAll(((data['levelStay'] as List?) ?? const []).cast<String>());
    levelSeen
      ..clear()
      ..addAll(((data['levelSeen'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, (v as num).toInt())));
    exerciseGoals
      ..clear()
      ..addAll(((data['goals'] as Map?) ?? const {}).map((k, v) {
        final g = (v as Map).cast<String, dynamic>();
        final due = (g['d'] as num?)?.toInt();
        return MapEntry(k as String,
            (target: (g['t'] as num).toDouble(), due: due == null ? null : DateTime.fromMillisecondsSinceEpoch(due)));
      }));
    levelShown
      ..clear()
      ..addAll(((data['levelShown'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k as String, (v as List).map((x) => (x as num).toInt()).toList())));
    exerciseBar
      ..clear()
      ..addAll(((data['barKg'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k as String, (v as num).toDouble())));
    videoMarks
      ..clear()
      ..addAll(((data['marks'] as Map?) ?? const {}).map((k, v) => MapEntry(
            k as String,
            (v as Map).map((i, ms) => MapEntry(int.parse(i as String), (ms as num).toInt())),
          )));
    modeOverride
      ..clear()
      ..addAll(((data['exMode'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, v as String))
        ..removeWhere((_, v) => !const ['weight', 'cardio', 'time'].contains(v)));
    bgDim = (data['bgDim'] as num?)?.toDouble() ?? 0.55;
    showFocus = data['showFocus'] as bool? ?? true;
    showRecommended = data['showRecs'] as bool? ?? true;
    levelHints = data['levelHints'] as bool? ?? true;
    toastSound = data['toastSound'] as bool? ?? true;
    Beeper.instance.chimeOn = toastSound;
    heatmapLabels = data['heatLabels'] as bool? ?? true;
    multiPlan = data['multiPlan'] as bool? ?? false;
    final weekStart = data['weekStart'];
    weekStartDay = SettingsState.weekStarts.contains(weekStart) ? weekStart as int : DateTime.monday;
    autoAdvance = data['autoAdvance'] as bool? ?? true;
    keepScreenOn = data['keepAwake'] as bool? ?? true;
    startCountdown = data['countdown'] as bool? ?? true;
    gamification = data['gamify'] as bool? ?? true;
    logRpe = data['rpe'] as bool? ?? false;
    effortScale = data['effort'] == 'rir' ? 'rir' : 'rpe';
    trainReminderMin = (data['trainAt'] as num?)?.toInt();
    smartReminder = data['trainSmart'] as bool? ?? false;
    progressStep
      ..clear()
      ..addAll(((data['progress'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k as String, (v as num).toDouble())));
    autoWarmup
      ..clear()
      ..addAll(((data['warmup'] as List?) ?? const []).cast<String>());
    programStates
      ..clear()
      ..addAll(((data['progStates'] as Map?) ?? const {}).map((k, v) =>
          MapEntry(k as String, ProgState.fromJson((v as Map).cast<String, dynamic>()))));
  }

  void _loadPlanExtras(Map<String, dynamic> data) {
    planExtras
      ..clear()
      ..addAll(((data['planExtras'] as Map?) ?? const {}).map((k, v) => MapEntry(
            int.parse(k as String),
            (v as List).cast<String>().where((id) => id != weeklyPlan[int.parse(k)]).toList(),
          )))
      ..removeWhere((_, v) => v.isEmpty);
  }

  void _restoreLiveSession(Map<String, dynamic> data) {
    final live = data['live'] as Map?;
    if (live == null) return;
    session = WorkoutSession.fromJson(live.cast<String, dynamic>());
    _elapsedBefore = (data['liveElapsed'] as num?)?.toInt() ?? 0;
    sessionPaused = data['livePaused'] as bool? ?? false;
    final started = data['liveStart'] as String?;
    if (sessionPaused || started == null) {
      _runningSince = null;
    } else {
      _runningSince = DateTime.tryParse(started);
      _startTicking(from: _runningSince);
    }
    if (!sessionPaused) syncRest();
    resetRoute('session');
  }

  void _loadMedia(Map<String, dynamic> data, {Map<String, String>? restored}) {
    exerciseMedia.clear();
    if (restored != null) {
      exerciseMedia.addAll(restored);
      return;
    }
    ((data['media'] as Map?) ?? {}).forEach((k, v) {
      if (v is String && v.isNotEmpty) exerciseMedia[k as String] = v;
    });
    for (final e in (data['custom'] as List?) ?? const []) {
      final legacy = (e as Map)['m'];
      final id = e['id'];
      if (id is String && legacy is String && legacy.isNotEmpty) {
        exerciseMedia.putIfAbsent(id, () => legacy);
      }
    }
  }

  void _loadExerciseRest(Map<String, dynamic> data) {
    exerciseRest.clear();
    ((data['exRest'] as Map?) ?? const {}).forEach((k, v) {
      final n = (v as num?)?.toInt();
      if (k is String && n != null) exerciseRest[k] = n <= 0 ? 0 : n.clamp(15, 600);
    });
  }

  void _loadRepsOnly(Map<String, dynamic> data) {
    repsOnly
      ..clear()
      ..addAll(((data['repsOnly'] as List?) ?? const []).cast<String>());
    repsOnlyOff
      ..clear()
      ..addAll(((data['repsOnlyOff'] as List?) ?? const []).cast<String>());
  }

  void _loadShots(Map<String, dynamic> data, {Map<String, String>? restored}) {
    shots
      ..clear()
      ..addAll(((data['shots'] as List?) ?? const [])
          .map((e) => ProgressEntry.fromJson((e as Map).cast<String, dynamic>()))
          .where((e) => !e.isEmpty));
    if (restored == null) return;
    for (var i = 0; i < shots.length; i++) {
      final e = shots[i];
      final kept = <String, String>{};
      e.shots.forEach((pose, name) {
        final now = restored[name];
        if (now != null) kept[pose] = now;
      });
      shots[i] = e.copyWith(shots: kept);
    }
    shots.removeWhere((e) => e.isEmpty);
  }

  void _loadMeasures(Map<String, dynamic> data) {
    measures
      ..clear()
      ..addAll(((data['measures'] as List?) ?? const [])
          .map((e) => BodyMeasure.fromJson((e as Map).cast<String, dynamic>()))
          .where((m) => kMeasureKeys.contains(m.key)));
  }

  void _loadPlaces(Map<String, dynamic> data) {
    places.clear();
    final raw = data['places'];
    if (raw is List) {
      places.addAll(raw.map((e) => GymPlace.fromJson((e as Map).cast<String, dynamic>())));
    }
    activePlaceId = data['place'] as String? ?? '';
    if (places.every((p) => p.id != activePlaceId)) activePlaceId = '';
  }

  void _loadNotes(Map<String, dynamic> data) {
    notes.clear();
    final raw = data['notes'];
    if (raw is List) {
      notes.addAll(raw.map((e) => GymNote.fromJson((e as Map).cast<String, dynamic>())));
      return;
    }

    var seq = 0;
    GymNote legacy(String exId, DateTime when, String text) => GymNote(
          id: 'n${when.microsecondsSinceEpoch}${seq++}',
          exerciseId: exId,
          date: _dayKey(when),
          kind: NoteKind.note,
          text: text,
          createdAt: when,
        );

    (data['exNotes'] as Map?)?.forEach((k, v) {
      for (final e in (v as List)) {
        final m = (e as Map).cast<String, dynamic>();
        final text = ((m['t'] ?? '') as String).trim();
        if (text.isEmpty) continue;
        notes.add(legacy(
            k as String, DateTime.tryParse((m['d'] ?? '') as String) ?? DateTime.now(), text));
      }
    });
    if (raw is Map) {
      raw.forEach((k, v) {
        final text = (v as String).trim();
        if (text.isNotEmpty) notes.add(legacy(k as String, DateTime.now(), text));
      });
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        'profile': profile.toJson(),
        'dark': dark,
        'theme': themePref,
        'units': units,
        'language': language,
        'rest': restSeconds,
        'alarmSound': alarmSound,
        'alarmSoundName': alarmSoundName,
        'bg': bgPattern,
        'heatTone': heatTone,
        'bgDim': bgDim,
        'showFocus': showFocus,
        'showRecs': showRecommended,
        'levelHints': levelHints,
        'toastSound': toastSound,
        'heatLabels': heatmapLabels,
        'weekStart': weekStartDay,
        'autoAdvance': autoAdvance,
        'keepAwake': keepScreenOn,
        'countdown': startCountdown,
        'gamify': gamification,
        'rpe': logRpe,
        'effort': effortScale,
        'demo': demoSize,
        'demoLoop': demoLoop,
        'alarmStyle': alarmStyle,
        'noSuggest': noSuggest.toList(),
        'archived': archived.toList(),
        'levelStay': levelStay.toList(),
        'levelSeen': Map.of(levelSeen),
        'levelShown': Map.of(levelShown),
        'goals': exerciseGoals.map((k, g) => MapEntry(k, {'t': g.target, if (g.due != null) 'd': g.due!.millisecondsSinceEpoch})),
        'barKg': exerciseBar,
        'marks': videoMarks.map((k, v) => MapEntry(k, v.map((i, ms) => MapEntry('$i', ms)))),
        'exMode': modeOverride,
        'trainAt': trainReminderMin,
        'trainSmart': smartReminder,
        'alarmAskedAt': alarmAskedAt,
        'onboarded': onboarded,
        'favorites': favorites,
        'notes': notes.map((n) => n.toJson()).toList(),
        'rehabEp': rehabEpisodes.map((e) => e.toJson()).toList(),
        'places': places.map((p) => p.toJson()).toList(),
        'place': activePlaceId,
        'checkins': checkins.toList(),
        'routines': routines.map((r) => r.toJson()).toList(),
        'weeklyPlan': weeklyPlan.map((k, v) => MapEntry(k.toString(), v)),
        'planExtras': planExtras.map((k, v) => MapEntry(k.toString(), v)),
        'multiPlan': multiPlan,
        'custom': customExercises.map((e) => e.toJson()).toList(),
        'media': exerciseMedia,
        'exRest': exerciseRest,
        'progress': progressStep,
        'progStates': programStates.map((k, v) => MapEntry(k, v.toJson())),
        'warmup': autoWarmup.toList(),
        'repsOnly': repsOnly.toList(),
        'repsOnlyOff': repsOnlyOff.toList(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'bodyweight': bodyweight.map((b) => b.toJson()).toList(),
        'measures': measures.map((m) => m.toJson()).toList(),
        'shots': shots.map((s) => s.toJson()).toList(),
        'awards': awards.map((k, v) => MapEntry(k, v.toIso8601String())),
        'awardsSeen': awardsSeen.toList(),
        'moments': moments.map((m) => m.toJson()).toList(),
        'photoEvery': photoIntervalDays,
        'bodyTl': bodyTimeline,
        if (session != null && !session!.complete) ...{
          'live': session!.toJson(),
          'liveStart': _runningSince?.toIso8601String(),
          'liveElapsed': _elapsedBefore,
          'livePaused': sessionPaused,
        },
      };

  void resetAllData() {
    _saveDebounce?.cancel();
    _sessionTimer?.cancel();
    _restTimer?.cancel();
    RestAlarm.instance.cancel();
    ProgressReminder.instance.cancel();
    session = null;
    _runningSince = null;
    _elapsedBefore = 0;
    sessionPaused = false;
    sessions.clear();
    bodyweight.clear();
    measures.clear();
    shots.clear();
    compareFromId = null;
    compareToId = null;
    notes.clear();
    moments.clear();
    awards.clear();
    awardsSeen.clear();
    pendingAwards.clear();
    places.clear();
    activePlaceId = '';
    checkins.clear();
    routines.clear();
    weeklyPlan.clear();
    planExtras.clear();
    multiPlan = false;
    customExercises.clear();
    exerciseMedia.clear();
    repsOnly.clear();
    repsOnlyOff.clear();
    exerciseRest.clear();
    progressStep.clear();
    programStates.clear();
    progFeedback = [];
    autoWarmup.clear();
    noSuggest.clear();
    archived.clear();
    levelStay.clear();
    levelSeen.clear();
    levelShown.clear();
    exerciseGoals.clear();
    videoMarks.clear();
    exerciseBar.clear();
    modeOverride.clear();
    demoSize = 'large';
    demoLoop = 'always';
    MediaStore.clearAll();
    favorites.clear();
    sessionPicks.clear();
    selectedMuscles.clear();
    profile = Profile();
    showFocus = true;
    showRecommended = true;
    levelHints = true;
    toastSound = true;
    Beeper.instance.chimeOn = true;
    heatmapLabels = true;
    weekStartDay = DateTime.monday;
    autoAdvance = true;
    startCountdown = true;
    gamification = true;
    logRpe = false;
    effortScale = 'rpe';
    trainReminderMin = null;
    smartReminder = false;
    TrainReminder.instance.cancel();
    onboarded = false;
    strengthExerciseId = null;
    _photoBytes = null;
    _photoCacheKey = null;
    _bannerBytes = null;
    _bannerCacheKey = null;
    _seedCalculatorsFromProfile();
    resetRoute('home');
    trainStep = 'select';
    persistNow();
    _refreshWidgets();
    notifyListeners();
  }

  String exportJson() => Store.instance.exportJson(toJson());

  String exportCsv() => Store.instance.exportCsv(sessions);

  bool importJson(String raw) {
    final map = Store.instance.tryParse(raw);
    if (map == null) return false;
    applyBackup(map);
    return true;
  }

  void applyBackup(Map<String, dynamic> backup,
      {Map<String, String>? restoredMedia,
      Map<String, String>? restoredNoteMedia,
      Map<String, String>? restoredShots,
      Map<String, String>? restoredMoments}) {
    final map = withMergedExercises(backup);
    if (restoredMedia != null) restoredMedia = withMergedExercises(restoredMedia).cast<String, String>();
    _loading = true;
    profile = Profile.fromJson((map['profile'] as Map?)?.cast<String, dynamic>() ?? {});
    themePref = _themeFrom(map, fallback: themePref);
    units = map['units'] as String? ?? units;
    _applyLanguage(map['language'] as String? ?? language);
    restSeconds = (map['rest'] as num?)?.toInt() ?? restSeconds;
    bgPattern = map['bg'] as String? ?? bgPattern;
    heatTone = map['heatTone'] as String? ?? heatTone;
    _loadToggles(map);
    onboarded = map['onboarded'] as bool? ?? onboarded;
    favorites
      ..clear()
      ..addAll(((map['favorites'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, v as bool)));
    _loadPlaces(map);
    _loadNotes(map);
    if (restoredNoteMedia != null) _remapNoteMedia(restoredNoteMedia);
    checkins
      ..clear()
      ..addAll(((map['checkins'] as List?) ?? []).cast<String>());
    routines
      ..clear()
      ..addAll(((map['routines'] as List?) ?? [])
          .map((e) => Routine.fromJson((e as Map).cast<String, dynamic>())));
    weeklyPlan
      ..clear()
      ..addAll(((map['weeklyPlan'] as Map?) ?? {})
          .map((k, v) => MapEntry(int.parse(k as String), v as String)));
    _loadPlanExtras(map);
    customExercises
      ..clear()
      ..addAll(((map['custom'] as List?) ?? [])
          .map((e) => Exercise.fromJson((e as Map).cast<String, dynamic>())));
    _loadMedia(map, restored: restoredMedia);
    _loadRepsOnly(map);
    _loadExerciseRest(map);
    sessions
      ..clear()
      ..addAll(((map['sessions'] as List?) ?? [])
          .map((e) => LoggedSession.fromJson((e as Map).cast<String, dynamic>())));
    bodyweight
      ..clear()
      ..addAll(((map['bodyweight'] as List?) ?? [])
          .map((e) => BodyweightEntry.fromJson((e as Map).cast<String, dynamic>())));
    _loadMeasures(map);
    _loadShots(map, restored: restoredShots);
    _loadAwards(map);
    _loadMoments(map, restored: restoredMoments);
    photoIntervalDays = (map['photoEvery'] as num?)?.toInt() ?? photoIntervalDays;
    bodyTimeline = map['bodyTl'] as bool? ?? bodyTimeline;
    _seedCalculatorsFromProfile();
    _loading = false;
    _persist();
    syncTrainReminder();
    syncPhotoReminder();
    _refreshWidgets();
    notifyListeners();
  }

  void _loadAwards(Map<String, dynamic> map) {
    awards
      ..clear()
      ..addAll(((map['awards'] as Map?) ?? const {}).map((k, v) =>
          MapEntry(k as String, DateTime.tryParse(v as String? ?? '') ?? DateTime.now())));
    awardsSeen
      ..clear()
      ..addAll(((map['awardsSeen'] as List?) ?? const []).cast<String>());
    pendingAwards.clear();
  }

  void _loadMoments(Map<String, dynamic> map, {Map<String, String>? restored}) {
    moments
      ..clear()
      ..addAll(((map['moments'] as List?) ?? const [])
          .map((e) => Moment.fromJson((e as Map).cast<String, dynamic>()))
          .map((m) => restored == null
              ? m
              : Moment(m.date, restored[m.file] ?? m.file, note: m.note))
          .where((m) => m.file.isNotEmpty));
  }

  void _remapNoteMedia(Map<String, String> restored) {
    for (var i = 0; i < notes.length; i++) {
      final n = notes[i];
      if (n.media.isEmpty) continue;
      final kept = [
        for (final m in n.media)
          if (restored[m] != null) restored[m]!,
      ];
      notes[i] = n.copyWith(media: kept);
    }
  }

  static String _normName(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  @override
  void syncTrainReminder() {
    if (trainReminderMin == null) {
      TrainReminder.instance.cancel();
      return;
    }
    TrainReminder.instance.schedule(
      minuteOfDay: reminderMinute,
      weekdays: reminderWeekdays,
      skipToday: trainedToday,
    );
  }

  int get reminderMinute =>
      (smartReminder ? usualStartMinute : null) ?? trainReminderMin ?? 19 * 60;

  Set<int> get reminderWeekdays {
    if (smartReminder) {
      final days = usualWeekdays;
      if (days.isNotEmpty) return days.toSet();
    }
    return weeklyPlan.keys.toSet();
  }

  Exercise? matchExerciseByName(String name) => matchExercise(name, allExercises);

  int applyTemplate(ProgramTemplate template, {Map<String, double>? tm}) {
    final planWasEmpty = weeklyPlan.isEmpty;
    var made = 0;
    final instId = 'pi${DateTime.now().millisecondsSinceEpoch}';
    final inst = ProgState(tpl: template.id);
    final sameDay = <String, String>{};
    for (final day in template.days) {
      final matched = <String, ProgramExercise>{};
      for (final pe in day.exercises) {
        final ex = matchExerciseByName(pe.name);
        if (ex == null || matched.containsKey(ex.id)) continue;
        matched[ex.id] = pe;
      }
      if (matched.isEmpty) continue;
      final key = '${day.name}|${matched.entries.map((e) => '${e.key}:${e.value.sets}').join(',')}';
      final twin = sameDay[key];
      if (twin != null) {
        if (planWasEmpty && day.weekday != null) weeklyPlan[day.weekday!] = twin;
        continue;
      }
      final id = createRoutine(day.name);
      sameDay[key] = id;
      setRoutineGroup(id, template.name);
      final r = _routine(id)!;
      if (template.pro) r.progInst = instId;
      for (final entry in matched.entries) {
        final exId = entry.key;
        final pe = entry.value;
        toggleRoutineExercise(id, exId);
        final spec = pe.spec;
        if (spec == null) {
          bumpRoutineSets(id, exId, pe.sets - kDefaultRoutineSets);
          continue;
        }
        r.prog[exId] = spec;
        if (spec.kind == ProgKind.reps) repsOnly.add(exId);
        if (spec.isCycle) {
          inst.tm[exId] =
              tm?[pe.name] ?? estimateTrainingMax(this, exId) ?? 40;
        }
        buildInitialPlan(r, exId, spec, inst);
      }
      if (planWasEmpty && day.weekday != null) weeklyPlan[day.weekday!] = id;
      made++;
    }
    if (made == 0) return 0;
    if (template.pro) programStates[instId] = inst;
    persistNow();
    syncTrainReminder();
    notifyListeners();
    return made;
  }

  static const planTemplate = '{\n'
      '  "program": "Upper Lower",\n'
      '  "unit": "kg",\n'
      '  "routines": [\n'
      '    {\n'
      '      "name": "Upper A",\n'
      '      "days": ["Monday", "Thursday"],\n'
      '      "exercises": [\n'
      '        {"name": "Barbell Bench Press", "sets": 4, "reps": 8, "weight": 60, "rest": 120,\n'
      '         "plan": [{"type": "warmup", "reps": 10, "weight": 30}]},\n'
      '        {"name": "Barbell Bent Over Row", "sets": 4, "reps": 8, "superset": true},\n'
      '        {"name": "Dumbbell Biceps Curl", "sets": 3, "reps": 12}\n'
      '      ]\n'
      '    }\n'
      '  ]\n'
      '}';

  static const planWeeksTemplate = '{"program": "12 weeks", "weeks": [\n'
      '  {"name": "Week 1", "routines": [{"name": "Day A", "exercises": [{"name": "Barbell Full Squat", "sets": 3, "reps": 8}]}]},\n'
      '  {"name": "Week 2", "routines": [{"name": "Day A", "exercises": [{"name": "Barbell Full Squat", "sets": 4, "reps": 8}]}]}\n'
      ']}';

  String planRequestText() {
    final here = allExercises.where((e) => fitsHere(e) && !isArchived(e.id)).toList();
    final month = DateTime.now().subtract(const Duration(days: 30));
    final recent = sessions.where((s) => s.date.isAfter(month)).length;
    final records = personalRecords.take(5).toList();
    final lines = <String>[
      'GymMane · ${activePlace?.name ?? t.placeAll}',
      t.planAboutMe,
      '- ${t.planBody(profile.sex == 'female' ? t.female : t.male, profile.age, heightLabel(profile.heightCm), weightLabel(profile.weightKg))}',
      '- ${t.planDays(weeklyTarget)}',
      if (sessions.isEmpty) '- ${t.planNoHistory}' else '- ${t.planHistory(recent)}',
      if (records.isNotEmpty) '- ${t.planBestLifts}: ${records.map((r) => '${r.name} ${recordLabel(r)}').join('; ')}',
      t.planAskFirst,
      '',
      t.planIntro,
      t.planFormat,
      planTemplate,
      t.planFormatNotes,
      planWeeksTemplate,
      '',
    ];
    for (final ex in here) {
      final local = exerciseName(ex);
      final label = local == ex.name ? ex.name : '${ex.name} ($local)';
      final mode = modeOf(ex.id);
      lines.add('$label | ${ex.primary} | ${ex.equipment} | ${ex.difficulty}${mode.isEmpty ? '' : ' | $mode'}');
    }
    return lines.join('\n');
  }

  ({int added, List<String> missed, bool readable}) importPlan(String raw, {bool schedule = false}) {
    final plans = parsePlan(raw);
    if (plans.isEmpty) return (added: 0, missed: const [], readable: false);
    final result = applyPlan(plans, schedule: schedule);
    return (added: result.added, missed: result.missed, readable: true);
  }

  Exercise? _planExercise(PlanItem item, {bool create = false}) {
    final byId = item.id == null ? null : exerciseById(item.id!);
    if (byId != null && (item.name.isEmpty || !isCustom(byId.id) || byId.name == item.name)) return byId;
    final byName = matchExerciseByName(item.name);
    if (byName != null) return byName;
    if (!create || (item.muscle ?? '').isEmpty) return null;
    final muscle = kMuscles.any((m) => m.id == item.muscle) ? item.muscle! : 'chest';
    final gear = kEquipment.contains(item.equipment) ? item.equipment! : 'Other';
    final level = kDifficulties.contains(item.level) ? item.level! : 'Beginner';
    final id = addCustomExercise(
        name: item.name,
        primary: muscle,
        equipment: gear,
        difficulty: level,
        steps: item.steps,
        mode: item.mode,
        secondary: item.secondary);
    return exerciseById(id);
  }

  ({int routines, int added, List<String> missed}) previewPlan(List<PlanRoutine> plans) {
    var made = 0, added = 0;
    final missed = <String>[];
    for (final plan in plans) {
      var found = 0;
      for (final item in plan.items) {
        final known = _planExercise(item) != null || (item.muscle ?? '').isNotEmpty;
        if (known) {
          found++;
        } else if (!missed.contains(item.name)) {
          missed.add(item.name);
        }
      }
      if (found > 0) made++;
      added += found;
    }
    return (routines: made, added: added, missed: missed);
  }

  bool _sameRoutine(Routine r, String name, List<String> ids) =>
      r.name.trim().toLowerCase() == name.trim().toLowerCase() &&
      r.exerciseIds.length == ids.length &&
      [for (var i = 0; i < ids.length; i++) r.exerciseIds[i] == ids[i]].every((x) => x);

  ({int routines, int added, List<String> missed}) applyPlan(List<PlanRoutine> plans,
      {bool schedule = false}) {
    var made = 0, added = 0;
    final missed = <String>[];
    for (final plan in plans) {
      final picked = <(Exercise, PlanItem)>[];
      for (final item in plan.items) {
        final ex = _planExercise(item, create: true);
        if (ex == null) {
          if (!missed.contains(item.name)) missed.add(item.name);
          continue;
        }
        if (picked.any((p) => p.$1.id == ex.id)) continue;
        picked.add((ex, item));
      }
      if (picked.isEmpty) continue;
      final name = plan.name.isEmpty ? t.newRoutineName : plan.name;
      final ids = [for (final p in picked) p.$1.id];
      final existing = routines.where((r) => _sameRoutine(r, name, ids) && r.group == plan.group).firstOrNull;
      final id = existing?.id ?? createRoutine(name);
      if (existing == null) {
        setRoutineGroup(id, plan.group);
        for (final (ex, item) in picked) {
          toggleRoutineExercise(id, ex.id);
          final sets = _plannedFrom(item);
          if (sets.isNotEmpty) {
            setPlannedSets(id, ex.id, sets);
          } else if (item.sets != null) {
            setRoutineSetCount(id, ex.id, item.sets!);
          }
          if (item.superset) toggleChain(id, ex.id);
          final rest = item.restSec;
          if (rest != null) setRoutineRest(id, ex.id, rest);
        }
        made++;
        added += picked.length;
      }
      if (schedule) {
        for (final d in plan.days) {
          weeklyPlan[d] = id;
        }
      }
    }
    if (added > 0 || schedule) {
      persistNow();
      syncTrainReminder();
      notifyListeners();
    }
    return (routines: made, added: added, missed: missed);
  }

  // ---- 康复档案：提示词 + 回复套用（放在 FitState 里，用得到目录/计划引擎）----

  /// 生成给通用 AI 的康复提示词（手动复制/导出，App 不联网）。
  String rehabPromptText(RehabEpisode ep) {
    final month = DateTime.now().subtract(const Duration(days: 30));
    final recent = sessions.where((s) => s.date.isAfter(month)).length;
    final goals = ep.goals.map(rehabGoalLabel).join('、');
    final gear = ep.equipment.isEmpty ? t.rehabGearBodyweight : ep.equipment.join('、');
    final flags = ep.redFlags.map((k) => t.rehabRedFlag(k)).join('；');
    final linked = routines.where((r) => ep.routineIds.contains(r.id)).toList();
    final feedback = rehabFeedbackSessions();
    final lines = <String>[
      '你是运动康复方向的助理。请根据下面的个人情况、当前计划和近期训练反馈，给出一份循序渐进、可以自己执行的康复训练建议；已有计划时，直接对当前计划做调整。',
      '',
      '【我的情况】',
      '- 性别/年龄/身高/体重：${profile.sex == 'female' ? '女' : '男'}、${profile.age} 岁、${heightLabel(profile.heightCm)}、${weightLabel(profile.weightKg)}',
      '- 近 30 天训练次数：$recent 次',
      '- 每周可训练天数：${ep.daysPerWeek} 天',
      '- 可用器材：$gear',
      if (goals.isNotEmpty) '- 康复目标：$goals',
      '',
      '【本次困扰】',
      '- 部位：${rehabAreaLabel(ep.area)}',
      '- 病程：${rehabDurationLabel(ep.duration)}',
      '- 当前不适程度：${ep.pain}/10',
      if (ep.factors.trim().isNotEmpty) '- 加重 / 缓解因素：${ep.factors.trim()}',
      if (flags.isEmpty) '- 安全筛查：未发现红旗征' else '- 安全筛查命中：$flags',
      '',
      '【当前计划】',
      if (linked.isEmpty) '暂无计划（请按输出要求用 routines 字段新建）' else exportPlanJson(linked, withSchedule: false),
      '',
      '【近期训练反馈】',
      if (feedback.isEmpty)
        '无训练反馈记录'
      else
        for (final s in feedback) rehabFeedbackLine(s),
      '',
      '【输出要求】',
      '1. 只输出一个 JSON 对象，不要额外解释文字。',
      '2. 用 advice 字段写「注意事项 + 叫停规则」（字符串）。',
      '3. 【当前计划】为空时，用 routines 字段给整套新计划，结构照抄下面模板：',
      FitState.planTemplate,
      '4. 【当前计划】非空时，用 adjust 数组给「对当前计划的修改指令」（不需要修改就给空数组 []），结构照抄：',
      '[{"action":"set","routine":"康复 A","exercise":"动作英文名","field":"weight","value":45},',
      ' {"action":"set","exercise":"动作英文名","field":"sets","value":3},',
      ' {"action":"remove","exercise":"动作英文名"},',
      ' {"action":"add","routine":"康复 A","exercise":"动作英文名","sets":3,"reps":12}]',
      '   - set：field 只允许 weight / sets / reps / rest 四种；value 是目标新值。',
      '   - remove：把该动作从计划里删掉。',
      '   - add：往计划里加动作，可带 sets / reps / weight。',
      '   - routine 可省略（省略 = 应用到全部当前计划）。',
      '5. 动作名尽量取自【动作库清单】里的英文名，这样能自动匹配到 App 的动作库。',
      '6. 强度保守：以不加重症状为前提，训练中疼痛不超过 3/10；先活动度、再稳定性、最后力量。',
      '7. advice 里必须包含：${t.rehabStopRules}',
      '8. 未通过安全门时，只给 advice，routines 与 adjust 都不要输出。',
      '',
      '【动作库清单】英文名 (中文名) | 肌群 | 器材 | 难度 | 模式',
    ];
    final pool = allExercises.where((e) => fitsHere(e) && !isArchived(e.id)).toList();
    for (final ex in pool) {
      final local = exerciseName(ex);
      final label = local == ex.name ? ex.name : '${ex.name} ($local)';
      final mode = modeOf(ex.id);
      lines.add('$label | ${ex.primary} | ${ex.equipment} | ${ex.difficulty}${mode.isEmpty ? '' : ' | $mode'}');
    }
    return lines.join('\n');
  }

  /// 近期训练反馈：近 [days] 天内带反馈的记录（按时间新→旧）；
  /// 若一条都没有，回退到最近 [fallback] 次有反馈的。
  /// N=7 的依据：临床疼痛回顾（BPI「过去一周」）与运动科学急性负荷窗口（ACWR 7 天）取公约数。
  List<LoggedSession> rehabFeedbackSessions({int days = 7, int fallback = 3}) {
    final since = DateTime.now().subtract(Duration(days: days));
    final recent = sessions.where((s) => s.hasFeedback && s.date.isAfter(since)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (recent.isNotEmpty) return recent;
    final older = sessions.where((s) => s.hasFeedback).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return older.take(fallback).toList();
  }

  /// 把一条训练反馈写成提示词里的一行。
  String rehabFeedbackLine(LoggedSession s) {
    final parts = <String>[];
    if (s.feel != null) parts.add(_feelText(s.feel!));
    if (s.painArea.isNotEmpty || s.painLevel > 0) {
      final area = s.painArea.isEmpty ? '不适' : muscleLabel(s.painArea);
      parts.add(s.painLevel > 0 ? '$area ${s.painLevel}/10 不适' : area);
    }
    if (s.note.trim().isNotEmpty) parts.add('备注：${s.note.trim()}');
    final mm = s.date.month.toString().padLeft(2, '0');
    final dd = s.date.day.toString().padLeft(2, '0');
    return '- $mm/$dd：${parts.isEmpty ? '（无具体记录）' : parts.join('；')}';
  }

  String _feelText(int i) => switch (i) {
        0 => t.fbFeelEasy,
        1 => t.fbFeelOk,
        2 => t.fbFeelHard,
        _ => t.fbFeelMax,
      };

  /// 把 AI 回复里的 adjust 指令套到档案关联的计划上。
  /// 安全门未通过 / 无关联计划时不动。返回实际应用的条数 + 未处理项说明。
  ({int adjusted, List<String> missed}) applyRehabAdjust(
      String episodeId, List<RehabAdjust> adjusts) {
    final ep = episodeById(episodeId);
    if (ep == null || adjusts.isEmpty) return (adjusted: 0, missed: const <String>[]);
    if (!ep.safe) return (adjusted: 0, missed: const ['未通过安全门，已忽略全部计划调整']);
    final rs = routines.where((r) => ep.routineIds.contains(r.id)).toList();
    if (rs.isEmpty) return (adjusted: 0, missed: const ['档案没有关联计划，无法套用调整']);
    var n = 0;
    final missed = <String>[];
    for (final a in adjusts) {
      final targets = a.target.isEmpty ? rs : rs.where((r) => r.name == a.target).toList();
      if (targets.isEmpty) {
        missed.add('计划「${a.target}」不存在');
        continue;
      }
      for (final r in targets) {
        final ok = switch (a.action) {
          'set' => _rehabSet(r, a, missed),
          'remove' => _rehabRemove(r, a, missed),
          _ => _rehabAdd(r, a, missed),
        };
        if (ok) n++;
      }
    }
    if (n > 0) persistNow();
    return (adjusted: n, missed: missed.toSet().toList());
  }

  bool _rehabSet(Routine r, RehabAdjust a, List<String> missed) {
    final ex = matchExerciseByName(a.exercise);
    if (ex == null) {
      missed.add(a.exercise);
      return false;
    }
    if (!r.exerciseIds.contains(ex.id)) return false; // 该计划里本来没这个动作，静默跳过
    final value = a.value!;
    switch (a.field) {
      case 'rest':
        setRoutineRest(r.id, ex.id, value.toInt());
      case 'sets':
        _rehabSetCount(r, ex.id, value.toInt());
      case 'weight':
        _rehabSetField(r, ex.id, 'weight', value);
      case 'reps':
        _rehabSetField(r, ex.id, 'reps', value);
    }
    return true;
  }

  /// 改组数：无 plan 时走简单模式；有 plan 时补 / 删工作组（warmup 不动）。
  void _rehabSetCount(Routine r, String exId, int n) {
    final count = n.clamp(1, 20);
    final planned = r.plan[exId];
    if (planned == null || planned.isEmpty) {
      setRoutineSetCount(r.id, exId, count);
      return;
    }
    final next = [...planned];
    final working = [for (var i = 0; i < next.length; i++) if (next[i].kind != SetKind.warmup) i];
    final delta = count - working.length;
    if (delta > 0) {
      final base = working.isEmpty ? const PlannedSet() : next[working.first];
      for (var i = 0; i < delta && next.length < 20; i++) {
        next.add(PlannedSet(reps: base.reps, weightKg: base.weightKg));
      }
    } else {
      for (var i = 0; i < -delta; i++) {
        final idx = next.lastIndexWhere((p) => p.kind != SetKind.warmup);
        if (idx < 0) break;
        next.removeAt(idx);
      }
    }
    setPlannedSets(r.id, exId, next);
  }

  /// 改重量 / 次数：只改工作组（warmup 不动）；无 plan 时先建出工作组。
  void _rehabSetField(Routine r, String exId, String field, num value) {
    final planned = r.plan[exId];
    var next = planned == null ? <PlannedSet>[] : [...planned];
    if (next.isEmpty) {
      final count = routineSets(r, exId).clamp(1, 20);
      next = [for (var i = 0; i < count; i++) const PlannedSet()];
    }
    for (var i = 0; i < next.length; i++) {
      if (next[i].kind == SetKind.warmup) continue;
      next[i] = field == 'weight'
          ? next[i].copyWith(weightKg: value.toDouble())
          : next[i].copyWith(reps: value.toInt());
    }
    setPlannedSets(r.id, exId, next);
  }

  bool _rehabRemove(Routine r, RehabAdjust a, List<String> missed) {
    final ex = matchExerciseByName(a.exercise);
    if (ex == null) {
      missed.add(a.exercise);
      return false;
    }
    if (!r.exerciseIds.remove(ex.id)) return false;
    r.sets.remove(ex.id);
    r.plan.remove(ex.id);
    r.rest.remove(ex.id);
    r.chained.remove(ex.id);
    return true;
  }

  bool _rehabAdd(Routine r, RehabAdjust a, List<String> missed) {
    final ex = matchExerciseByName(a.exercise);
    if (ex == null) {
      missed.add(a.exercise);
      return false;
    }
    if (!r.exerciseIds.contains(ex.id)) r.exerciseIds.add(ex.id);
    final sets = a.addSets?.clamp(1, 20);
    if (sets != null) r.sets[ex.id] = sets;
    if (a.addReps != null || a.addWeight != null) {
      final count = (sets ?? r.sets[ex.id] ?? kDefaultRoutineSets).clamp(1, 20);
      setPlannedSets(r.id, ex.id, [
        for (var i = 0; i < count; i++)
          PlannedSet(reps: a.addReps, weightKg: a.addWeight?.toDouble()),
      ]);
    }
    return true;
  }

  /// 把 AI 回复套到档案上：建训练计划 + 修改现有计划 + 存 advice。
  ({int routines, int added, int adjusted, List<String> missed}) applyRehabReply(
      String episodeId, String raw) {
    final ep = episodeById(episodeId);
    if (ep == null) return (routines: 0, added: 0, adjusted: 0, missed: const <String>[]);
    if (!ep.safe) {
      // 安全门未通过：只保留 advice，不建计划、不套调整（与提示词规则 8 一致）
      final advice = extractRehabAdvice(raw);
      if (advice.isNotEmpty) ep.advice = advice;
      updateEpisode(ep);
      return (routines: 0, added: 0, adjusted: 0, missed: const ['未通过安全门，已忽略计划与调整']);
    }
    final plans = parsePlan(raw);
    final before = routines.map((r) => r.id).toSet();
    var made = 0;
    var added = 0;
    final missed = <String>[];
    if (plans.isNotEmpty) {
      final res = applyPlan(plans);
      final fresh = routines.where((r) => !before.contains(r.id)).map((r) => r.id).toList();
      made = res.routines;
      added = res.added;
      missed.addAll(res.missed);
      if (fresh.isNotEmpty) ep.routineIds = [...ep.routineIds, ...fresh];
    }
    final adjusts = extractRehabAdjust(raw);
    var adjusted = 0;
    if (adjusts.isNotEmpty) {
      final adj = applyRehabAdjust(episodeId, adjusts);
      adjusted = adj.adjusted;
      missed.addAll(adj.missed);
    }
    final advice = extractRehabAdvice(raw);
    if (advice.isNotEmpty) ep.advice = advice;
    updateEpisode(ep);
    return (routines: made, added: added, adjusted: adjusted, missed: missed.toSet().toList());
  }

  List<PlannedSet> _plannedFrom(PlanItem item) {
    final explicit = [
      for (final p in item.plan)
        PlannedSet(
          reps: p.reps ?? item.reps,
          weightKg: p.weightKg ?? (p.kind == SetKind.warmup.index ? null : item.weightKg),
          kind: setKindFrom(p.kind),
          sec: p.sec,
          km: p.km,
        ),
    ];
    final working = explicit.where((p) => p.kind != SetKind.warmup).length;
    final simple = item.reps == null && item.weightKg == null;
    final wanted = item.sets ?? (working > 0 || simple ? working : kDefaultRoutineSets);
    if (simple && explicit.isEmpty) return const [];
    return [
      ...explicit,
      for (var i = working; i < wanted.clamp(0, 20); i++) PlannedSet(reps: item.reps, weightKg: item.weightKg),
    ];
  }

  static const _kindNames = ['normal', 'warmup', 'drop', 'failure', 'restpause'];

  String exportPlanJson(List<Routine> list, {bool withSchedule = true}) {
    return encodePlan({
      'gymmane': 'plan',
      'v': 1,
      'unit': 'kg',
      'routines': [
        for (final r in list)
          {
            'name': routineTitle(r),
            if (r.group.isNotEmpty) 'group': r.group,
            if (withSchedule)
              'days': [for (var d = 1; d <= 7; d++) if (plannedOn(d, r.id)) d],
            'exercises': [
              for (final id in r.exerciseIds)
                if (exerciseById(id) case final ex?)
                  {
                    'id': id,
                    'name': ex.name,
                    'sets': routineSets(r, id),
                    if (hasPlan(r, id))
                      'plan': [
                        for (final p in plannedSets(r, id))
                          {
                            if (p.kind != SetKind.normal) 'type': _kindNames[p.kind.index],
                            if (p.reps != null) 'reps': p.reps,
                            if (p.weightKg != null) 'weight': _round3(p.weightKg!),
                            if (p.sec != null) 'time': p.sec,
                            if (p.km != null) 'distance': p.km,
                          },
                      ],
                    if (chainsToNext(r, id)) 'superset': true,
                    'rest': ?(routineRest(r.id, id) ?? (hasCustomRest(id) ? restFor(id) : null)),
                    if (isCustom(id))
                      'custom': {
                        'muscle': ex.primary,
                        if (ex.secondary.isNotEmpty) 'secondary': ex.secondary,
                        'equipment': ex.equipment,
                        'level': ex.difficulty,
                        if (ex.steps.isNotEmpty) 'steps': ex.steps,
                        if (modeOf(id).isNotEmpty) 'track': modeOf(id),
                      },
                  },
            ],
          },
      ],
    });
  }

  String planSummaryText(List<Routine> list) {
    final out = <String>[];
    for (final r in list) {
      final days = [for (var d = 1; d <= 7; d++) if (plannedOn(d, r.id)) t.weekdayShort(d)];
      out.add(days.isEmpty ? routineTitle(r) : '${routineTitle(r)} · ${days.join(', ')}');
      for (final id in r.exerciseIds) {
        final ex = exerciseById(id);
        if (ex == null) continue;
        final planned = plannedSets(r, id).where((p) => p.kind != SetKind.warmup).toList();
        final reps = planned.isEmpty ? null : planned.first.reps;
        final kg = planned.isEmpty ? null : planned.first.weightKg;
        final detail = StringBuffer('${routineSets(r, id)}')..write(reps == null ? '' : ' × $reps');
        if (kg != null) detail.write(' @ ${weightLabel(kg)}');
        out.add('• ${exerciseName(ex)} — $detail${chainsToNext(r, id) ? ' +' : ''}');
      }
      out.add('');
    }
    return out.join('\n').trim();
  }

  static String _sessionKey(LoggedSession s) =>
      '${s.date.toIso8601String()}|${s.exercises.map((e) => '${e.id}:${e.sets.length}').join(',')}';
  int importParsedSessions(List<ParsedSession> parsed) {
    final seen = sessions.map(_sessionKey).toSet();
    var added = 0;
    for (final ps in parsed) {
      final exs = <LoggedExercise>[];
      for (final pe in ps.exercises) {
        if (pe.sets.isEmpty) continue;
        final match = (pe.id == null ? null : exerciseById(pe.id!)) ?? matchExerciseByName(pe.name);
        final id = match?.id ?? 'imp:${_normName(pe.name).replaceAll(' ', '-')}';
        final hint = (pe.muscle ?? '').toLowerCase();
        final primary =
            match?.primary ?? (kFilterMuscles.contains(hint) ? hint : guessMuscle(pe.name) ?? 'other');
        exs.add(LoggedExercise(id, match?.name ?? pe.name, primary,
            [for (final s in pe.sets) LoggedSet(s.reps, s.weightKg, rpe: s.rpe)]));
      }
      if (exs.isEmpty) continue;
      final ls = LoggedSession(ps.date, ps.durationSec, exs);
      final key = _sessionKey(ls);
      if (seen.contains(key)) continue;
      sessions.add(ls);
      seen.add(key);
      added++;
    }
    if (added > 0) {
      sessions.sort((a, b) => a.date.compareTo(b.date));
      _persist();
      _refreshWidgets();
      notifyListeners();
    }
    return added;
  }

  int importParsedWeights(List<ParsedWeight> parsed) {
    final seen = bodyweight.map((e) => _dayKey(e.date)).toSet();
    var added = 0;
    for (final w in parsed) {
      if (w.kg <= 0) continue;
      if (!seen.add(_dayKey(w.date))) continue;
      bodyweight.add(BodyweightEntry(w.date, _round3(w.kg)));
      added++;
    }
    if (added > 0) {
      bodyweight.sort((a, b) => a.date.compareTo(b.date));
      final latest = latestBodyweight;
      if (latest != null) {
        profile.weightKg = latest.kg;
        _seedCalculatorsFromProfile();
      }
      _persist();
      notifyListeners();
    }
    return added;
  }

  bool handleBack() {
    switch (route) {
      case 'exercise-detail':
        closeExerciseDetail();
      case 'about':
        backFromAbout();
      case 'tools':
        backFromTools();
      case 'tools-detail':
        closeTool();
      case 'routines':
        backFromRoutines();
      case 'routine-edit':
        closeRoutineEdit();
      case 'measures':
        backFromMeasures();
      case 'places':
        backFromPlaces();
      case 'timeline':
        backFromTimeline();
      case 'compare':
        backFromCompare();
      case 'notes':
        backFromNotes();
      case 'note-edit':
        closeNoteEditor();
      case 'train':
        trainStep == 'review' ? trainBack() : closeTrain();
      case 'preferences':
        backFromPreferences();
      case 'moments':
        backFromMoments();
      case 'awards':
        backFromAwards();
      case 'ai-plan':
        backFromAiPlan();
      case 'rehab-episodes':
        backFromRehabEpisodes();
      case 'rehab-episode-new':
        backFromRehabNew();
      case 'rehab-episode':
        backFromRehabEpisode();
      case 'progress':
      case 'exercises':
      case 'settings':
        goHome();
      case 'home':
        return false;
      default:
        popRoute();
    }
    return true;
  }

  void goAbout() => pushRoute('about');

  void backFromAbout() => popRoute(fallback: 'settings');

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }
}

final fit = FitState();
