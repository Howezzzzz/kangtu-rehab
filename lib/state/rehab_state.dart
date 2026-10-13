part of 'fit_state.dart';

/// 康复档案状态（本地）。
/// 参考 RehabFlow 的 Care Episode：一个困扰 = 一个档案，
/// 问诊信息、安全门、训练计划、AI 建议、备注都挂在这个档案下。
/// 提示词生成 / 回复套用放在 FitState 本体（fit_state.dart），那里能用到目录和计划引擎。
mixin RehabState on FitCore {
  final List<RehabEpisode> rehabEpisodes = [];

  /// 统一「日志」用的康复日志条目（原 prefs `rehab_log_v1` 一次性迁入）。
  final List<RehabLogEntry> rehabLog = [];
  bool rehabLogMerged = false;

  void addRehabLog(RehabLogEntry e) {
    rehabLog.insert(0, e);
    persistNow();
    notifyListeners();
  }

  void updateRehabLog(RehabLogEntry e) {
    final i = rehabLog.indexWhere((x) => x.id == e.id);
    if (i < 0) return;
    rehabLog[i] = e;
    persistNow();
    notifyListeners();
  }

  void deleteRehabLog(String id) {
    rehabLog.removeWhere((x) => x.id == id);
    persistNow();
    notifyListeners();
  }

  /// 是否有进行中的康复档案（决定训练反馈里是否出现康复记录）。
  bool get hasActiveRehab => rehabEpisodes.any((e) => e.status == 'active');

  /// 按「日」写入/更新一条康复日志（训练反馈用：同一天重复保存只更新不新增）。
  void upsertRehabLogForDay(DateTime day, int phase, String light, String feel) {
    final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    String dayKey(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final i = rehabLog.indexWhere((x) => dayKey(x.date) == key);
    if (i >= 0) {
      rehabLog[i] = RehabLogEntry(
          id: rehabLog[i].id, date: rehabLog[i].date, phase: phase, light: light, feel: feel);
    } else {
      rehabLog.insert(0,
          RehabLogEntry(id: 'r${day.millisecondsSinceEpoch}', date: day, phase: phase, light: light, feel: feel));
      rehabLog.sort((a, b) => b.date.compareTo(a.date));
    }
    persistNow();
    notifyListeners();
  }

  /// 一次性把旧康复手册日志（prefs `rehab_log_v1`）迁进统一日志。
  Future<void> migrateRehabLog() async {
    if (rehabLogMerged) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('rehab_log_v1');
      if (raw != null && raw.isNotEmpty) {
        final d = jsonDecode(raw);
        if (d is List) {
          for (final e in d.whereType<Map>()) {
            final m = e.cast<String, dynamic>();
            final date = DateTime.tryParse('${m['date']}') ?? DateTime.now();
            rehabLog.add(RehabLogEntry(
              id: 'r${date.millisecondsSinceEpoch}_${rehabLog.length}',
              date: date,
              phase: (m['phase'] as num?)?.toInt() ?? 0,
              light: '${m['light'] ?? 'g'}',
              feel: '${m['feel'] ?? ''}',
            ));
          }
          rehabLog.sort((a, b) => b.date.compareTo(a.date));
        }
      }
    } catch (_) {}
    rehabLogMerged = true;
    persistNow();
  }

  String? activeEpisodeId;

  RehabEpisode? get activeEpisode {
    final id = activeEpisodeId;
    return id == null ? null : episodeById(id);
  }

  RehabEpisode? episodeById(String id) =>
      rehabEpisodes.where((e) => e.id == id).firstOrNull;

  String createEpisode(RehabEpisode ep) {
    rehabEpisodes.insert(0, ep);
    persistNow();
    notifyListeners();
    return ep.id;
  }

  void updateEpisode(RehabEpisode ep) {
    final i = rehabEpisodes.indexWhere((e) => e.id == ep.id);
    if (i < 0) return;
    rehabEpisodes[i] = ep;
    persistNow();
    notifyListeners();
  }

  void deleteEpisode(String id) {
    // 只删档案，保留它建出来的训练计划（用户可能已经用上了）
    rehabEpisodes.removeWhere((e) => e.id == id);
    if (activeEpisodeId == id) activeEpisodeId = null;
    persistNow();
    notifyListeners();
  }

  // ---- 路由 ----
  void goRehabEpisodes() => pushRoute('rehab-episodes');

  void backFromRehabEpisodes() => popRoute(fallback: 'rehab');

  void newRehabEpisode() => pushRoute('rehab-episode-new');

  void backFromRehabNew() => popRoute(fallback: 'rehab-episodes');

  void openRehabEpisode(String id) {
    activeEpisodeId = id;
    pushRoute('rehab-episode');
  }

  void backFromRehabEpisode() => popRoute(fallback: 'rehab-episodes');
}
