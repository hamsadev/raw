import 'package:raw/raw.dart';
import 'package:raw/test_helpers.dart';
import 'package:test/test.dart';

void main() {
  group("DebugHexEncoder:", () {
    test("convert empty bytes", () {
      final input = [];
      final output = const DebugHexEncoder().convert(input);
      expect(output, equals("""(no bytes)"""));
    });

    test("convert 9 bytes", () {
      final input = [1, 2, 3, 4, 5, 6, 7, 8, 9];
      final output = const DebugHexEncoder().convert(input);
      expect(output, equals("""

0x0000: 0102 0304  0506 0708  09
"""));
    });

    test("convert 10 bytes", () {
      final input = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      final output = const DebugHexEncoder().convert(input);
      expect(output, equals("""

0x0000: 0102 0304  0506 0708  090a
"""));
    });

    test("convert 19 bytes", () {
      final input = [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        19
      ];
      final output = const DebugHexEncoder().convert(input);
      expect(output, equals("""

0x0000: 0102 0304  0506 0708  090a 0b0c  0d0e 0f10
0x0010: 1112 13
"""));
    });

    test("convert 19 bytes with expectation", () {
      final input = [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        19
      ];
      final expected = [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        19
      ];
      final output = const DebugHexEncoder().convert(input, expected: expected);
      expect(output, equals("""

0x0000: 0102 0304  0506 0708  090a 0b0c  0d0e 0f10
    (0)

0x0010: 1112 13
   (16)

"""));
    });

    test("convert 19 bytes with expectation and wrong bytes", () {
      final input = [
        1,
        2,
        0xEE,
        4,
        5,
        0x0F,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        19
      ];
      final expected = [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        19
      ];
      final output = const DebugHexEncoder().convert(input, expected: expected);
      expect(
          output,
          equals(
            """

0x0000: 0102 ee04  050f 0708  090a 0b0c  0d0e 0f10
    (0)      ^^      ^^                             <-- index of the first error: 0x2 (decimal: 2)
             03      06

0x0010: 1112 13
   (16)

""",
          ));
    });
  });

  group("DebugHexDecoder:", () {
    test("convert empty string", () {
      final input = "";
      final output = const DebugHexDecoder().convert(input);
      expect(output, byteListEquals(const <int>[]));
    });

    test("convert TCPDump-like lines", () {
      final input = """
0x0000: 0123 4567 89ab cdef 1234 5678 9abc def0 ................
0x0010: 0123 4567 89ab cdef 0123 4567 abcreageragerga # comment
""";
      final output = const DebugHexDecoder().convert(input);
      expect(
          output,
          byteListEquals(const <int>[
            0x01,
            0x23,
            0x45,
            0x67,
            0x89,
            0xab,
            0xcd,
            0xef,
            0x12,
            0x34,
            0x56,
            0x78,
            0x9a,
            0xbc,
            0xde,
            0xf0,
            0x01,
            0x23,
            0x45,
            0x67,
            0x89,
            0xab,
            0xcd,
            0xef,
            0x01,
            0x23,
            0x45,
            0x67,
          ]));
    });
  });
}
