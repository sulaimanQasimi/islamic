import 'dart:typed_data';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<Directory> _booksDir() async {
  final dir = await getApplicationSupportDirectory();
  return Directory('${dir.path}${Platform.pathSeparator}books')
    ..createSync(recursive: true);
}

Future<String> _path(String id) async {
  if (!RegExp(r'^[a-z0-9-]+$').hasMatch(id)) {
    throw ArgumentError.value(id, 'id', 'Invalid book id');
  }
  final books = await _booksDir();
  return '${books.path}${Platform.pathSeparator}$id.epub';
}

Future<String> _coverPath(String id) async {
  if (!RegExp(r'^[a-z0-9-]+$').hasMatch(id)) {
    throw ArgumentError.value(id, 'id', 'Invalid book id');
  }
  final books = await _booksDir();
  return '${books.path}${Platform.pathSeparator}$id.cover';
}

Future<Uint8List?> read(String id) async {
  final file = File(await _path(id));
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

Future<void> write(String id, Uint8List bytes) async {
  final target = File(await _path(id));
  final tmp = File('${target.path}.tmp');
  await tmp.writeAsBytes(bytes, flush: true);
  await tmp.rename(target.path);
}

Future<bool> contains(String id) async => File(await _path(id)).exists();

Future<Uint8List?> readCover(String id) async {
  final file = File(await _coverPath(id));
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

Future<void> writeCover(String id, Uint8List bytes) async {
  final target = File(await _coverPath(id));
  final tmp = File('${target.path}.tmp');
  await tmp.writeAsBytes(bytes, flush: true);
  await tmp.rename(target.path);
}
