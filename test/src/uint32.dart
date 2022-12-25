import 'package:raw/raw.dart';
import 'package:test/test.dart';

void main() {
  test("extractUint32bits", () {
    expect(extractUint32Bits(0x12345678, 0, 0xF), 0x8);
    expect(extractUint32Bits(0x12345678, 0, 0xFF), 0x78);
    expect(extractUint32Bits(0x12345678, 4, 0xF), 0x7);
    expect(extractUint32Bits(0x12345678, 4, 0xFF), 0x67);
  });
  test("transformUint32bits", () {
    expect(transformUint32Bits(0x12345678, 0, 0xF, 0xA), 0x1234567A);
    expect(transformUint32Bits(0x12345678, 0, 0xFF, 0xAB), 0x123456AB);
    expect(transformUint32Bits(0x12345678, 4, 0xF, 0xA), 0x123456A8);
    expect(transformUint32Bits(0x12345678, 4, 0xFF, 0xAB), 0x12345AB8);
  });
  test("extractUint32bool", () {
    expect(extractUint32Bool(0x0, 0), false);
    expect(extractUint32Bool(0x1, 0), true);
    expect(extractUint32Bool(0x101, 4), false);
    expect(extractUint32Bool(0x111, 4), true);
  });
  test("transformUint32bool", () {
    expect(transformUint32Bool(0x101, 4, false), 0x101);
    expect(transformUint32Bool(0x111, 4, false), 0x101);
    expect(transformUint32Bool(0x101, 4, true), 0x111);
    expect(transformUint32Bool(0x111, 4, true), 0x111);
  });
}
