// 康途定制 · RISK-091 闭环：把 GPL 署名变成测试守住的不变量
//
// 本 fork 基于 InlitX/GymMane（GPL-3.0 + 7(b) 附加条款）二次开发。附加条款要求：
// 含 GymMane 全部或一部分的作品，必须在「Appropriate Legal Notices」处保留署名
// 「Based on GymMane by InlitX」，交互界面要在展示法律声明的地方（如关于页）显示它，
// **允许翻译**、不要求 logo 或链接（原文见 ADDITIONAL_TERMS.md）。
//
// 风险不在「代码里还留着 GymMane 字样」，而在**品牌大扫除时顺手把署名一起删掉**
// —— 2026-11-04 一天内就做了两轮清扫（清 GymMane 残留 + 清 24 处硬编码中文），
// 再扫一轮很容易把 `_kUpstreamUrl`、`_author='InlitX'`、aboutOssBody 当残留删掉，
// 那就是 GPL 违约。所以这里把每个署名点钉死：谁删了，测试就红。
//
// 同时记录「有意保留 GymMane 字样」的三处（不是漏网）：
// about 页署名行、PDF 元数据 `_author`、类名 `GymManeApp` 与 `lib/app/gymmane_app.dart`
// 文件名（与上游同名同结构，降低后续三方合并成本）。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('许可证全文与附加条款随源码分发', () {
    final lic = File('LICENSE');
    expect(lic.existsSync(), isTrue, reason: 'GPL-3.0 全文必须在仓库根目录');
    expect(lic.readAsStringSync(), contains('GNU GENERAL PUBLIC LICENSE'));
    expect(lic.readAsStringSync(), contains('Version 3, 29 June 2007'));

    final at = File('ADDITIONAL_TERMS.md');
    expect(at.existsSync(), isTrue, reason: 'README 引用了 GPL 7(b) 附加条款，文件不能丢');
    expect(at.readAsStringSync(), contains('Based on GymMane by InlitX'),
        reason: '附加条款里必须留着署名原文');
  });

  test('README 写明二次开发来源与许可', () {
    final r = File('README.md').readAsStringSync();
    expect(r, contains('InlitX'));
    expect(r, contains('GymMane'));
    expect(r, contains('GPL-3.0'));
    expect(r, contains('ADDITIONAL_TERMS.md'), reason: '附加条款要能从 README 点到');
  });

  test('关于页仍渲染开源署名行（App 内的法律声明位置）', () {
    final s = File('lib/screens/about_screen.dart').readAsStringSync();
    expect(s, contains("const _kUpstreamUrl = 'https://github.com/InlitX/GymMane'"),
        reason: '上游仓库链接不能被品牌清扫删掉');
    expect(s, contains('t.aboutOssTitle, t.aboutOssBody, _kUpstreamUrl'),
        reason: '署名行必须真的被渲染进 _credits，而不是只留个常量');
  });

  test('三个语言的署名文案都点到 InlitX 与 GymMane（允许翻译）', () {
    for (final loc in ['en', 'zh', 'zh_Hant']) {
      final arb = jsonDecode(File('lib/l10n/app_$loc.arb').readAsStringSync()) as Map;
      final body = arb['aboutOssBody']?.toString() ?? '';
      expect(body, contains('InlitX'), reason: '$loc 的署名缺作者名');
      expect(body, contains('GymMane'), reason: '$loc 的署名缺上游项目名');
    }
    final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
    expect(en['aboutOssBody'], 'Based on GymMane by InlitX',
        reason: '英文即附加条款要求的原文，逐字不能改');
  });

  test('导出的 PDF 元数据仍署名 InlitX', () {
    final s = File('lib/services/plan_pdf.dart').readAsStringSync();
    expect(s, contains("const _author = 'InlitX'"), reason: 'PDF 作者不能被换成自家品牌');
    expect(s, contains('/Author'), reason: 'PDF Info 字典要带 Author');
    expect(s, contains('dc:creator'), reason: 'XMP 要带 creator');
  });

  test('品牌名本地化不能顶掉署名（RISK-087 与 RISK-091 的边界）', () {
    // RISK-087 之后：App 内品牌走 t.appName（zh=康途 / 其余语言=Kangtu）。
    // 署名是法律义务，不参与品牌本地化，两者不能混。
    final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
    final zh = jsonDecode(File('lib/l10n/app_zh.arb').readAsStringSync()) as Map;
    expect(en['appName'], 'Kangtu');
    expect(zh['appName'], '康途');
    expect(en['aboutOssBody'].toString(), isNot(contains(en['appName'].toString())),
        reason: '署名里出现自家品牌名 = 把上游作者顶掉了');
    expect(zh['aboutOssBody'].toString(), isNot(contains(zh['appName'].toString())),
        reason: '同上（中文侧）');
  });
}
