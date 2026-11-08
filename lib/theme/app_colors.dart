import 'package:flutter/material.dart';

/// 规范 v1.5 §06：「禁用态 = 该 token 的 38% 不透明度，**不得**另造灰色 hex」。
const double kDisabledOpacity = 0.38;

@immutable
class GymColors extends ThemeExtension<GymColors> {
  const GymColors({
    required this.pageBg,
    required this.bg,
    required this.bgRaised,
    required this.bgRaised2,
    required this.border,
    required this.navBg,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.ember,
    required this.emberDeep,
    required this.onEmber,
    required this.emberSoft,
    required this.emberShadow,
    required this.accent,
    required this.accentSoft,
    required this.brass,
    required this.accentInk,
    required this.sage,
    required this.sageSoft,
    required this.mutedFill,
    required this.heatEmpty,
    required this.info,
    required this.warn,
    required this.danger,
    required this.successInk,
    required this.warningInk,
    required this.errorInk,
    required this.focus,
    required this.recessed,
    required this.surface3,
    required this.highlight,
    required this.sheen,
    required this.glow,
    required this.shadow,
    required this.shadowDeep,
  });

  final Color pageBg;
  final Color bg;
  final Color bgRaised;
  final Color bgRaised2;
  final Color border;
  final Color navBg;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color ember;
  final Color emberDeep;
  final Color onEmber;
  final Color emberSoft;
  final Color emberShadow;
  final Color accent;
  final Color accentSoft;
  final Color brass;

  /// 规范 v1.1 §06：橙色**正文级**变体（--color-accent-ink）。
  /// 品牌橙 #FF8C42 在浅底仅 2.3:1，规范规定「Never as text」；
  /// 凡橙色要当文字/标签，必须用它（浅 #A94B10 = 5.5:1 / 深 #FFC49B）。
  final Color accentInk;
  final Color sage;
  final Color sageSoft;
  final Color mutedFill;
  final Color heatEmpty;
  final Color info;
  final Color warn;
  final Color danger;

  /// 规范 v1.5 §06.1：语义色的**正文级**定版变体（--color-success-ink /
  /// --color-warning-ink / --color-error-ink）。原始语义色只够图形级
  /// （success 3.4:1 / warning 2.9:1 / error 4.6:1 于白底），状态**文字**一律用 ink 变体。
  final Color successInk;
  final Color warningInk;
  final Color errorInk;

  /// 规范 v1.5 §06：焦点环色（--color-focus）· 2 px 环 + 2 px 偏移 · 两种场底均 ≥3:1。
  final Color focus;

  // ── 规范 v1.5.2 §06.3 双向表面阶梯：recessed(-1) → bg(0) → surface(1) → surface-2(2) → surface-3(3)
  /// 阶梯 -1：凹陷面（输入框/内嵌区）。浅 #DCE9E6 · 深 #061613 · AMOLED 与场同为 #000000（无法再降）。
  final Color recessed;
  /// 阶梯 3：最高抬升层（弹层/顶层）。浅 #FFFFFF · 深 #245C54 · AMOLED #1B4640。
  final Color surface3;

  // ── 规范 v1.5.2 §06.4 光影五信号（光源固定在左上）
  /// 顶侧 1px 内高光（@90%）· 浅 #FFFFFF · 深/AMOLED #A8E6DF。
  final Color highlight;
  /// 光泽色（--color-sheen）· 用于场域/玻璃感高光。
  final Color sheen;
  /// 场域辉光（--color-glow）· 铺在最底层，让 L0 也有纵深。
  final Color glow;
  /// 阴影基色（--color-shadow）· 浅 #0C2F2C，深/AMOLED #000000。**不得自造灰色 hex**。
  final Color shadow;
  /// 贴地阴影基色（--color-shadow-deep）· 浅 #061613，深/AMOLED #000000。
  final Color shadowDeep;

  /// 浅色主题判定（阶梯方向/阴影配方按亮度分）。
  bool get isLight => pageBg.computeLuminance() > 0.5;

  /// §06.4 三层阴影（ambient / key / contact），level 1..4 递增。
  /// 全部由 --color-shadow / --color-shadow-deep 配 α 合成，不自造灰。
  List<BoxShadow> depthShadows(int level) {
    if (level <= 0) return const [];
    final m = (level.clamp(1, 4)) / 4.0;
    final aAmb = (isLight ? 0.10 : 0.38) * m;
    final aKey = (isLight ? 0.09 : 0.30) * m;
    final aCon = (isLight ? 0.12 : 0.36) * m;
    return [
      BoxShadow(color: shadow.withValues(alpha: aAmb), blurRadius: 40 + 24 * m, offset: Offset(0, 12 * m)),
      BoxShadow(color: shadow.withValues(alpha: aKey), blurRadius: 14 + 6 * m, offset: Offset(0, 4 * m)),
      BoxShadow(color: shadowDeep.withValues(alpha: aCon), blurRadius: 3, offset: const Offset(0, 1)),
    ];
  }

  /// 按阶梯层级取填充色：1=凹陷面、2=卡片、3=弹层、4=顶层。
  Color surfaceFill(int level) => switch (level) {
        <= 1 => recessed,
        2 => bgRaised,
        3 => bgRaised2,
        _ => surface3,
      };

  /// §06.4 深度配方：阶梯填充 + 顶侧高光 + 1px 发丝线 + 分层阴影。
  /// level≥2 才加高光，level≥3 才加发丝线（规范：L2 起受光，L3 起需读边）。
  /// 注：Flutter 不允许「圆角 + 各边不同色 Border」，故顶侧高光用一道极短的渐变
  /// （顶部 2% 处从样式化的高光色过渡到填充色）近似「1 px 内高光」。
  BoxDecoration depthDecor({
    required int level,
    double radius = 22,
    Color? color,
    BorderRadius? borderRadius,
  }) {
    final br = borderRadius ?? BorderRadius.circular(radius);
    final hair = level >= 3;
    final lit = level >= 2;
    final fill = color ?? (level >= 2 ? surfaceFill(level) : bgRaised);
    return BoxDecoration(
      color: lit ? null : fill,
      gradient: lit
          ? LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.alphaBlend(highlight.withValues(alpha: 0.9), fill), fill],
              stops: const [0.0, 0.02],
            )
          : null,
      borderRadius: br,
      border: Border.all(color: hair ? border : border.withValues(alpha: 0.5), width: 1),
      boxShadow: depthShadows(level),
    );
  }

  /// 规范 §04 色阶（teal / orange / ink 各 10 级，brand 在 05，文字安全从 07/08/05 起）。
  /// 图表、密度图、热力图等「同色系内选一档」的场合用它，禁止为此另造第三个色相。
  static const List<Color> tealRamp = [
    Color(0xFFE9F8F5), Color(0xFFCBECE6), Color(0xFF9ADBD1), Color(0xFF55C8BC), Color(0xFF00B5AD),
    Color(0xFF00938B), Color(0xFF007C76), Color(0xFF005F5A), Color(0xFF0B3D39), Color(0xFF0B2321),
  ];
  static const List<Color> orangeRamp = [
    Color(0xFFFFF2E8), Color(0xFFFFE0C4), Color(0xFFFFC49B), Color(0xFFFFA061), Color(0xFFFF8C42),
    Color(0xFFED7526), Color(0xFFD15E17), Color(0xFFA94B10), Color(0xFF7C360A), Color(0xFF3A1B04),
  ];
  static const List<Color> inkRamp = [
    Color(0xFFE4F1EE), Color(0xFFC6DED8), Color(0xFFA2C9C1), Color(0xFF7BAFA7), Color(0xFF5B7B77),
    Color(0xFF4E6B67), Color(0xFF35605B), Color(0xFF244F4A), Color(0xFF163C38), Color(0xFF0C2F2C),
  ];

  /// 面板/抽屉打开时**页面后退的背板**色（原先是自造灰 #16161A / #3A3A3E，违反
  /// 「不得在实现时自造 hex」）。规范没有该 token，故按 §06.3「抬升/下沉靠色调」**派生**：
  /// 场色叠一层黑（浅 10% / 深 30%），两种主题都得到同一色系的更深一档。
  Color get backdrop =>
      Color.alphaBlend(Colors.black.withValues(alpha: pageBg.computeLuminance() > 0.5 ? 0.10 : 0.30), pageBg);

  /// 语义别名（v1.5 命名 → 本仓既有命名）：原始语义色**只作图形**。
  Color get success => sage;
  Color get warning => warn;
  Color get error => danger;

  static const dark = GymColors(
    pageBg: Color(0xFF0B2321),
    bg: Color(0xFF0B2321),
    bgRaised: Color(0xFF143A35),
    bgRaised2: Color(0xFF1B4640),
    border: Color(0xFF2F6A61),
    navBg: Color(0xD90B2321),
    text: Color(0xFFE8F4F2),
    textSecondary: Color(0xFF9FBDB8),
    textTertiary: Color(0xBF9FBDB8),
    ember: Color(0xFF2CD4C9),
    emberDeep: Color(0xFF7BEDE4),
    onEmber: Color(0xFF0B2321),
    emberSoft: Color(0x2E2CD4C9),
    emberShadow: Color(0x80000000),
    accent: Color(0xFF2CD4C9),
    accentSoft: Color(0x2E2CD4C9),
    brass: Color(0xFFFFA061),
    accentInk: Color(0xFFFFC49B),
    sage: Color(0xFF4ADE9E),
    sageSoft: Color(0x2E4ADE9E),
    mutedFill: Color(0x14E8F4F2),
    heatEmpty: Color(0xFF0B2321),
    recessed: Color(0xFF061613),
    surface3: Color(0xFF245C54),
    highlight: Color(0xFFA8E6DF),
    sheen: Color(0xFF7BEDE4),
    glow: Color(0xFF2CD4C9),
    shadow: Color(0xFF000000),
    shadowDeep: Color(0xFF000000),
    info: Color(0xFF7BEDE4),
    warn: Color(0xFFF5C451),
    danger: Color(0xFFFF8078),
    successInk: Color(0xFF4ADE9E),
    warningInk: Color(0xFFF5C451),
    errorInk: Color(0xFFFF8078),
    focus: Color(0xFF2CD4C9),
  );

  // AMOLED（规范 v1.5 §06.2 的 sanctioned exception）：
  // 相对 dark **只改 4 个 token** —— 场换真纯黑（像素关闭），阶梯整体上抬一步：
  //   场 #000000 · surface #0B2321 · surface-2 #143A35 · divider #1B4640
  // 其余 token 全部沿用 dark 值（文字天花板 #E8F4F2，**永不 #FFFFFF**）。
  static const amoled = GymColors(
    pageBg: Color(0xFF000000),
    bg: Color(0xFF000000),
    bgRaised: Color(0xFF0B2321),
    bgRaised2: Color(0xFF143A35),
    border: Color(0xFF245C54),
    navBg: Color(0xE6000000),
    text: Color(0xFFE8F4F2),
    textSecondary: Color(0xFF9FBDB8),
    textTertiary: Color(0xBF9FBDB8),
    ember: Color(0xFF2CD4C9),
    emberDeep: Color(0xFF7BEDE4),
    onEmber: Color(0xFF0B2321),
    emberSoft: Color(0x2E2CD4C9),
    emberShadow: Color(0x80000000),
    accent: Color(0xFF2CD4C9),
    accentSoft: Color(0x2E2CD4C9),
    brass: Color(0xFFFFA061),
    accentInk: Color(0xFFFFC49B),
    sage: Color(0xFF4ADE9E),
    sageSoft: Color(0x2E4ADE9E),
    mutedFill: Color(0x14E8F4F2),
    heatEmpty: Color(0xFF000000),
    recessed: Color(0xFF000000),
    surface3: Color(0xFF1B4640),
    highlight: Color(0xFFA8E6DF),
    sheen: Color(0xFF7BEDE4),
    glow: Color(0xFF2CD4C9),
    shadow: Color(0xFF000000),
    shadowDeep: Color(0xFF000000),
    info: Color(0xFF7BEDE4),
    warn: Color(0xFFF5C451),
    danger: Color(0xFFFF8078),
    successInk: Color(0xFF4ADE9E),
    warningInk: Color(0xFFF5C451),
    errorInk: Color(0xFFFF8078),
    focus: Color(0xFF2CD4C9),
  );

  static const light = GymColors(
    pageBg: Color(0xFFEEF9F7),
    bg: Color(0xFFEEF9F7),
    bgRaised: Color(0xFFF7FCFA),
    bgRaised2: Color(0xFFFFFFFF),
    border: Color(0xFFBCD5D0),
    navBg: Color(0xD9EEF9F7),
    text: Color(0xFF0C2F2C),
    textSecondary: Color(0xFF5B7B77),
    textTertiary: Color(0xBF5B7B77),
    ember: Color(0xFF007C76),
    emberDeep: Color(0xFF007C76),
    onEmber: Color(0xFFFFFFFF),
    emberSoft: Color(0x26007C76),
    emberShadow: Color(0x80000000),
    accent: Color(0xFF00B5AD),
    accentSoft: Color(0x2600B5AD),
    brass: Color(0xFFFF8C42),
    accentInk: Color(0xFFA94B10),
    sage: Color(0xFF1B9E6B),
    sageSoft: Color(0x261B9E6B),
    mutedFill: Color(0x140C2F2C),
    heatEmpty: Color(0xFFEEF9F7),
    recessed: Color(0xFFDCE9E6),
    surface3: Color(0xFFFFFFFF),
    highlight: Color(0xFFFFFFFF),
    sheen: Color(0xFFFFFFFF),
    glow: Color(0xFF00B5AD),
    shadow: Color(0xFF0C2F2C),
    shadowDeep: Color(0xFF061613),
    info: Color(0xFF007C76),
    warn: Color(0xFFC98A12),
    danger: Color(0xFFD2413A),
    successInk: Color(0xFF137A52),
    warningInk: Color(0xFF8A6000),
    errorInk: Color(0xFFA82F2A),
    focus: Color(0xFF007C76),
  );

  @override
  GymColors copyWith({
    Color? pageBg,
    Color? bg,
    Color? bgRaised,
    Color? bgRaised2,
    Color? border,
    Color? navBg,
    Color? text,
    Color? textSecondary,
    Color? textTertiary,
    Color? ember,
    Color? emberDeep,
    Color? onEmber,
    Color? emberSoft,
    Color? emberShadow,
    Color? accent,
    Color? accentSoft,
    Color? brass,
    Color? accentInk,
    Color? sage,
    Color? sageSoft,
    Color? mutedFill,
    Color? heatEmpty,
    Color? info,
    Color? warn,
    Color? danger,
    Color? successInk,
    Color? warningInk,
    Color? errorInk,
    Color? focus,
    Color? recessed,
    Color? surface3,
    Color? highlight,
    Color? sheen,
    Color? glow,
    Color? shadow,
    Color? shadowDeep,
  }) {
    return GymColors(
      pageBg: pageBg ?? this.pageBg,
      bg: bg ?? this.bg,
      bgRaised: bgRaised ?? this.bgRaised,
      bgRaised2: bgRaised2 ?? this.bgRaised2,
      border: border ?? this.border,
      navBg: navBg ?? this.navBg,
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      ember: ember ?? this.ember,
      emberDeep: emberDeep ?? this.emberDeep,
      onEmber: onEmber ?? this.onEmber,
      emberSoft: emberSoft ?? this.emberSoft,
      emberShadow: emberShadow ?? this.emberShadow,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      brass: brass ?? this.brass,
      accentInk: accentInk ?? this.accentInk,
      sage: sage ?? this.sage,
      sageSoft: sageSoft ?? this.sageSoft,
      mutedFill: mutedFill ?? this.mutedFill,
      heatEmpty: heatEmpty ?? this.heatEmpty,
      info: info ?? this.info,
      warn: warn ?? this.warn,
      danger: danger ?? this.danger,
      successInk: successInk ?? this.successInk,
      warningInk: warningInk ?? this.warningInk,
      errorInk: errorInk ?? this.errorInk,
      focus: focus ?? this.focus,
      recessed: recessed ?? this.recessed,
      surface3: surface3 ?? this.surface3,
      highlight: highlight ?? this.highlight,
      sheen: sheen ?? this.sheen,
      glow: glow ?? this.glow,
      shadow: shadow ?? this.shadow,
      shadowDeep: shadowDeep ?? this.shadowDeep,
    );
  }

  @override
  GymColors lerp(GymColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return GymColors(
      pageBg: c(pageBg, other.pageBg),
      bg: c(bg, other.bg),
      bgRaised: c(bgRaised, other.bgRaised),
      bgRaised2: c(bgRaised2, other.bgRaised2),
      border: c(border, other.border),
      navBg: c(navBg, other.navBg),
      text: c(text, other.text),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      ember: c(ember, other.ember),
      emberDeep: c(emberDeep, other.emberDeep),
      onEmber: c(onEmber, other.onEmber),
      emberSoft: c(emberSoft, other.emberSoft),
      emberShadow: c(emberShadow, other.emberShadow),
      accent: c(accent, other.accent),
      accentSoft: c(accentSoft, other.accentSoft),
      brass: c(brass, other.brass),
      accentInk: c(accentInk, other.accentInk),
      sage: c(sage, other.sage),
      sageSoft: c(sageSoft, other.sageSoft),
      mutedFill: c(mutedFill, other.mutedFill),
      heatEmpty: c(heatEmpty, other.heatEmpty),
      info: c(info, other.info),
      warn: c(warn, other.warn),
      danger: c(danger, other.danger),
      successInk: c(successInk, other.successInk),
      warningInk: c(warningInk, other.warningInk),
      errorInk: c(errorInk, other.errorInk),
      focus: c(focus, other.focus),
      recessed: c(recessed, other.recessed),
      surface3: c(surface3, other.surface3),
      highlight: c(highlight, other.highlight),
      sheen: c(sheen, other.sheen),
      glow: c(glow, other.glow),
      shadow: c(shadow, other.shadow),
      shadowDeep: c(shadowDeep, other.shadowDeep),
    );
  }
}

extension GymColorsX on BuildContext {
  GymColors get gc => Theme.of(this).extension<GymColors>()!;
}
