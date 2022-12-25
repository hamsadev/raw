import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart' show Int64;

import 'self_codec.dart';

/// Writes values into a buffer.
///
/// If `isExpanding` is true, buffer is automatically is expanded.
class RawWriter {
  /// Minimum length for copying bytes in uin32 chunks.
  /// See 'test/benchmark.dart'.
  static const int _minLengthForUin32CopyMethod = 128;

  ByteData _byteData;

  int _length = 0;

  /// Determines whether buffer is expanded automatically.
  final bool isExpanding;

  /// Constructor that uses the [ByteData] as buffer.
  ///
  /// If `isExpanding` is true, buffer is expanded automatically.
  RawWriter.withByteData(this._byteData, {this.isExpanding = true});

  /// Constructor that allocates a new buffer with the capacity.
  ///
  /// If `isExpanding` is true, buffer is automatically is expanded.
  factory RawWriter.withCapacity(int capacity, {bool isExpanding = true}) {
    return new RawWriter.withByteData(
      new ByteData(capacity),
      isExpanding: isExpanding,
    );
  }

  /// Constructor that uses the [Uint8List] as buffer.
  ///
  /// If `isExpanding` is true, buffer is expanded automatically.
  RawWriter.withUint8List(Uint8List list, {bool isExpanding = true})
      : this.withByteData(
          new ByteData.view(
            list.buffer,
            list.offsetInBytes,
            list.lengthInBytes,
          ),
          isExpanding: isExpanding,
        );

  /// Returns the buffer.
  ByteData get bufferAsByteData => _byteData;

  /// Current written length.
  ///
  /// It's acceptable to mutate the length temporarily to write into a specific
  /// region of the buffer.
  ///
  /// Decreasing length does not affect the underlying buffer at all.
  ///
  /// Increasing length does not guarantee that the added bytes are zero.
  /// For increasing length with zero bytes, use [writeZeroes].
  int get length => _length;

  set length(int value) {
    final oldValue = this._length;
    if (value > oldValue) {
      ensureAvailableLength(value - oldValue);
    }
    this._length = value;
  }

  /// Ensures that the buffer has space for N more bytes.
  ///
  /// If buffer does not have enough space and [isExpanding] is false, will
  /// throw [RawWriterException].
  void ensureAvailableLength(int length) {
    // See whether old buffer has enough capacity.
    final oldByteData = this._byteData;
    final minCapacity = this._length + length;
    if (oldByteData.lengthInBytes >= minCapacity) {
      return;
    }

    if (!isExpanding) {
      throw RawWriterException(
          "ensureAvailaleLength($length) was called, but only ${oldByteData.lengthInBytes - this._length} bytes is available");
    }

    // Choose a new capacity that's a power of 2.
    var newCapacity = 64;
    while (newCapacity < minCapacity) {
      newCapacity *= 2;
    }

    // Switch to the new buffer.
    _byteData = new ByteData(newCapacity);
    final oldIndex = this._length;
    this._length = 0;

    // Write contents of the old buffer.
    //
    // We write the whole buffer so we eliminate complex bugs when index is
    // non-monotonic or data is written directly.
    writeByteData(oldByteData);

    this._length = oldIndex;
  }

  /// Returns a copy of the written bytes. The length will be equal to [length].
  ByteData toByteDataCopy() {
    final length = this._length;
    final result = new ByteData(length);
    final writer = new RawWriter.withByteData(result);
    writer.writeByteData(_byteData, 0, length);
    return result;
  }

  /// Returns a view at the written bytes. The length will be equal to [length].
  ByteData toByteDataView() {
    final byteData = this._byteData;
    final length = this._length;
    if (length == byteData.lengthInBytes) {
      return byteData;
    }
    return new ByteData.view(
      byteData.buffer,
      byteData.offsetInBytes,
      length,
    );
  }

  /// Returns a copy of the written bytes. The length will be equal to [length].
  Uint8List toUint8ListCopy() {
    // Create a copy
    final byteData = toByteDataCopy();

    // Return a view at the copy
    return new Uint8List.view(
      byteData.buffer,
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
  }

  /// Returns a view at the written bytes. The length will be equal to [length].
  Uint8List toUint8ListView() {
    final byteData = this._byteData;
    return new Uint8List.view(
      byteData.buffer,
      byteData.offsetInBytes,
      this._length,
    );
  }

  /// Writes bytes from [ByteData].
  void writeByteData(ByteData value, [int index = 0, int? writtenLength]) {
    var calculatedWrittenLength = writtenLength ?? value.lengthInBytes - index;
    ensureAvailableLength(calculatedWrittenLength);

    final byteData = this._byteData;
    var bufferLength = this._length;
    if (calculatedWrittenLength >= _minLengthForUin32CopyMethod) {
      final hostEndian = Endian.host;
      while (calculatedWrittenLength >= 4) {
        byteData.setUint32(
          bufferLength,
          value.getUint32(index, hostEndian),
          hostEndian,
        );
        bufferLength += 4;
        index += 4;
        calculatedWrittenLength -= 4;
      }
    }
    while (calculatedWrittenLength > 0) {
      byteData.setUint8(bufferLength, value.getUint8(index));
      bufferLength++;
      index++;
      calculatedWrittenLength--;
    }
    this._length = bufferLength;
  }

  /// Writes bytes from a list.
  void writeBytes(List<int> value, [int index = 0, int? writtenLength]) {
    if (writtenLength == null) {
      writtenLength = value.length - index;
    }
    if (writtenLength >= _minLengthForUin32CopyMethod && value is Uint8List) {
      writeByteData(
        new ByteData.view(
          value.buffer,
          value.offsetInBytes + index,
          writtenLength,
        ),
      );
      return;
    }
    ensureAvailableLength(writtenLength);

    final buffer = this._byteData;
    var bufferIndex = this._length;
    for (final end = index + writtenLength; index < end; index++) {
      buffer.setUint8(bufferIndex, value[index]);
      bufferIndex++;
    }
    this._length = bufferIndex;
  }

  /// Writes 64-bit integer (Int64 from _'package:fixnum'_).
  void writeFixInt64(Int64 value, [Endian endian = Endian.big]) {
    ensureAvailableLength(8);

    final bytes = value.toBytes();
    final length = this._length;
    if (endian == Endian.little) {
      for (var i = 0; i < bytes.length; i++) {
        _byteData.setUint8(length + 7 - i, bytes[i]);
      }
    } else {
      for (var i = 0; i < bytes.length; i++) {
        _byteData.setUint8(length + i, bytes[i]);
      }
    }
    this._length = length + 8;
  }

  /// Writes a 32-bit floating-point value.
  void writeFloat32(double value, [Endian endian = Endian.big]) {
    ensureAvailableLength(4);

    final length = this._length;
    _byteData.setFloat32(length, value, endian);
    this._length = length + 4;
  }

  /// Writes a 64-bit floating-point value.
  void writeFloat64(double value, [Endian endian = Endian.big]) {
    ensureAvailableLength(8);

    final length = this._length;
    _byteData.setFloat64(length, value, endian);
    this._length = length + 8;
  }

  /// Writes an 16-bit signed integer.
  void writeInt16(int value, [Endian endian = Endian.big]) {
    ensureAvailableLength(2);

    final length = this._length;
    _byteData.setInt16(length, value, endian);
    this._length = length + 2;
  }

  /// Writes a 32-bit signed integer.
  void writeInt32(int value, [Endian endian = Endian.big]) {
    ensureAvailableLength(4);

    final length = this._length;
    _byteData.setInt32(length, value, endian);
    this._length = length + 4;
  }

  /// Writes an 8-bit signed integer.
  void writeInt8(int value) {
    ensureAvailableLength(1);

    final length = this._length;
    _byteData.setInt8(length, value);
    this._length = length + 1;
  }

  /// Writes a [SelfEncoder].
  void writeSelfEncoder(SelfEncoder encoder) {
    encoder.encodeSelf(this);
  }

  /// Writes a 16-bit unsigned integer.
  void writeUint16(int value, [Endian endian = Endian.big]) {
    ensureAvailableLength(2);

    final length = this._length;
    _byteData.setUint16(length, value, endian);
    this._length = length + 2;
  }

  /// Writes a 32-bit unsigned integer.
  void writeUint32(int value, [Endian endian = Endian.big]) {
    ensureAvailableLength(4);

    final length = this._length;
    _byteData.setUint32(length, value, endian);
    this._length = length + 4;
  }

  /// Writes an 8-bit unsigned integer.
  void writeUint8(int value) {
    ensureAvailableLength(1);

    final length = this._length;
    _byteData.setUint8(length, value);
    this._length = length + 1;
  }

  /// Writes an UTF-8 string.
  /// Returns number of written bytes.
  int writeUtf8(String value, {int? maxLengthInBytes}) {
    // Write until the first multi-byte rune.
    final multiByteRuneIndex = _writeUtf8Simple(value);
    if (multiByteRuneIndex < 0) {
      // All runes were single-byte.
      return value.length;
    }

    // Remove written prefix.
    value = value.substring(multiByteRuneIndex);

    // Write the rest using UTF8-encoder
    final utf8Bytes = utf8.encode(value);
    if (maxLengthInBytes != null && utf8Bytes.length >= maxLengthInBytes) {
      throw new ArgumentError.value(
        value,
        "value",
        "string exceeds maximum length ($maxLengthInBytes) when encoded to UTF-8",
      );
    }
    writeBytes(utf8Bytes);
    return utf8Bytes.length;
  }

  /// Writes an UTF-8 string.
  /// Returns number of written bytes, including the final null-character.
  ///
  /// Throws [ArgumentError] if any rune is 0.
  int writeUtf8NullEnding(String value, {int? maxLengthInBytes}) {
    for (var i = 0; i < value.length; i++) {
      if (value.codeUnitAt(i) == 0) {
        throw new ArgumentError.value(value, "value", "contains null byte");
      }
    }
    final n = writeUtf8(value);
    writeUint8(0);
    return n + 1;
  }

  /// Writes an UTF-8 string.
  ///
  /// Validates that all runes take only a single byte in UTF-8.
  /// Throws [ArgumentError] if any rune is greater than 127.
  void writeUtf8Simple(String value) {
    final multiByteRuneIndex = _writeUtf8Simple(value);
    if (multiByteRuneIndex < 0) {
      // All bytes were 0..127
      return;
    }
    throw new ArgumentError.value(
        value, "value", "encountered a multi-byte rune at $multiByteRuneIndex");
  }

  /// Writes a null-delimited UTF-8 string.
  /// Validates that all runes take only a single byte in UTF-8.
  ///
  /// Throws [ArgumentError] if any rune is 0 or greater than 127.
  void writeUtf8SimpleNullEnding(String value) {
    ensureAvailableLength(value.length + 1);

    final byteData = this._byteData;
    var length = this._length;
    for (var i = 0; i < value.length; i++) {
      final byte = value.codeUnitAt(i);
      if (byte == 0 || byte > 0x7F) {
        throw new ArgumentError.value(value);
      }
      byteData.setUint8(length, byte);
      length++;
    }
    byteData.setUint8(length, 0);
    length++;
    this._length = length;
  }

  /// Writes variable-length signed integer.
  void writeVarInt(int value) {
    if (value < 0) {
      writeVarUint(-2 * value - 1);
    } else {
      writeVarUint(2 * value);
    }
  }

  /// Writes variable-length unsigned integer.
  void writeVarUint(int value) {
    if (value < 0) {
      throw new ArgumentError.value(value);
    }
    while (true) {
      final byte = 0x7F & value;
      final nextValue = value >> 7;
      if (nextValue == 0) {
        writeUint8(byte);
        return;
      }
      writeUint8(0x80 | byte);
      value = nextValue;
    }
  }

  /// Writes N zeroes.
  void writeZeroes(int writtenLength) {
    ensureAvailableLength(writtenLength);
    final byteData = this._byteData;
    var bufferLength = this._length;
    while (writtenLength >= 4) {
      byteData.setUint32(bufferLength, 0);
      bufferLength += 4;
      writtenLength -= 4;
    }
    while (writtenLength > 0) {
      byteData.setUint8(bufferLength, 0);
      bufferLength++;
      writtenLength--;
    }
    this._length = bufferLength;
  }

  /// Writes UTF-8 runes until a multi-byte rune is encountered.
  ///
  /// Returns index of the first multi-byte rune.
  /// Return value -1 means that all runes were single-byte.
  int _writeUtf8Simple(String value) {
    ensureAvailableLength(value.length);

    final byteData = this._byteData;
    var length = this._length;
    for (var i = 0; i < value.length; i++) {
      final byte = value.codeUnitAt(i);
      if (byte > 0x7F) {
        this._length = length;
        return i;
      }
      byteData.setUint8(length, byte);
      length++;
    }
    this._length = length;
    return -1;
  }
}

/// Thrown by [RawWriter].
class RawWriterException implements Exception {
  final String message;

  RawWriterException(this.message);

  @override
  String toString() => message;
}
