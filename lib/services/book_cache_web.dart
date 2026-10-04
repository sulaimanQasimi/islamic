import 'dart:convert';
import 'dart:typed_data';

import 'app_storage.dart';

String _key(String id) => 'ketab_epub_$id';

Future<Uint8List?> read(String id) async {
  final value = (await AppStorage.getInstance()).getString(_key(id));
  if (value == null) return null;
  try {
    return Uint8List.fromList(base64Decode(value));
  } catch (_) {
    return null;
  }
}

Future<void> write(String id, Uint8List bytes) async {
  try {
    await (await AppStorage.getInstance()).setString(
      _key(id),
      base64Encode(bytes),
    );
  } catch (_) {
    // localStorage quota exceeded or unavailable: skip caching; the book
    // still opens from the backend bytes.
  }
}

Future<bool> contains(String id) async =>
    (await AppStorage.getInstance()).containsKey(_key(id));
