part of 'fit_state.dart';

/// 康复档案状态（本地）。
/// 参考 RehabFlow 的 Care Episode：一个困扰 = 一个档案，
/// 问诊信息、安全门、训练计划、AI 建议、备注都挂在这个档案下。
/// 提示词生成 / 回复套用放在 FitState 本体（fit_state.dart），那里能用到目录和计划引擎。
mixin RehabState on FitCore {
  final List<RehabEpisode> rehabEpisodes = [];

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
