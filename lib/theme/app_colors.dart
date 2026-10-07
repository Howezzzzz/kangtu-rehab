import 'package:flutter/material.dart';

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
    required this.sage,
    required this.sageSoft,
    required this.mutedFill,
    required this.heatEmpty,
    required this.info,
    required this.warn,
    required this.danger,
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
  final Color sage;
  final Color sageSoft;
  final Color mutedFill;
  final Color heatEmpty;
  final Color info;
  final Color warn;
  final Color danger;

  static const dark = GymColors(
    pageBg: Color(0xFF061210),
    bg: Color(0xFF081815),
    bgRaised: Color(0xFF102C28),
    bgRaised2: Color(0xFF173E38),
    border: Color(0xFF245049),
    navBg: Color(0xD9081815),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9FC3BE),
    textTertiary: Color(0xFF6E938E),
    ember: Color(0xFF6FE0D8),
    emberDeep: Color(0xFFA7F0EA),
    onEmber: Color(0xFF04201E),
    emberSoft: Color(0x2E6FE0D8),
    emberShadow: Color(0x80000000),
    accent: Color(0xFF00B5AD),
    accentSoft: Color(0x3800B5AD),
    brass: Color(0xFFFF8C42),
    sage: Color(0xFF5FC9A6),
    sageSoft: Color(0x385FC9A6),
    mutedFill: Color(0xFF14332E),
    heatEmpty: Color(0xFF0F2723),
    info: Color(0xFF7FC0DB),
    warn: Color(0xFFE7B45C),
    danger: Color(0xFFF0785F),
  );

  static const light = GymColors(
    pageBg: Color(0xFFF7FBFA),
    bg: Color(0xFFEAF6F3),
    bgRaised: Color(0xFFFFFFFF),
    bgRaised2: Color(0xFFDDF0EC),
    border: Color(0xFFCFE4DF),
    navBg: Color(0xF2F7FBFA),
    text: Color(0xFF0C2F2C),
    textSecondary: Color(0xFF4E706B),
    textTertiary: Color(0xFF6E8F8A),
    ember: Color(0xFF00524B),
    emberDeep: Color(0xFF00312C),
    onEmber: Color(0xFFFFFFFF),
    emberSoft: Color(0x1F00524B),
    emberShadow: Color(0x3300524B),
    accent: Color(0xFF007A70),
    accentSoft: Color(0x1F007A70),
    brass: Color(0xFFC25E12),
    sage: Color(0xFF2E8C68),
    sageSoft: Color(0x1F2E8C68),
    mutedFill: Color(0xFFDDEFEB),
    heatEmpty: Color(0xFFDCEDE9),
    info: Color(0xFF2A6B8A),
    warn: Color(0xFF9A6A12),
    danger: Color(0xFFC0392B),
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
    Color? sage,
    Color? sageSoft,
    Color? mutedFill,
    Color? heatEmpty,
    Color? info,
    Color? warn,
    Color? danger,
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
      sage: sage ?? this.sage,
      sageSoft: sageSoft ?? this.sageSoft,
      mutedFill: mutedFill ?? this.mutedFill,
      heatEmpty: heatEmpty ?? this.heatEmpty,
      info: info ?? this.info,
      warn: warn ?? this.warn,
      danger: danger ?? this.danger,
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
      sage: c(sage, other.sage),
      sageSoft: c(sageSoft, other.sageSoft),
      mutedFill: c(mutedFill, other.mutedFill),
      heatEmpty: c(heatEmpty, other.heatEmpty),
      info: c(info, other.info),
      warn: c(warn, other.warn),
      danger: c(danger, other.danger),
    );
  }
}

extension GymColorsX on BuildContext {
  GymColors get gc => Theme.of(this).extension<GymColors>()!;
}
