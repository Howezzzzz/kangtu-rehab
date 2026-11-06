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
    border: Color(0xFF21504A),
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
    border: Color(0xFF1B4640),
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
    bgRaised: Color(0xFFFFFFFF),
    bgRaised2: Color(0xFFFFFFFF),
    border: Color(0xFFDCE9E6),
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
    );
  }
}

extension GymColorsX on BuildContext {
  GymColors get gc => Theme.of(this).extension<GymColors>()!;
}
