// 康途定制 · 资源引用守门（ISS-205 回归）
//
// 起因：上游 2.0.0 新增的 `lib/services/report_pdf.dart` 是「整份取上游」进来的，
// 里面写着 `_loadImage('assets/img/runner.png')`；而我方早年已把 runner.png 换成自有
// 品牌图 brand_full.png（runner.png 在本仓库根本不存在）→ 导出报告 PDF 时
// `rootBundle.load` 抛异常，而外层 `shareReport` 是 `try { … } catch (_) {}`，
// 异常被**静默吞掉**：用户点「导出 PDF」没任何反应、也没任何提示。
//
// 这类问题的共同结构是「上游新文件引用了我方已改名/已删除的资源」，
// analyze 抓不到（字符串字面量）、flutter test 也抓不到（没有测试真去解码那张图）。
// 所以这里做两件事：
// ① 全库扫 lib/ 的静态 asset 字面量，逐个断言文件真的存在（悬空引用棘轮）；
// ② 断言计划 PDF 与报告 PDF 用同一张主图，防止两份 PDF 再各指各的。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/ 里的静态 asset 引用都落到真实文件（悬空引用棘轮）', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue, reason: '要在仓库根目录跑这个测试');

    // 只匹配纯静态字面量：含 $ 插值的（如 'assets/rehab/$rel'）不在守门范围
    final re = RegExp(r"'(assets/[A-Za-z0-9_.\-/]+)'");
    final dangling = <String>[];
    var checked = 0;
    for (final e in lib.listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final src = e.readAsStringSync();
      for (final m in re.allMatches(src)) {
        final p = m.group(1)!;
        if (p.endsWith('/')) continue; // 目录字面量，不是资源
        checked++;
        if (!File(p).existsSync()) dangling.add('${e.path} → $p');
      }
    }

    expect(checked, greaterThan(20),
        reason: '只扫到 $checked 处引用，正则或遍历方式大概被改坏了（守门失效比漏网更糟）');
    expect(dangling, isEmpty,
        reason: '悬空 asset 引用会在运行时抛异常，且常被外层 catch 静默吞掉：\n  ${dangling.join('\n  ')}');
  });

  test('计划 PDF 与报告 PDF 用同一张主图（别再各指各的）', () {
    String heroOf(String file) {
      final src = File(file).readAsStringSync();
      final m = RegExp(r"_loadImage\('(assets/[^']+)'\)").firstMatch(src);
      expect(m, isNotNull, reason: '$file 里找不到 _loadImage(...)，PDF 主图取值方式变了？');
      return m!.group(1)!;
    }

    final plan = heroOf('lib/services/plan_pdf.dart');
    final report = heroOf('lib/services/report_pdf.dart');
    expect(report, plan, reason: '两份 PDF 的主图必须一致（report=$report / plan=$plan）');
    expect(File(plan).existsSync(), isTrue, reason: '主图 $plan 不存在');
  });

  test('pubspec 声明的 assets 目录都非空（防止整目录被漏打包）', () {
    final ps = File('pubspec.yaml').readAsStringSync();
    final dirs = RegExp(r'^\s+-\s+(assets/[^\s]+)/\s*$', multiLine: true)
        .allMatches(ps)
        .map((m) => m.group(1)!)
        .toList();
    expect(dirs, isNotEmpty, reason: 'pubspec 里一条 assets 目录声明都没扫到？');
    for (final d in dirs) {
      final dir = Directory(d);
      expect(dir.existsSync(), isTrue, reason: 'pubspec 声明了不存在的目录：$d');
      expect(dir.listSync().whereType<File>().length, greaterThan(0),
          reason: 'pubspec 声明的目录是空的：$d（打包会漏资源）');
    }
  });
}
