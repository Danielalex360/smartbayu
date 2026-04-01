// Stub for dart:io on web — only provides File class
import 'dart:typed_data';

class File {
  final String path;
  File(this.path);

  Future<Uint8List> readAsBytes() async => Uint8List(0);
}
