/// Replaces specific bits in a 32-bit unsigned integer.
///
/// Bits are specified by:
///   * `shift` - Bitmask left-shift (0,1, ..., 30, 31)
///   * `bitmask` - For example, 0xF for 4 bits.
int transformUint32Bits(int uint32, int shift, int bitmask, int newValue) {
  if (bitmask | newValue != bitmask) {
    throw new ArgumentError.value(newValue, "newValue", "too many bits");
  }
  return ((0xFFFFFFFF ^ (bitmask << shift)) & uint32) | (newValue << shift);
}

/// Replaces a single bit in a 32-bit unsigned integer.
int transformUint32Bool(int uint32, int shift, bool newValue) {
  return ((0xFFFFFFFF ^ (0x1 << shift)) & uint32) |
      ((newValue ? 1 : 0) << shift);
}

/// Returns specific bits in a 32-bit unsigned integer.
///
/// Bits are specified by:
///   * `shift` - Bitmask left-shift (0,1, ..., 30, 31)
///   * `bitmask` - For example, 0xF for 4 bits.
///
/// Example:
///   viewUint32(0xF0A0, 8, 0xF) // --> 0xA
int extractUint32Bits(int uint32, int shift, int mask) {
  return mask & (uint32 >> shift);
}

/// Return a single bit in a 32-bit unsigned integer.
///
/// Example:
///   viewUint32Bool(0xF010, 8) // --> true
bool extractUint32Bool(int uint32, int shift) {
  return 0x1 & (uint32 >> shift) != 0;
}
