import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

Future<Uint8List?> localFileBytes(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

ImageProvider? localFileImage(String path) => FileImage(File(path));
