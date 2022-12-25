import 'raw_reader.dart';
import 'raw_writer.dart';
import 'self_codec.dart';

/// A simple [SelfEncoder] that holds bytes.
class RawData extends SelfEncoder {
  static final RawData empty = new RawData(const []);

  final List<int> bytes;

  const RawData(this.bytes);

  factory RawData.decode(RawReader reader, int? length) {
    length ??= reader.availableLengthInBytes;
    if (length == 0) {
      return empty;
    }
    return new RawData(reader.readUint8ListViewOrCopy(length));
  }

  @override
  int encodeSelfCapacity() => bytes.length;

  @override
  void encodeSelf(RawWriter writer) {
    writer.writeBytes(bytes);
  }

  String toString() => "[Raw data with length ${bytes.length}]";
}
