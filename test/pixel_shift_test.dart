import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/pixel_shift.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 规范 v1.5 §06.2「shift static UI chrome periodically against burn-in」的实现自测。
///
/// 位移数学是**纯函数**（`pixelShiftOffset`），所以这里可以本地实跑、不依赖真机：
/// - 幅度必须**有界**（否则"防烧屏"会把界面挪歪）；
/// - 必须**确定性**（同一时刻同一结果，可复现、可回归）；
/// - 必须**真的在动**（8 个周期内不止一个位置，且 8 周期后回到起点）；
/// - 必须是**整数像素**（亚像素位移对烧屏无意义且渲染发虚）。
void main() {
  group('widget 层（PixelShift 包装器）', _widgetTests);

  test('幅度有界：|dx|、|dy| 不超过 amplitude，且不超过硬上限', () {
    for (var amp = 0; amp <= 6; amp++) {
      for (var k = 0; k < 200; k++) {
        final t = DateTime(2026, 11, 6, 12).add(Duration(minutes: k * 7));
        final o = pixelShiftOffset(t, amplitude: amp, periodMinutes: 4);
        final cap = amp.clamp(0, kPixelShiftAmplitude).toDouble();
        expect(o.dx.abs(), lessThanOrEqualTo(cap), reason: 'amp=$amp k=$k dx=${o.dx}');
        expect(o.dy.abs(), lessThanOrEqualTo(cap), reason: 'amp=$amp k=$k dy=${o.dy}');
        expect(o.dx.abs(), lessThanOrEqualTo(kPixelShiftAmplitude.toDouble()), reason: '硬上限');
      }
    }
    // 传超大 amplitude 也会被夹到硬上限
    expect(pixelShiftOffset(DateTime(2026, 11, 6), amplitude: 99).dx.abs(),
        lessThanOrEqualTo(kPixelShiftAmplitude.toDouble()));
  });

  test('amplitude = 0 → 恒不位移', () {
    for (var k = 0; k < 50; k++) {
      expect(pixelShiftOffset(DateTime(2026, 11, 6).add(Duration(minutes: k)), amplitude: 0), Offset.zero);
    }
  });

  test('确定性：同一时刻同一结果', () {
    final t = DateTime(2026, 11, 6, 19, 30);
    expect(pixelShiftOffset(t), pixelShiftOffset(t));
    expect(pixelShiftOffset(t, periodMinutes: 4), pixelShiftOffset(t, periodMinutes: 4));
  });

  test('真的在动：8 个周期内出现多个不同位置，且 8 周期后回到起点', () {
    final base = DateTime(2026, 11, 6, 12, 0);
    final p = kPixelShiftPeriodMinutes;
    final seq = [for (var k = 0; k < kPixelShiftSteps; k++) pixelShiftOffset(base.add(Duration(minutes: p * k)))];
    expect(seq.toSet().length, greaterThanOrEqualTo(4), reason: '轮换至少要有 4 个不同位点：$seq');
    // 8 格一圈：再过一个完整周期（+8×period）应回到与起点相同的位置
    final wrap = pixelShiftOffset(base.add(Duration(minutes: p * kPixelShiftSteps)));
    expect(wrap, seq.first, reason: '8 格一圈后应回到起点（首=${seq.first} wrap=$wrap）');
  });

  test('位移是整数像素（避免亚像素渲染发虚）', () {
    for (var k = 0; k < 100; k++) {
      final o = pixelShiftOffset(DateTime(2026, 11, 6).add(Duration(minutes: k * 3)));
      expect(o.dx, o.dx.roundToDouble());
      expect(o.dy, o.dy.roundToDouble());
    }
  });

  test('默认常量自洽：默认幅度 ≤ 4 px、默认周期 ≥ 1 分钟', () {
    expect(kPixelShiftAmplitude, inInclusiveRange(1, 4), reason: '幅度应"小到不被察觉"');
    expect(kPixelShiftPeriodMinutes, greaterThanOrEqualTo(1));
    expect(pixelShiftOffset(DateTime(2026, 11, 6)),
        pixelShiftOffset(DateTime(2026, 11, 6), amplitude: kPixelShiftAmplitude, periodMinutes: kPixelShiftPeriodMinutes));
  });
}

// ---- widget 层：覆盖 PixelShift 的 build/lifecycle/定时器（逻辑变更行覆盖率门禁）----
void _widgetTests() {
  testWidgets('非 AMOLED 不位移；切到 AMOLED 立即生效且幅度 ≤3；dispose 不留定时器', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
    fit.setThemePref('light');

    Widget wrap() => const MaterialApp(home: Scaffold(body: PixelShift(child: SizedBox(width: 20, height: 20))));
    Finder inner() => find.descendant(of: find.byType(PixelShift), matching: find.byType(Transform));

    await tester.pumpWidget(wrap());
    await tester.pump();
    expect(inner(), findsNothing, reason: '非 AMOLED 主题不做位移（规范只允许 AMOLED 例外）');

    fit.setThemePref('amoled');           // 订阅 fit → 应立即生效
    await tester.pump();
    final tf = tester.widget<Transform>(inner());
    final o = Offset(tf.transform.getTranslation().x, tf.transform.getTranslation().y);
    expect(o.dx.abs(), lessThanOrEqualTo(3), reason: '位移幅度必须 ≤3 px');
    expect(o.dy.abs(), lessThanOrEqualTo(3));

    await tester.pump(const Duration(minutes: 1));   // 触发定时器回调（覆盖 _refresh 的定时路径）
    fit.setThemePref('light');
    await tester.pump();
    expect(inner(), findsNothing, reason: '切回浅色后应复位');

    // 回前台立即复位（覆盖 didChangeAppLifecycleState 分支）
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.descendant(of: find.byType(PixelShift), matching: find.byType(Transform)), findsNothing,
        reason: '切回浅色后即使回前台也不应再位移');

    await tester.pump(const Duration(milliseconds: 600));  // 让应用自身的防抖持久化定时器（400ms）跑完
    await tester.pumpWidget(const SizedBox());        // dispose：PixelShift 的定时器必须被取消（否则报 pending timer）
  });
}
