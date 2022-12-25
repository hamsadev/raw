import 'dart:typed_data';

import 'package:collection/collection.dart';

import 'raw_reader.dart';
import 'raw_writer.dart';

/// Something that implements both [SelfEncoder] and [SelfDecoder].
abstract class SelfCodec extends SelfEncoder with SelfDecoder {}

/// Something that can decode itself using [RawReader].
abstract class SelfDecoder {
  /// Decodes state from the bytes.
  void decodeSelf(RawReader reader);

  /// Decodes state from the SelfEncoder.
  void decodeSelfFromSelfEncoder(SelfEncoder value) {
    final byteData = value.toImmutableByteData();
    final reader = new RawReader.withByteData(byteData);
    decodeSelf(reader);
  }
}

/// Something that can encode itself using [RawWriter].
abstract class SelfEncoder {
  const SelfEncoder();

  /// Determines hash by serializing this value.
  @override
  int get hashCode => const SelfEncoderEquality().hash(this);

  /// Determines equality by serializing both values.
  @override
  bool operator ==(other) {
    return other is SelfEncoder &&
        const SelfEncoderEquality().equals(this, other);
  }

  /// Encodes this object.
  void encodeSelf(RawWriter writer);

  /// Returns an estimate of the maximum number of bytes needed to encode this
  /// value.
  int encodeSelfCapacity() => 64;

  /// Returns an immutable encoding of this value.
  ByteData toImmutableByteData() => toMutableByteData();

  /// Returns an immutable encoding of this value.
  List<int> toImmutableBytes() => toMutableBytes();

  /// Returns a mutable encoding of this value.
  ByteData toMutableByteData() {
    final capacity = encodeSelfCapacity();
    final writer = new RawWriter.withCapacity(capacity);
    encodeSelf(writer);
    return writer.toByteDataView();
  }

  /// Returns a mutable encoding of this value.
  List<int> toMutableBytes() {
    final capacity = encodeSelfCapacity();
    final writer = new RawWriter.withCapacity(capacity);
    encodeSelf(writer);
    return writer.toUint8ListView();
  }
}

/// Equality for [SelfEncoder].
///
/// Used by '==' and 'hashCode' in [SelfEncoder].
class SelfEncoderEquality implements Equality<SelfEncoder> {
  const SelfEncoderEquality();

  @override
  bool equals(SelfEncoder e1, SelfEncoder e2) {
    final bytes = e1.toImmutableBytes();
    final otherBytes = e2.toImmutableBytes();
    if (bytes.length != otherBytes.length) {
      return false;
    }
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] != otherBytes[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int hash(SelfEncoder e) {
    final bytes = e.toImmutableByteData();
    const mask = 0x7FFFFFFF;

    var h = 0;
    var i = 0;
    while (true) {
      int value = 0;
      if (i + 3 < bytes.lengthInBytes) {
        value = bytes.getUint32(i, Endian.little);
        i += 4;
      } else if (i < bytes.lengthInBytes) {
        value = 0;
        var shift = 0;
        do {
          value |= bytes.getUint8(i) << shift;
          i++;
          shift += 8;
        } while (i < bytes.lengthInBytes);
      } else {
        break;
      }
      final a = 0xFF & (value >> 24);
      final b = 0xFF & (value >> 16);
      final c = 0xFF & (value >> 8);
      final d = 0xFF & value;
      h = mask & (h ^ value);
      h = mask & ((((h * 11 + a) * 13 + b) * 17 + c) * 19 + d);
      h = mask & ((h >> 19) | (h << 13));
      h = mask & (h ^ value);
      h = mask & ((((h * 13 + a) * 17 + b) * 19 + c) * 23 + d);
    }
    h ^= bytes.lengthInBytes;
    return h;
  }

  @override
  bool isValidKey(Object? o) => o is SelfEncoder;
}
