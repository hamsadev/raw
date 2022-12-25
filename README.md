# Introduction
A package for writing, reading, and debugging binary data.


## Issues & contributing
  * Found a bug? Create an issue [in Github](https://github.com/terrier989/dart-raw/issues).
  * Contributing code? Create a pull request [in Github](https://github.com/terrier989/dart-raw).


# A walkthrough
## Key classes
  * [RawWriter](https://pub.dartlang.org/documentation/raw/latest/raw/RawWriter-class.html):
    * Writes bytes to a buffer.
    * Automatically expands the buffer when `isExpanding` is true.
  * [RawReader](https://pub.dartlang.org/documentation/raw/latest/raw/RawReader-class.html):
    * Reads bytes from a buffer.
    * If reading fails, throw descriptive exceptions.
  * [SelfEncoder](https://pub.dartlang.org/documentation/raw/latest/raw/SelfEncoder-class.html)
    * Classes that know how to encode state using _RawWriter_.
  * [SelfDecoder](https://pub.dartlang.org/documentation/raw/latest/raw/SelfDecoder-class.html)
    * Classes that know how to decode state using _RawReader_.
  * [SelfCodec](https://pub.dartlang.org/documentation/raw/latest/raw/SelfCodec-class.html)
    * Classes that implement both _SelfEncoder_ and _SelfDecoder_.

## Example of SelfCodec
A typical implementation of _SelfCodec_ looks like this:
```dart
class MyStruct extends SelfCodec {
  int intField = 0;
  String stringField = "";
  
  @override
  void encodeSelf(RawWriter writer) {
    writer.writeInt32(intField);
    writer.writeUint32(stringField.length, Endian.little);
    writer.writeUtf8(stringField);
  }
  
  @override
  void decodeSelf(RawReader reader) {
    intField = reader.readInt32();
    final stringLength = reader.readUint32(Endian.little);
    stringField = reader.readUtf(stringLength);
  }
}
```

## Supported primitives
  * Numeric types
    * Unsigned/signed integers
      * `Uint8` / `Int8`
      * `Uint16` / `Int16`
      * `Uint32` / `Int32`
      * `FixInt64` / `FixInt64` (_Int64_ from [fixnum](https://pub.dartlang.org/packages/fixnum))
    * Floating- point values
      * `Float32`
      * `Float64`
    * Variable-length integers (identical with [Protocol Buffers encoding](https://developers.google.com/protocol-buffers/docs/encoding))
      * `VarUint`
      * `VarInt`
  * Sequence types
    * Uint8List
    * ByteData
    * Strings
      * `Utf8` / `Utf8NullEnding`
      * `Utf8Simple` / `Utf8SimpleNullEnding`
        * Validates that every byte is less than 128.
    * Zeroes


## Helpers for testing
```dart
import 'package:test/test.dart';
import 'package:raw/raw_test.dart';

void main() {
  test("an example", () {
    final value = [9,8,7];
    final expected = [1,2,3];
    expect(value, byteListEquals(expected));
    
    // Output:
    // 0x0000: 0908 07
    //     (0) ^^^^ ^^
    //         0102 03
  });
}
```

If your class implements _SelfEncoder_, use _selfEncoderEquals_:

```dart
class MyStruct extends SelfCodec {
  // ...
}

void main() {
  test("an example", () {
    // ...
    expect(myStruct, selfEncoderEquals(expected));
  });
}
```


## Converting hex formats to bytes

[DebugHexDecoder](https://pub.dartlang.org/documentation/raw/latest/raw/DebugHexDecoder-class.html) is able to import hex formats such as:
  * "0000000: 0123 4567 89ab cdef 0123 4567 89ab cdef ................"
  * "0000010: 012345678 ............ # comment"
  * "012345678abcdef // no prefix"


## Converting bytes to hex-based descriptions

[DebugHexEncoder](https://pub.dartlang.org/documentation/raw/latest/raw/DebugHexEncoder-class.html) converts bytes to the following format:
```
0x0000: 0123 4567 89ab cdef  0123 4567 89ab cdef
    (0)
0x0010: 0123 4567 89ab cdef  0123 4567 89ab cdef
   (16)
```

If expected byte list is specified, bytes are converted to the following format:
```
0x0000: 0123 5555 89ab cdef  0123 4567 89ab cdef
    (0)      ^ ^^                                 <-- index of the first error: 0x02 (decimal: 2)
             4 67
0x0010: 0123 4567 89ab cdef  0123 4567 89
   (16)                                  ^^ ^^^^  <-- index of the first error: 0x0D (decimal: 13)
                                         ab cdef
```