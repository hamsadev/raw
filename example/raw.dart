import 'package:raw/raw.dart';

class ExampleStruct extends SelfCodec {
  int intField = 0;
  String stringField = "";

  @override
  void decodeSelf(RawReader reader) {
    intField = reader.readVarInt();
    stringField = reader.readUtf8NullEnding();
  }

  @override
  void encodeSelf(RawWriter writer) {
    writer.writeVarInt(intField);
    writer.writeUtf8(stringField);
  }
}
