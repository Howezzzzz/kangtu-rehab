import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/services/rehab_intake.dart';

/// V5 §2.11 fuzz + §2.12 属性测试：解析器面对海量随机 / 畸形输入的不变量。
void main() {
  group('extractRehabAdjust 属性不变量（2.12）', () {
    test('任意随机结构：不抛异常，返回值全部合法', () {
      final rnd = Random(20261006);
      const actions = ['set', 'remove', 'add', 'explode', '', 'SET', 'Add'];
      const fields = ['weight', 'sets', 'reps', 'rest', 'color', '', 'WEIGHT'];
      const names = ['', 'Barbell Bench Press', '不存在的动作', '  bench  '];
      final values = <Object?>[null, 0, -1, 3, 1.5, 9999, 'x', true, <Object?>[], {}];

      for (var i = 0; i < 4000; i++) {
        final n = rnd.nextInt(7);
        final list = <Object?>[];
        for (var j = 0; j < n; j++) {
          if (rnd.nextInt(4) == 0) {
            list.add(rnd.nextBool() ? 42 : 'garbage');
            continue;
          }
          list.add(<String, Object?>{
            if (rnd.nextBool()) 'action': actions[rnd.nextInt(actions.length)],
            if (rnd.nextBool()) 'exercise': names[rnd.nextInt(names.length)],
            if (rnd.nextBool()) 'name': names[rnd.nextInt(names.length)],
            if (rnd.nextBool()) 'field': fields[rnd.nextInt(fields.length)],
            if (rnd.nextBool()) 'value': values[rnd.nextInt(values.length)],
            if (rnd.nextBool()) 'sets': values[rnd.nextInt(values.length)],
            if (rnd.nextBool()) 'reps': values[rnd.nextInt(values.length)],
            if (rnd.nextBool()) 'routine': rnd.nextBool() ? 'X' : 7,
          });
        }
        final raw = jsonEncode({'advice': 'x', 'adjust': list});
        final out = extractRehabAdjust(raw);
        for (final a in out) {
          expect(const ['set', 'remove', 'add'], contains(a.action),
              reason: '非法 action 泄漏: ${a.action}');
          expect(a.exercise.trim(), isNotEmpty, reason: '空动作名泄漏');
          if (a.action == 'set') {
            expect(const ['weight', 'sets', 'reps', 'rest'], contains(a.field));
            expect(a.value, isNotNull);
          }
        }
      }
    });
  });

  group('extractRehabAdjust fuzz 稳健性（2.11）', () {
    test('畸形 / 超大 / 深嵌套 / 非法字符输入不抛异常', () {
      final inputs = <String>[
        '',
        '{',
        '}',
        '{"adjust": ]',
        '{"adjust": {}}',
        '{"adjust": [1,2,3]}',
        '{"adjust": null}',
        '{"adjust": "' + ('x' * 100000) + '"}',
        '{"adjust": [' +
            List.filled(5000, '{"action":"add","exercise":"a"}').join(',') +
            ']}',
        '{"adjust": [{"action":"add","exercise":"\u0000\uD83D\uDE00"}]}',
        '{"adjust": ' + ('[' * 200) + (']' * 200) + '}',
        '\u0000\uD83D\uDE00' * 500,
        '{"adjust": [{"action":"set","exercise":"a","field":"weight","value":' +
            ('9' * 400) +
            '}]}',
      ];
      for (final raw in inputs) {
        expect(() => extractRehabAdjust(raw), returnsNormally,
            reason: '输入抛异常: ${raw.length > 30 ? '${raw.substring(0, 30)}…' : raw}');
      }
    });

    test('随机字节串不抛异常', () {
      final rnd = Random(7);
      for (var i = 0; i < 2000; i++) {
        final len = rnd.nextInt(200);
        final sb = StringBuffer();
        for (var j = 0; j < len; j++) {
          sb.writeCharCode(rnd.nextInt(0x2000));
        }
        final raw = sb.toString();
        expect(() => extractRehabAdjust(raw), returnsNormally);
      }
    });
  });
}
