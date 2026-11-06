// 回归：底部标签栏「气泡(_LiquidPill)中心」必须与对应标签中心重合。
// 背景：2026-10-31 Howe 报「标签和阴影又对不上」——上游 1.8.0 把 `_gap` 改回
//   `clamp(0, 40)`，而 Row 用 spaceBetween 会均分更大的剩余空间 → 宽屏（>约 468dp）
//   气泡落后于图标（实测 600dp 偏 -21px、800dp 偏 -71px）。
// 修复：`_gap` 不设上限 + Row 改用显式 SizedBox(width: _gap) 间隙（气泡与图标共用同一 gap）。
// 本测试跨多种宽度断言偏差≈0。注意（2026-11-06 变异实测）：单独把 `_gap` 上限加回 40
// 或单独改回 spaceBetween，都**不会**红——因为「气泡」与「真图标」仍共用同一个 `_gap`，
// 只是整条栏不再铺满。只有让两者用上**不同**的间隙值（= 原始 bug 的组合）才会红。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Finder pill() =>
      find.byWidgetPredicate((x) => x.runtimeType.toString() == '_LiquidPill');

  /// 气泡中心的屏幕 x（气泡的 left 是相对其 Positioned 盒子的）
  double pillCenterX(WidgetTester tester) {
    final box = tester.getRect(pill()).topLeft.dx;
    final w = tester.widgetList(pill()).first;
    final left = (w as dynamic).left as double;
    final width = (w as dynamic).width as double;
    return box + left + width / 2;
  }

  Future<void> boot(WidgetTester tester, double width) async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    setAppLanguage('en');
    fit.onboarded = true;
    fit.resetRoute('home');
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const GymManeApp());
    await tester.pump(const Duration(milliseconds: 600));
  }

  for (final width in [360.0, 411.0, 480.0, 600.0, 800.0]) {
    testWidgets('底栏气泡与标签对齐 @${width.toInt()}dp', (tester) async {
      await boot(tester, width);
      expect((pillCenterX(tester) - tester.getRect(find.bySemanticsLabel(t.home)).center.dx).abs(),
          lessThan(0.5), reason: '首页标签与气泡错位 @${width}dp');

      fit.goProgress();
      await tester.pump(const Duration(milliseconds: 700));
      expect(
          (pillCenterX(tester) - tester.getRect(find.bySemanticsLabel(t.progress)).center.dx).abs(),
          lessThan(0.5),
          reason: '进度标签与气泡错位 @${width}dp');
    });
  }
}
