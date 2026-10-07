import 'package:flutter/material.dart';

/// The 康途 / Kangtu identity mark — the four colourways defined by
/// "Kangtu — Identity Mark v1.0":
///
/// * [BrandMarkStyle.fullColor] two-colour master (teal path + orange figure),
///   drawn on the pale-mint field.
/// * [BrandMarkStyle.inverted] white + peach mark, for teal / brand-coloured
///   fields.
/// * [BrandMarkStyle.monoTeal] single-ink teal, for light fields.
/// * [BrandMarkStyle.knockout] solid white knockout, for dark / ink fields.
///
/// [BrandMarkStyle.auto] picks a sensible fallback from the current
/// [Theme] brightness so callers do not have to know the surface colour.
enum BrandMarkStyle {
  fullColor,
  inverted,
  monoTeal,
  knockout,
  auto,
}

class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.style = BrandMarkStyle.auto,
    this.height,
    this.width,
    this.opacity = 1,
    this.color,
    this.fit = BoxFit.contain,
  });

  /// Which colourway to draw. Defaults to [BrandMarkStyle.auto].
  final BrandMarkStyle style;

  final double? height;
  final double? width;

  /// Overall opacity (the mark is often used as a faint watermark).
  final double opacity;

  /// When set, the whole mark is flattened to this single colour
  /// (negative-space / tinted usage such as stickers).
  final Color? color;

  final BoxFit fit;

  static const Map<BrandMarkStyle, String> assets = {
    BrandMarkStyle.fullColor: 'assets/img/brand_full.png',
    BrandMarkStyle.inverted: 'assets/img/brand_inverted.png',
    BrandMarkStyle.monoTeal: 'assets/img/brand_mono.png',
    BrandMarkStyle.knockout: 'assets/img/brand_knockout.png',
  };

  /// Auto rule: dark surfaces get the white knockout, light surfaces the
  /// single-ink teal master.
  static BrandMarkStyle forBrightness(Brightness brightness) =>
      brightness == Brightness.dark
          ? BrandMarkStyle.knockout
          : BrandMarkStyle.monoTeal;

  @override
  Widget build(BuildContext context) {
    final resolved = style == BrandMarkStyle.auto
        ? forBrightness(Theme.of(context).brightness)
        : style;
    Widget mark = Image.asset(
      assets[resolved]!,
      height: height,
      width: width,
      fit: fit,
      color: color,
      colorBlendMode: color == null ? null : BlendMode.srcIn,
    );
    if (opacity < 1) {
      mark = Opacity(opacity: opacity, child: mark);
    }
    return mark;
  }
}
