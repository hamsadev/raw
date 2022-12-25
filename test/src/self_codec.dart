import 'dart:typed_data';

import 'package:raw/raw.dart';
import 'package:test/test.dart';

void main() {
  group("SelfEncoder: ", () {
    test("==", () {
      var a = new _ExampleStructWriter([1, 2]);
      var b = new _ExampleStructWriter([1, 2]);
      expect(a, equals(b));

      // Non-equal value
      b = _ExampleStructWriter([1, 3]);
      expect(a, isNot(equals(b)));

      // Non-equal length
      b = new _ExampleStructWriter([1]);
      expect(a, isNot(equals(b)));
      b = new _ExampleStructWriter([1, 2, 3]);
      expect(a, isNot(equals(b)));
    });

    test("hashCode", () {
      var hashCount = 0;
      const maxBits = 32;
      const mod = 1 << 22;
      final hashCodeMap = new Map<int, int>();

      // Zero buffer
      final byteData = new ByteData(1000);
      var example = new _ExampleHashCode(byteData);

      // 1 000 hashCodes,
      for (var i = 0; i < byteData.lengthInBytes; i++) {
        hashCount++;

        // Calculate new hashCode, truncate to 16-bits
        example.length = i;
        var hashCode = example.hashCode;

        // Check the number of bits
        expect(hashCode >> maxBits, 0);

        // Check that we don't have a collision
        hashCode = hashCode % mod;
        final previous = hashCodeMap[hashCode];
        expect(previous, isNull,
            reason:
                "collision: i=$i, hash=$hashCode,  current=$hashCount, previous=$previous");

        // Add to set of hashCodes
        hashCodeMap[hashCode] = hashCount;
      }

      // Fill buffer:
      // [1, 2, ..., 1000]
      for (var i = 0; i < byteData.lengthInBytes; i++) {
        byteData.setUint8(i, (1 + i) % 256);
      }

      // 3 000 hashCodes
      for (var i = 1; i < byteData.lengthInBytes; i++) {
        hashCount++;

        // Calculate new hashCode
        example.length = i;
        var hashCode = example.hashCode;

        // Check the number of bits
        expect(hashCode >> maxBits, 0);

        // Check that we don't have a collision
        hashCode = hashCode % mod;
        final previous = hashCodeMap[hashCode];
        expect(previous, isNull,
            reason:
                "collision: i=$i, hash=$hashCode, current=$hashCount, previous=$previous");

        // Add to set of hashCodes
        hashCodeMap[hashCode] = hashCount;
      }

      // Change a single byte
      expect(example.toImmutableByteData().getUint8(0), 1);
      byteData.setUint8(0, 0);
      expect(example.toImmutableByteData().getUint8(0), 0);

      // 1 000 hashCodes
      for (var i = 2; i < byteData.lengthInBytes; i++) {
        hashCount++;

        // Calculate new hashCode, truncate to 16-bits
        example.length = i;
        var hashCode = example.hashCode;

        // Check the number of bits
        expect(hashCode >> maxBits, 0);

        // Check that we don't have a collision
        hashCode = hashCode % mod;
        final previous = hashCodeMap[hashCode];
        expect(previous, isNull,
            reason:
                "collision: i=$i, hash=$hashCode, current=$hashCount, previous=$previous");

        // Add to set of hashCodes
        hashCodeMap[hashCode] = hashCount;
      }
    });

    test("toImmutableByteData", () {
      final a = new _ExampleStructWriter([1, 2, 3]);
      final byteData = a.toImmutableByteData();
      final uint8List = new Uint8List.view(
        byteData.buffer,
        0,
        byteData.lengthInBytes,
      );
      expect(uint8List, orderedEquals([1, 2, 3]));
    });

    test("toImmutableBytes", () {
      final a = new _ExampleStructWriter([1, 2, 3]);
      expect(a.toImmutableBytes(), orderedEquals([1, 2, 3]));
    });
  });
}

class _ExampleStructWriter extends SelfEncoder {
  final List<int> bytes;

  _ExampleStructWriter(this.bytes);

  @override
  void encodeSelf(RawWriter writer) {
    writer.writeBytes(bytes);
  }
}

class _ExampleHashCode extends SelfEncoder {
  final ByteData byteData;
  int length = 0;

  _ExampleHashCode(this.byteData);

  @override
  void encodeSelf(RawWriter writer) {
    throw new UnimplementedError();
  }

  @override
  ByteData toImmutableByteData() =>
      new ByteData.view(byteData.buffer, 0, length);
}
