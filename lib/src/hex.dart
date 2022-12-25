import 'dart:convert';
import 'dart:typed_data';

/// Converts various hex formats to [Uint8List].
///
/// Rules for interpreting lines are:
///   * Skip possible whitespace prefix.
///   * Skip possible location prefix (number + ":" + whitespace).
///   * Read the first group of hexadecimal digits. It must have even number of digits.
///   * Every successive non-whitespace hexadecimal digit group with the equal or shorter length is interpreted as bytes.
///   * The rest of the line is ignored.
///
/// Examples of valid lines:
///   * "0000000: 0123 4567 89ab cdef 0123 4567 89ab cdef ................"
///   * "0000010: 012345678 ............ # comment"
///   * "abcdef // no prefix"
///
class DebugHexDecoder extends Converter<String, Uint8List> {
  static final RegExp _prefixRegExp = new RegExp(
    r"^\s*(?:0x)?[0-9a-fA-F]+:\s+",
  );
  static final RegExp _hexRegExp = new RegExp(
    r"^(?:0x)?([0-9a-f-AF]+),?(?:\s+|$)",
  );

  const DebugHexDecoder();

  @override
  Uint8List convert(String s) {
    var result = new Uint8List(64);
    var resultLength = 0;
    var lineNumber = 0;
    for (var line in s.split("\n")) {
      lineNumber++;

      // Remove prefix
      final match = _prefixRegExp.matchAsPrefix(line);
      if (match != null) {
        line = line.substring(match.end);
      }

      int? firstGroupLength;

      // For each hexadecimal digit group
      while (true) {
        // Match hexadecimical characters
        final match = _hexRegExp.matchAsPrefix(line);
        if (match == null) {
          break;
        }
        final group = match.group(1)!;
        line = line.substring(match.end);

        // Validate group length
        if (group.length % 2 != 0) {
          throw new ArgumentError(
            "Error at line $lineNumber: invalid group of hexadecimal digits (non-even length): '$group'",
          );
        }
        if (firstGroupLength == null) {
          firstGroupLength = group.length;
        } else if (group.length > firstGroupLength) {
          // Longer than the first group.
          // Conclude that it's not a hex group anymore.
          break;
        }

        // Parse bytes
        for (var i = 0; i < group.length; i += 2) {
          final byteString = group.substring(i, i + 2);
          int byte;
          try {
            byte = int.parse(byteString, radix: 16);
          } catch (e) {
            throw new ArgumentError.value(
              "Error at line $lineNumber: '$byteString' is not hex",
            );
          }

          // Ensure that the buffer has capacity left
          if (resultLength == result.lengthInBytes) {
            final oldResult = result;
            result = new Uint8List(2 * resultLength);
            result.setAll(0, oldResult);
          }

          // Set byte
          result[resultLength] = byte;
          resultLength++;
        }
      }
    }
    return new Uint8List.view(result.buffer, 0, resultLength);
  }
}

/// Converts bytes to a hex-based descriptions.
///
/// By default, converts bytes to the following format:
/// ```
/// 0x0000: 0123 4567 89ab cdef  0123 4567 89ab cdef
///     (0)
/// 0x0010: 0123 4567 89ab cdef  0123 4567 89ab cdef
///    (16)
/// ```
///
/// If optional parameter `expected` is given, the format is:
///
/// ```
/// 0x0000: 0123 5555 89ab cdef  0123 4567 89ab cdef
///     (0)      ^ ^^                                 <-- index of the first error: 0x02 (decimal: 2)
///              4 67
/// 0x0010: 0123 4567 89ab cdef  0123 4567 89
///    (16)                                  ^^ ^^^^  <-- index of the first error: 0x0D (decimal: 13)
///                                          ab cdef
/// ```
class DebugHexEncoder extends Converter<Iterable, String> {
  final int bytesPerRow;
  final List<int> groups;

  const DebugHexEncoder({this.bytesPerRow = 16, this.groups = const [2, 4]});

  String convert(Iterable iterable, {List<int>? expected}) {
    if (iterable.isEmpty && expected == null) {
      return "(no bytes)";
    }
    final sb = new StringBuffer();

    // Print "\n" so the first actual line will be aligned with the second one.
    sb.write("\n");

    final list = iterable.toList();
    var maxLength = list.length;
    if (expected != null && expected.length > maxLength) {
      maxLength = expected.length;
    }

    void maybePrintDifferenceLine(int start, int end) {
      if (expected == null) {
        return;
      }
      var equal = true;
      for (var i = start; i < end; i++) {
        if (i >= list.length ||
            i >= expected.length ||
            list[i] != expected[i]) {
          equal = false;
          break;
        }
      }
      const prefix = "        ";
      sb.write("(${start})".padLeft(prefix.length - 1, " "));
      if (equal) {
        // Print empty line
        sb.write("\n");
        // Print empty line
        sb.write("\n");
        return;
      }
      sb.write(" ");

      // Print markings
      var printExpectedBytes = false;
      int? firstAt;
      final lineSb = new StringBuffer();
      for (var i = start; i < end; i++) {
        lineSb.write(getSpaceBefore(i));
        if (i >= list.length) {
          lineSb.write("^^"); // "Should be inserted"
          printExpectedBytes = true;
          firstAt ??= i;
        } else if (i >= expected.length) {
          lineSb.write("--"); // "Should be deleted"
          firstAt ??= i;
        } else if (list[i] != expected[i]) {
          lineSb.write("^^"); // "Should be changed"
          printExpectedBytes = true;
          firstAt ??= i;
        } else {
          lineSb.write("  "); // "OK"
        }
      }
      if (firstAt != null && firstAt > start) {
        lineSb.write("  <-- index of the first error: 0x");
        lineSb.write(firstAt.toRadixString(16).toUpperCase());
        lineSb.write(" (decimal: $firstAt)");
      }
      sb.write(lineSb.toString().trimRight());
      sb.write("\n");

      if (printExpectedBytes) {
        final lineSb = new StringBuffer();
        // Print another line for expected bytes
        lineSb.write(prefix);
        for (var i = start; i < end; i++) {
          lineSb.write(getSpaceBefore(i));
          if (i < expected.length &&
              (i >= list.length || list[i] != expected[i])) {
            // "Should be this byte"
            lineSb.write(expected[i].toRadixString(16).padLeft(2, "0"));
          } else {
            // "OK"
            lineSb.write("  ");
          }
        }
        sb.write(lineSb.toString().trimRight());
        sb.write("\n");
        // Print empty line
        sb.write("\n");
      } else {
        // Print empty line
        sb.write("\n");
      }
    }

    var rowStart = 0;
    for (var i = 0; i < maxLength; i++) {
      if (i % bytesPerRow == 0) {
        // Beginning of a row
        if (i > 0) {
          // Not the first row
          sb.write("\n");
          if (i > 0) {
            maybePrintDifferenceLine(
              rowStart,
              i,
            );
            rowStart = i;
          }
        }
        sb.write("0x");
        sb.write(i.toRadixString(16).padLeft(4, "0").toUpperCase());
        sb.write(": ");
      }
      sb.write(getSpaceBefore(i));
      if (i >= list.length) {
        sb.write(" ");
        continue;
      }
      final item = list[i];
      if (item is int) {
        sb.write(item.toRadixString(16).padLeft(2, "0"));
      } else {
        sb.write("{ ");
        sb.write(item);
        sb.write(" }");
      }
    }
    sb.write("\n");
    maybePrintDifferenceLine(
      rowStart,
      maxLength,
    );
    return sb.toString();
  }

  String getSpaceBefore(int i) {
    var s = "";
    for (var group in groups) {
      if (i % bytesPerRow == 0) {
        return "";
      }
      if (i % group == 0) {
        s += " ";
      }
    }
    return s;
  }
}
