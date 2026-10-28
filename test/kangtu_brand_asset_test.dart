import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 康途定制回归：品牌标识用「康途」全套（brand_full.png），
/// 取代上游 GymMane 的跑者图 runner.png。
/// （原上游 requests_20oct_test 的对应断言，随其测试重构被删，此处承接留证。）
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('康途品牌标识齐全且在 assets 里', () async {
    for (final p in [
      'assets/img/brand_full.png',
      'assets/img/brand_inverted.png',
      'assets/img/brand_knockout.png',
      'assets/img/brand_mono.png',
    ]) {
      final data = await rootBundle.load(p);
      expect(data.lengthInBytes, greaterThan(0), reason: '缺资产: $p');
    }
  });
}
