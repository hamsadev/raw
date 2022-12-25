import 'package:raw/raw.dart';
import 'dart:io';

void main() async {
  final data = await stdin.toList();
  final hex = const DebugHexEncoder().convert(data);
  print(hex);
}
