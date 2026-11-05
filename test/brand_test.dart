import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/theme/app_colors.dart';

/// 品牌不变量：
/// ① 自有 LOGO 四形态都在；② 每个语种都有非空 appName，且中文=康途、其余=Kangtu；
/// ③ 代码里不再出现「用户可见的硬编码 GymMane」——只有 GPL 署名（上游仓库/作者名）允许保留。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('自有 LOGO 四形态齐全', () {
    for (final f in ['brand_full', 'brand_inverted', 'brand_knockout', 'brand_mono']) {
      expect(File('assets/img/$f.png').existsSync(), isTrue, reason: '$f.png 不见了');
    }
  });

  test('每个语种的 appName 都非空，且中文为「康途」、其余为「Kangtu」', () {
    for (final code in appLanguages) {
      final t = lookupAppLocalizations(localeOf(code));
      expect(t.appName.trim(), isNotEmpty, reason: '$code 缺 appName');
      if (code == 'zh' || code == 'zh_Hant') {
        expect(t.appName, '康途', reason: '$code 的 appName 应为康途');
      } else {
        expect(t.appName, 'Kangtu', reason: '$code 的 appName 应为 Kangtu');
      }
    }
  });

  test('代码里没有用户可见的硬编码 GymMane（GPL 署名除外）', () {
    // 只按**行**放行 GPL 署名（含 InlitX 的行）；不做整文件豁免
    // —— 整文件豁免会让「该文件里塞回用户可见硬编码品牌」测不出来（变异验证逮到过）
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.contains('/l10n/')) continue;
      final rel = f.path.replaceFirst('./', '');
      final txt = f.readAsStringSync();
      if (!txt.contains('GymMane')) continue;
      for (final line in txt.split('\n')) {
        if (line.trimLeft().startsWith('//')) continue; // 注释不算用户可见
        if (line.contains('InlitX')) continue; // GPL 署名行（上游仓库/作者）必须保留
        // 注意：不能只匹配 'GymMane' 完整字面量 —— 'GymMane · …' 这类也会漏（踩过）
        if (RegExp(r'''['"][^'"]*GymMane[^'"]*['"]''').hasMatch(line)) {
          hits.add('$rel: ${line.trim()}');
        }
      }
    }
    expect(hits, isEmpty, reason: '这些地方应改用 t.appName：\n${hits.join('\n')}');
  });

  test('三套配色（dark / amoled / light）必须真的不同（否则深色模式会渲染成浅底）', () {
    // 变异验证：把三个 preset 填成同一份值 → 本用例立即红
    expect(GymColors.dark.pageBg, isNot(GymColors.light.pageBg), reason: 'dark 与 light 的底色不能相同');
    expect(GymColors.amoled.pageBg, isNot(GymColors.light.pageBg), reason: 'amoled 与 light 的底色不能相同');
    expect(GymColors.dark.text, isNot(GymColors.light.text), reason: 'dark 与 light 的文字色不能相同');
  });

  test('arb 文案里不得残留旧品牌（品牌要么走 appName，要么按语种写对）', () {
    final hits = <String>[];
    for (final f in Directory('lib/l10n').listSync().whereType<File>()) {
      if (!f.path.endsWith('.arb')) continue;
      final code = f.path.split('app_').last.replaceAll('.arb', '');
      final txt = f.readAsStringSync();
      if (txt.contains('GymMane')) hits.add('$code: 含 GymMane');
      // 中文语种的正文里不该出现拉丁品牌（appName 键除外，但值也应是康途）
      if ((code == 'zh' || code == 'zh_Hant') && txt.contains('"About Kangtu"')) {
        hits.add('$code: 用了拉丁品牌');
      }
    }
    expect(hits, isEmpty, reason: hits.join('; '));
  });

  test('不再引用上游的 runner.png，且启动图标资源齐全', () {
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (f.path.endsWith('.dart') && f.readAsStringSync().contains('runner.png')) hits.add(f.path);
    }
    expect(File('assets/img/runner.png').existsSync(), isFalse, reason: '上游那张跑者图应已移除');
    expect(hits, isEmpty, reason: '这些文件还在引用 runner.png：${hits.join(", ")}');
    for (final f in [
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
      'android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png',
      'android/app/src/main/res/drawable-xxxhdpi/ic_stat_gymmane.png',
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    ]) {
      expect(File(f).existsSync(), isTrue, reason: '缺图标资源：$f');
    }
  });

  test('按品牌规范：启动背景用薄荷场，不是默认纯白', () {
    for (final f in ['android/app/src/main/res/drawable/launch_background.xml',
                     'android/app/src/main/res/drawable-v21/launch_background.xml']) {
      final x = File(f).readAsStringSync();
      expect(x.contains('@android:color/white'), isFalse, reason: '$f 还是默认白底（规范：薄荷场 #EEF9F7）');
      expect(x, contains('kangtu_field'));
    }
    final colors = File('android/app/src/main/res/values/colors.xml').readAsStringSync();
    expect(colors, contains('kangtu_field'));
    expect(colors, contains('#EEF9F7'), reason: '薄荷场应为规范里的 #EEF9F7');
  });
}
