/*
 * 康复手册数据层 —— 加载打包在 assets/rehab/content.json 的离线内容。
 * 合并进 GymMane（GPLv3），随本体一同以 GPLv3 分发。
 */
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class RehabData {
  static Map<String, dynamic>? _root;
  static bool get ready => _root != null;

  static Future<void> load() async {
    if (_root != null) return;
    final s = await rootBundle.loadString('assets/rehab/content.json');
    _root = jsonDecode(s) as Map<String, dynamic>;
  }

  static Map<String, dynamic> get root => _root ?? const {};

  static Map<String, dynamic> o(String k) {
    final v = root[k];
    return v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
  }

  static List<dynamic> a(String k) {
    final v = root[k];
    return v is List ? v : const [];
  }

  static Map<String, dynamic> meta() => o('meta');

  /// 内容里的图片引用形如 "img/x.webp"，映射到打包资源路径。
  static String imgPath(String? rel) {
    if (rel == null || rel.isEmpty) return '';
    if (rel.startsWith('assets/')) return rel;
    return 'assets/rehab/$rel';
  }
}
