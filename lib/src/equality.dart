import 'dart:typed_data';

import 'package:collection/collection.dart';

class ByteDataEquality implements Equality<ByteData> {
  const ByteDataEquality();

  @override
  bool equals(ByteData e1, ByteData e2) {
    if (e1.lengthInBytes != e2.lengthInBytes) {
      return false;
    }
    var i = 0;
    for (; i + 3 < e1.lengthInBytes; i += 4) {
      if (e1.getUint32(i) != e2.getUint32(i)) {
        return false;
      }
    }
    for (; i < e1.lengthInBytes; i++) {
      if (e1.getUint8(i) != e2.getUint8(i)) {
        return false;
      }
    }
    return true;
  }

  @override
  int hash(ByteData e) {
    var h = e.lengthInBytes;
    var n = e.lengthInBytes;
    if (n > 256) {
      n = 256;
    }
    var i = 0;
    for (; i + 3 < n; i += 4) {
      h = 0xFFFFFFFF & (h + e.getUint32(i));
    }
    for (; i < n; i++) {
      h = 0xFFFFFFFF & (h + e.getUint8(i));
    }
    return h;
  }

  @override
  bool isValidKey(Object? o) {
    return o is ByteData;
  }
}
