import 'dart:typed_data';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> _path(String id) async {
  if (!RegExp(r'^[a-z0-9-]+$').hasMatch(id)) {
    throw ArgumentError.value(id, 'id', 'Invalid book id');
  }
  final dir = await getApplicationSupportDirectory();
  final books = Directory('${dir.path}${Platform.pathSeparator}books')
    ..createSync(recursive: true);
  return '${books.path}${Platform.pathSeparator}$id.epub';
}

Future<Uint8List?> read(String id) async {
  final file = File(await _path(id));
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

Future<void> write(String id, Uint8List bytes) async =>
    File(await _path(id)).writeAsBytes(bytes, flush: true);

Future<bool> contains(String id) async => File(await _path(id)).exists();
