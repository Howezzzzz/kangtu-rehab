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
      'android/app/src/main/res/drawable-xxxhdpi/ic_stat_kangtu.png',
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

  test('上游遗留命名已清（图标/默认文件名/资源引用）；存储键必须保持不变', () {
    final legacy = <String>[];
    for (final d in ['android', 'lib']) {
      for (final f in Directory(d).listSync(recursive: true).whereType<File>()) {
        if (f.path.contains('/build/') || f.path.endsWith('.png') || f.path.endsWith('.webp')) continue;
        String txt;
        try { txt = f.readAsStringSync(); } catch (_) { continue; }
        // 同时查「引用」与「文件名」：上次漏了 drawable 下的 ic_live_tracker.xml，被 CI 的 AAPT 抓出来
        if (txt.contains('ic_stat_gymmane') || txt.contains('"gymmane.png"')) legacy.add(f.path);
      }
    }
    expect(legacy, isEmpty, reason: '仍有上游遗留命名/引用：${legacy.join(", ")}');
    for (final f in Directory('android/app/src/main/res').listSync(recursive: true).whereType<File>()) {
      expect(f.path.contains('ic_stat_gymmane'), isFalse, reason: '图标文件未改名：${f.path}');
    }
    expect(File('lib/services/local_store.dart').readAsStringSync(), contains("'gymmane_v1'"),
        reason: '存储键被改了 —— 这会丢掉所有本地数据');
  });

  test('配置与商店元数据里不留旧品牌；截图不留上游界面；版本显示必须动态', () {
    final hits = <String>[];
    for (final d in ['.github', 'fastlane']) {
      final dir = Directory(d);
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (f.path.endsWith('.png') || f.path.endsWith('.jpg') || f.path.endsWith('.webp')) continue;
        String txt;
        try { txt = f.readAsStringSync(); } catch (_) { continue; }
        for (final line in txt.split('\n')) {
          if (line.contains('InlitX')) continue; // GPL 署名行放行
          if (line.contains('上游 GymMane') || line.contains('upstream GymMane')) continue; // 正当引用上游项目名
          if (line.contains('GymMane')) hits.add('${f.path}: ${line.trim()}');
        }
      }
    }
    expect(hits, isEmpty, reason: '这些地方还写着旧品牌：\n${hits.join("\n")}');

    // 上游商店截图应已清除（README 里那批也删过了）
    for (final d in ['fastlane/metadata/android/en-US/images', 'fastlane/metadata/android/es-ES/images']) {
      final ps = Directory('$d/phoneScreenshots');
      expect(ps.existsSync() && ps.listSync().isNotEmpty, isFalse, reason: '$ps 还留着上游应用截图');
    }
    expect(File('README.md').readAsStringSync().contains('screenshots/store/'), isFalse);

    // 版本号必须动态取，不能写死（CI 每次发版都会自增构建号）
    final about = File('lib/screens/about_screen.dart').readAsStringSync();
    expect(about, contains('PackageInfo.fromPlatform()'),
        reason: '关于页版本号应动态取 PackageInfo（写死会与真实版本脱节）');
    // 上游的应用图标不应再被引用
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (f.path.endsWith('.dart')) {
        expect(f.readAsStringSync().contains('assets/img/app_icon.png'), isFalse,
            reason: '${f.path} 仍引用上游应用图标');
      }
    }
  });

  test('只允许 build.yml 发版（防第二条发布线：会给出更新器看不到的版本）', () {
    final wf = Directory('.github/workflows');
    final publishers = <String>[];
    for (final f in wf.listSync().whereType<File>()) {
      final t = f.readAsStringSync();
      if (t.contains('action-gh-release') || t.contains('gh release create') || t.contains('gh release upload')) {
        publishers.add(f.path);
      }
    }
    expect(publishers, ['.github/workflows/build.yml'],
        reason: '发布线必须唯一（且必须回写 app_version.json）：$publishers');
    expect(File('.github/workflows/build.yml').readAsStringSync(), contains('app_version.json'),
        reason: '唯一的发布线必须回写更新清单');
  });

  test('zh_Hant 统一走台湾用词（不得混入港式/大陆式）', () {
    // 背景：文件基础是台湾调（資料/裡/螢幕/影片/伺服器…），但曾混进「服務器/網絡/數據」
    //（多为康途自己后写的字符串）。选定台湾繁体后，这里把「不许混」钉死。
    const hkCn = ['服務器', '網絡', '數據', '軟件', '熒幕', '內存', '硬盤', '打印', '裏'];
    final arb = File('lib/l10n/app_zh_Hant.arb').readAsStringSync();
    final hits = <String>[];
    for (final w in hkCn) {
      if (arb.contains(w)) hits.add(w);
    }
    expect(hits, isEmpty, reason: 'zh_Hant 混入了港式/大陆式用词：${hits.join("、")}（应统一为台湾用词）');
    // 正例：台湾用词应当存在（防整文件被误替换成别的口径）
    expect(arb.contains('資料') || arb.contains('伺服器'), isTrue);
  });

  test('关于页「源代码」必须指向本仓库，且不得把上游 Ko-fi 当成自己的', () {
    final about = File('lib/screens/about_screen.dart').readAsStringSync();
    expect(about.contains('Howezzzzz/kangtu-rehab'), isTrue, reason: '关于页来源应指向本仓库');
    expect(about.contains('InlitX/GymMane'), isFalse, reason: '来源链接不得再指向上游仓库');
    expect(about.contains('ko-fi.com/inlitx'), isFalse, reason: '「请我喝咖啡」不得指向上游作者的 Ko-fi');
    expect(about.contains("'InlitX'"), isTrue, reason: 'GPL 署名（作者 InlitX）必须保留');
  });
}
