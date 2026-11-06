/// 防烧屏微移（规范 v1.5 §06.2 要求：「shift static UI chrome periodically against burn-in」）。
///
/// ## 依据（调研结论）
/// - **业界做法**：OLED 烧屏来自「同一批像素长期显示同一内容」；AOD/常亮类界面（Wear OS 表盘、
///   电视屏保、车机）一律让**常驻内容周期性微移**几个像素，靠位置轮换摊薄老化，位移幅度小到
///   肉眼几乎不可见。
/// - **同类参考**：Flutter 的 AOD 应用 `funny_time`（github.com/dengsgo/funny_time）在限定边距内
///   用**随机步进 + 撞边反向**微移时间部件；本项目取其"有界 + 缓慢轮换"的思路，但改成
///   **确定性圆周轮换**（可测、可复现，不需要随机源）。
///
/// ## 设计
/// - 位置沿一个小圆周轮换：第 `k` 个周期取角度 `2πk/N`，半径 = `amplitude` px；
///   一个圆 N=8 个位点、每 `periodMinutes` 分钟进一格 → **8 个周期后回到起点**，全程有界。
/// - **只取整数像素**（亚像素位移对烧屏无意义，还会让渲染发虚）。
/// - **仅 AMOLED 主题生效**：规范的例外条款只覆盖 AMOLED 场景，浅色/深色下不做无谓位移。
/// - 开「减弱动效」（`fit.calmMotion`）时**直接跳变**，不做过渡动画。
library;
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/fit_state.dart' show fit;


/// 圆周位点数（8 个方向）
const int kPixelShiftSteps = 8;

/// 默认位移半径（px）与轮换周期（分钟）。幅度刻意很小：既摊薄老化，又不被察觉。
const int kPixelShiftAmplitude = 3;
const int kPixelShiftPeriodMinutes = 4;

/// 纯函数：给定时刻，返回该时刻应施加的位移（确定性、有界、整数像素）。
///
/// - `amplitude <= 0` → 恒为 [Offset.zero]；
/// - 幅度上限硬夹在 [kPixelShiftAmplitude]（守门断言），避免"防烧屏把界面挪歪"。
Offset pixelShiftOffset(DateTime now, {int amplitude = kPixelShiftAmplitude, int periodMinutes = kPixelShiftPeriodMinutes}) {
  final amp = amplitude.clamp(0, kPixelShiftAmplitude);
  if (amp == 0) return Offset.zero;
  final period = (periodMinutes <= 0 ? 1 : periodMinutes) * 60 * 1000;
  final slot = now.millisecondsSinceEpoch ~/ period;
  final angle = 2 * math.pi * (slot % kPixelShiftSteps) / kPixelShiftSteps;
  // 取整到整像素，并保证 8 个位点互不重合（半径 ≥1 时天然成立）
  return Offset((amp * math.cos(angle)).roundToDouble(), (amp * math.sin(angle)).roundToDouble());
}

/// 把 `child` 包进「按周期微移」的容器；**仅在 AMOLED 主题**下位移，其余主题原样返回。
class PixelShift extends StatefulWidget {
  const PixelShift({
    super.key,
    required this.child,
    this.amplitude = kPixelShiftAmplitude,
    this.periodMinutes = kPixelShiftPeriodMinutes,
  });

  final Widget child;
  final int amplitude;
  final int periodMinutes;

  @override
  State<PixelShift> createState() => _PixelShiftState();
}

class _PixelShiftState extends State<PixelShift> with WidgetsBindingObserver {
  Timer? _timer;
  Offset _offset = Offset.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    // 每分钟只做一次"是否跨周期"的极轻量检查（UI 由 AnimatedBuilder 承担，开销可忽略）
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 回到前台立即按当前时间基对齐（避免"回来还停在旧位置"）
    if (state == AppLifecycleState.resumed) _refresh();
  }

  bool get _enabled => fit.themePref == 'amoled';

  void _refresh() {
    if (!mounted) return;
    final next = _enabled
        ? pixelShiftOffset(DateTime.now(), amplitude: widget.amplitude, periodMinutes: widget.periodMinutes)
        : Offset.zero;
    if (next != _offset) setState(() => _offset = next);
  }

  @override
  Widget build(BuildContext context) {
    final target = _enabled ? _offset : Offset.zero;
    if (target == Offset.zero && !_enabled) return widget.child;
    return TweenAnimationBuilder<Offset>(
      tween: Tween<Offset>(end: target),
      duration: fit.calmMotion ? Duration.zero : const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, child) => Transform.translate(offset: value, child: child),
      child: widget.child,
    );
  }
}
