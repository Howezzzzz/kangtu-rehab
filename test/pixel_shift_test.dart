import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/pixel_shift.dart';

/// 规范 v1.5 §06.2「shift static UI chrome periodically against burn-in」的实现自测。
///
/// 位移数学是**纯函数**（`pixelShiftOffset`），所以这里可以本地实跑、不依赖真机：
/// - 幅度必须**有界**（否则"防烧屏"会把界面挪歪）；
/// - 必须**确定性**（同一时刻同一结果，可复现、可回归）；
/// - 必须**真的在动**（8 个周期内不止一个位置，且 8 周期后回到起点）；
/// - 必须是**整数像素**（亚像素位移对烧屏无意义且渲染发虚）。
void main() {
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
