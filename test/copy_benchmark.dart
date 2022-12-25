import 'dart:typed_data';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:raw/raw.dart';

void main() {
  const minLength = 128;

  // Aligned copy, uint8 chunks
  new CopyBenchmark(0, 0, minLength - 1).report();
  // Aligned copy, uint32 chunks + uint8 chunks
  new CopyBenchmark(0, 0, minLength + 1).report();

  // Non-aligned copy, uint8 chunks
  new CopyBenchmark(63, 63, minLength - 1).report();
  // Non-aligned copy, uint32 chunks + uint8 chunks
  new CopyBenchmark(63, 63, minLength + 1).report();
}

class CopyBenchmark extends BenchmarkBase {
  final int times = 100;
  final int destinationIndex;
  final int sourceIndex;
  final int length;
  late Uint8List _source;
  late RawWriter _destination;

  CopyBenchmark(this.destinationIndex, this.sourceIndex, this.length)
      : super(
          "Write Uint8List: destinationIndex=$destinationIndex sourceIndex=$sourceIndex length=$length",
        );

  @override
  void setup() {
    _source = new Uint8List(sourceIndex + length);
    for (var i = 0; i < _source.length; i++) {
      _source[i] = i % 256;
    }
    _destination =
        new RawWriter.withCapacity(destinationIndex + times * length);
    super.setup();
  }

  @override
  void run() {
    for (var i = 0; i < times; i++) {
      // Copy from source to destination
      _destination.writeBytes(_source, sourceIndex, length);
    }
  }
}
