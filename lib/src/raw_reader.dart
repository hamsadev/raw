import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:raw/raw.dart' show DebugHexEncoder;

import 'raw_writer.dart';

class RawReader {
  /// Whether returned typed data slices should be copies.
  final bool isCopyOnRead;

  final ByteData _byteData;

  /// Current index in the buffer.
  int index;

  RawReader.withByteData(
    this._byteData, {
    this.index: 0,
    this.isCopyOnRead: true,
  });

  factory RawReader.withBytes(List<int> bytes, {bool isCopyOnRead = true}) {
    ByteData byteData;
    if (bytes is Uint8List) {
      // Use existing buffer
      byteData = new ByteData.view(
        bytes.buffer,
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
    } else {
      // Allocate a new buffer
      byteData = new ByteData(bytes.length);

      // Copy bytes to the new buffer
      final writer = new RawWriter.withByteData(byteData, isExpanding: false);
      writer.writeBytes(bytes);
    }
    return new RawReader.withByteData(
      byteData,
      isCopyOnRead: isCopyOnRead,
    );
  }

  /// Returns the number of bytes remaining.
  int get availableLengthInBytes => _byteData.lengthInBytes - index;

  /// Returns the buffer as [ByteData].
  ByteData get bufferAsByteData => _byteData;

  /// Returns the buffer as [Uint8List].
  Uint8List get bufferAsUint8List {
    final byteData = this._byteData;
    return Uint8List.view(
        byteData.buffer, byteData.offsetInBytes, byteData.lengthInBytes);
  }

  /// Returns true if there are no more bytes available.
  bool get isEndOfBytes => index == _byteData.lengthInBytes;

  /// Returns the number of bytes before the next zero byte.
  ///
  /// If `maxLength` is null, throws [RawReaderException] if zero is not found.
  /// Otherwise returns `maxLength if zero is not found.
  int lengthUntilZero({int? maxLength}) {
    final byteData = this._byteData;
    final start = this.index;
    int end;
    if (maxLength == null) {
      end = _byteData.lengthInBytes;
    } else {
      end = start + maxLength;
    }
    for (var i = start; i < end; i++) {
      if (byteData.getUint8(i) == 0) {
        return i - start;
      }
    }
    if (maxLength != null) {
      return maxLength;
    }
    throw _eofException(start, "sequence of bytes terminated by zero");
  }

  /// Previews a future uint16 without advancing in the byte list.
  int previewUint16(int index, [Endian endian = Endian.big]) {
    return _byteData.getUint16(this.index + index, endian);
  }

  /// Previews a future uint32 without advancing in the byte list.
  int previewUint32(int index, [Endian endian = Endian.big]) {
    return _byteData.getUint32(this.index + index, endian);
  }

  /// Previews a future uint8 without advancing in the byte list.
  int previewUint8(int index) {
    return _byteData.getUint8(this.index + index);
  }

  /// Returns the next `length` bytes.
  /// The method always returns a new copy of the bytes.
  ///
  /// Increments index by `length`.
  ByteData readByteDataCopy(int length) {
    final byteData = this._byteData;
    final result = new ByteData(length);
    var i = 0;

    // If 128 or more bytes, we read in 4-byte chunks.
    // This should be faster.
    //
    // This constant is just a guess of a good minimum.
    if (length >> 7 != 0) {
      final optimizedDestination = new Uint32List.view(
          result.buffer, result.offsetInBytes, result.lengthInBytes);
      while (i + 3 < length) {
        // Copy in 4-byte chunks.
        // We must use host endian during reading.
        optimizedDestination[i] = byteData.getUint32(index + i, Endian.host);
        i += 4;
      }
    }
    for (; i < result.lengthInBytes; i++) {
      result.setUint8(i, byteData.getUint8(index + i));
    }
    this.index = index + length;
    return result;
  }

  /// Returns the next `length` bytes.
  ///
  /// If [isCopyOnRead] is true, the method will return a new copy of the bytes.
  /// Otherwise the method will return a view at the bytes.
  ///
  /// Increments index by `length`.
  ByteData readByteDataViewOrCopy(int? length) {
    if (length == null) {
      length = availableLengthInBytes;
    } else if (length > _byteData.lengthInBytes - index) {
      throw new ArgumentError.value(length, "length");
    }
    if (isCopyOnRead) {
      return readByteDataCopy(length);
    }
    return _readByteDataView(length);
  }

  /// Reads a 64-bit signed integer as _Int64_ (from _'package:fixnum'_).
  /// Increments index by 8.
  Int64 readFixInt64([Endian endian = Endian.big]) {
    final bytes = readUint8ListCopy(8);
    if (endian == Endian.little) {
      return new Int64.fromBytes(bytes);
    } else {
      return new Int64.fromBytesBigEndian(bytes);
    }
  }

  /// Reads a 32-bit floating-point value.
  /// Increments index by 4.
  double readFloat32([Endian endian = Endian.big]) {
    final byteData = this._byteData;
    final index = this.index;
    final newIndex = index + 4;
    if (newIndex > byteData.lengthInBytes) {
      throw _eofException(index, "float32");
    }
    final value = byteData.getFloat32(index, endian);
    this.index = newIndex;
    return value;
  }

  /// Reads a 64-bit floating-point value.
  /// Increments index by 8.
  double readFloat64([Endian endian = Endian.big]) {
    final byteData = this._byteData;
    final index = this.index;
    final newIndex = index + 8;
    if (newIndex > byteData.lengthInBytes) {
      throw _eofException(index, "float64");
    }
    final value = _byteData.getFloat64(index, endian);
    this.index = index + 8;
    return value;
  }

  /// Reads a 32-bit signed integer.
  /// Increments index by 2.
  int readInt16([Endian endian = Endian.big]) {
    final byteData = this._byteData;
    final index = this.index;
    final newIndex = index + 2;
    if (newIndex > byteData.lengthInBytes) {
      throw _eofException(index, "int16");
    }
    final value = _byteData.getInt16(index, endian);
    this.index = index + 2;
    return value;
  }

  /// Reads a 32-it signed integer.
  /// Increments index by 4.
  int readInt32([Endian endian = Endian.big]) {
    final byteData = this._byteData;
    final index = this.index;
    final newIndex = index + 4;
    if (newIndex > byteData.lengthInBytes) {
      throw _eofException(index, "int32");
    }
    final value = _byteData.getInt32(index, endian);
    this.index = index + 4;
    return value;
  }

  /// Reads an 8-bit signed integer.
  /// Increments index by 1.
  int readInt8() {
    final byteData = this._byteData;
    final index = this.index;
    final newIndex = index + 1;
    if (newIndex > byteData.lengthInBytes) {
      throw _eofException(index, "int8");
    }
    final value = _byteData.getInt8(index);
    this.index = index + 1;
    return value;
  }

  /// Returns a new RawReader that is backed by a span of this RawReader.
  RawReader readRawReader(int length) {
    final byteData = this._byteData;
    final index = this.index;
    final result = new RawReader.withByteData(
      new ByteData.view(
        byteData.buffer,
        byteData.offsetInBytes + index,
        length,
      ),
    );
    this.index = index + length;
    return result;
  }

  /// Reads a 16-bit unsigned integer.
  /// Increments index by 2.
  int readUint16([Endian endian = Endian.big]) {
    final byteData = this._byteData;
    final index = this.index;
    final newIndex = index + 2;
    if (newIndex > byteData.lengthInBytes) {
      throw _eofException(index, "uint16");
    }
    final value = _byteData.getUint16(index, endian);
    this.index = index + 2;
    return value;
  }

  /// Reads a 32-bit unsigned integer.
  /// Increments index by 4.
  int readUint32([Endian endian = Endian.big]) {
    final byteData = this._byteData;
    final index = this.index;
    final newIndex = index + 4;
    if (newIndex > byteData.lengthInBytes) {
      throw _eofException(index, "uint32");
    }
    final value = _byteData.getUint32(index, endian);
    this.index = index + 4;
    return value;
  }

  /// Reads an 8-bit unsigned integer.
  /// Increments index by 1.
  int readUint8() {
    final byteData = this._byteData;
    final index = this.index;
    final newIndex = index + 1;
    if (newIndex > byteData.lengthInBytes) {
      throw _eofException(index, "uint8");
    }
    final value = _byteData.getUint8(index);
    this.index = index + 1;
    return value;
  }

  /// Returns the next bytes. Length is determined by the argument.
  /// The method always returns a new copy of the bytes.
  Uint8List readUint8ListCopy([int? length]) {
    if (length == null) {
      length = availableLengthInBytes;
    } else if (length > _byteData.lengthInBytes - index) {
      throw new ArgumentError.value(length, "length");
    }
    final result = new Uint8List(length);
    var i = 0;

    // If 128 or more bytes, we read in 4-byte chunks.
    // This should be faster.
    //
    // This constant is just a guess of a good minimum.
    if (length >> 7 != 0) {
      final optimizedDestination = new Uint32List.view(
        result.buffer,
        result.offsetInBytes,
        result.lengthInBytes,
      );
      while (i + 3 < length) {
        // Copy in 4-byte chunks.
        // We must use host endian during reading.
        optimizedDestination[i] = _byteData.getUint32(index + i, Endian.host);
        i += 4;
      }
    }
    for (var i = 0; i < result.length; i++) {
      result[i] = _byteData.getUint8(index + i);
    }
    this.index = index + length;
    return result;
  }

  /// Returns the next bytes. Length is determined by the argument.
  ///
  /// If [isCopyOnRead] is true, the method will return a new copy of the bytes.
  /// Otherwise the method will return a view at the bytes.
  Uint8List readUint8ListViewOrCopy(int? length) {
    if (length == null) {
      length = availableLengthInBytes;
    } else if (length > _byteData.lengthInBytes - index) {
      throw new ArgumentError.value(length, "length");
    }
    if (isCopyOnRead) {
      return readUint8ListCopy(length);
    }
    return _readUint8ListView(length);
  }

  /// Reads an UTF-8 string.
  String readUtf8(int length) {
    final bytes = _readUint8ListView(length);
    return utf8.decode(bytes);
  }

  /// Reads a null-terminated UTF-8 string.
  String readUtf8NullEnding() {
    var length = lengthUntilZero();
    final result = readUtf8(length);
    readUint8();
    return result;
  }

  /// Reads an UTF-8 string. Throws [RawReaderException] if a multi-byte rune is
  /// encountered.
  String readUtf8Simple(int length) {
    final bytes = _readUint8ListView(length);
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] >= 128) {
        throw _newException(
          "Expected UTF-8 with single-byte runes, found a rune that's not single-byte",
          index: index - length + i,
        );
      }
    }
    return new String.fromCharCodes(bytes);
  }

  /// Reads an UTF-8 string delimited by a zero-byte. Throws
  /// [RawReaderException] if a multi-byte rune is encountered.
  String readUtf8SimpleNullEnding(int length) {
    var length = lengthUntilZero();
    final result = readUtf8Simple(length);
    readUint8();
    return result;
  }

  /// Reads a variable-length signed integer.
  /// Compatible with [Protocol Buffers encoding](https://developers.google.com/protocol-buffers/docs/encoding).
  int readVarInt() {
    final value = readVarUint();
    if (value % 2 == 0) {
      return value ~/ 2;
    }
    return (value ~/ -2) - 1;
  }

  /// Reads a variable-length unsigned integer.
  /// Compatible with [Protocol Buffers encoding](https://developers.google.com/protocol-buffers/docs/encoding).
  int readVarUint() {
    final byteData = this._byteData;
    final start = this.index;
    var index = start;
    var result = 0;
    for (var i = 0; i < 64; i += 7) {
      if (index >= byteData.lengthInBytes) {
        throw _eofException(index, "VarUint");
      }
      final byte = byteData.getUint8(index);
      index++;
      result |= (0x7F & byte) << i;
      if (0x80 & byte == 0) {
        break;
      }
    }
    this.index = index;
    return result;
  }

  /// Reads N bytes and verifies that every one is zero.
  void readZeroes(int length) {
    final start = this.index;
    while (length > 0) {
      final value = readUint8();
      if (value != 0) {
        throw _newException(
            "expected $length zero bytes found a non-zero byte after ${this.index - 1 - start} bytes",
            index: start);
      }
    }
  }

  RawReaderException _eofException(int index, String type) {
    return _newException(
      "Expected $type at $index, encountered EOF after ${_byteData.lengthInBytes - index} bytes.",
    );
  }

  RawReaderException _newException(String message, {int? index}) {
    index ??= this.index;
    var snippetStart = index - 16;
    if (snippetStart < 0) {
      snippetStart = 0;
    }
    var snippetEnd = index + 16;
    if (snippetEnd > _byteData.lengthInBytes) {
      snippetEnd = _byteData.lengthInBytes;
    }
    final byteData = this._byteData;
    final snippet = new Uint8List.view(
      byteData.buffer,
      byteData.offsetInBytes + snippetStart,
      snippetEnd - snippetStart,
    );
    return new RawReaderException(
      message,
      index: index,
      snippet: snippet,
      snippetIndex: index - snippetStart,
    );
  }

  ByteData _readByteDataView(int length) {
    final byteData = this._byteData;
    final index = this.index;
    final result = new ByteData.view(
      byteData.buffer,
      byteData.offsetInBytes + index,
      length,
    );
    this.index = index + length;
    return result;
  }

  Uint8List _readUint8ListView(int length) {
    final byteData = this._byteData;
    final index = this.index;
    final result = new Uint8List.view(
      byteData.buffer,
      byteData.offsetInBytes + index,
      length,
    );
    this.index = index + length;
    return result;
  }
}

/// Thrown by [RawReader].
class RawReaderException implements Exception {
  final String message;
  final int index;
  final Uint8List snippet;
  final int snippetIndex;

  RawReaderException(this.message,
      {required this.index, required this.snippet, required this.snippetIndex});

  @override
  String toString() {
    final snippet = const DebugHexEncoder().convert(this.snippet);
    return "Error at ${index}: $message\nBytes ${index}..${index + snippetIndex}..${index + snippet.length}: $snippet";
  }
}
