import 'src/hex.dart' as hex;
import 'src/raw_reader.dart' as raw_reader;
import 'src/raw_writer.dart' as raw_writer;
import 'src/self_codec.dart' as self_codec;
import 'src/uint32.dart' as uint32;

void main() {
  hex.main();
  raw_writer.main();
  raw_reader.main();
  self_codec.main();
  uint32.main();
}
