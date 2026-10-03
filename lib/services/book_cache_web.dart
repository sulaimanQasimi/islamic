import 'dart:convert';
import 'dart:typed_data';

import 'app_storage.dart';

String _key(String id) => 'ketab_epub_$id';

Future<Uint8List?> read(String id) async {
  final value = (await AppStorage.getInstance()).getString(_key(id));
  return value == null ? null : Uint8List.fromList(base64Decode(value));
}

Future<void> write(String id, Uint8List bytes) async {
  await (await AppStorage.getInstance()).setString(
    _key(id),
    base64Encode(bytes),
  );
}

Future<bool> contains(String id) async =>
    (await AppStorage.getInstance()).containsKey(_key(id));
