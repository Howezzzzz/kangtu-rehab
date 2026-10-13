part of 'fit_state.dart';

/// 自测基线状态（本地）。v1：普通档 6 项，只存绝对值与趋势，不做优劣判定。
mixin BaselineState on FitCore {
  final List<BaselineSession> baselines = [];

  BaselineSession? get latestBaseline => baselines.isEmpty ? null : baselines.last;

  BaselineSession? get previousBaseline => baselines.length < 2 ? null : baselines[baselines.length - 2];

  void saveBaseline(BaselineSession s) {
    baselines.add(s);
    persistNow();
    notifyListeners();
  }

  void deleteBaseline(String id) {
    baselines.removeWhere((b) => b.id == id);
    persistNow();
    notifyListeners();
  }

  // ---- 路由 ----
  void goBaseline() => pushRoute('baseline');

  void backFromBaseline() => popRoute(fallback: 'home');
}
