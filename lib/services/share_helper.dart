import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Copy / share helpers for text and files (PDF).
///
/// Compatible with share_plus 10.x ([Share.share] / [Share.shareXFiles]).
/// Do not use SharePlus / ShareParams here — those need share_plus 11+.
class ShareHelper {
  ShareHelper._();

  static Future<void> copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  static Future<void> shareText(
    String text, {
    String? subject,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await Share.share(trimmed, subject: subject);
  }

  /// Copy then open the system share sheet.
  static Future<void> copyAndShare(
    String text, {
    String? subject,
  }) async {
    await copyText(text);
    await shareText(text, subject: subject);
  }

  static Future<void> shareBytesAsFile({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    String? text,
    String? subject,
  }) async {
    final safeName =
        fileName.replaceAll(RegExp(r'[^\w\.\-\u0600-\u06FF]+'), '_');
    final mime = mimeType ?? _mimeFor(safeName);

    if (kIsWeb) {
      await Share.shareXFiles(
        [
          XFile.fromData(bytes, mimeType: mime, name: safeName),
        ],
        text: text,
        subject: subject,
      );
      return;
    }

    // Native (Windows/Android/iOS): write a real temp file so the OS share
    // sheet receives a path + filename.
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$safeName';
    final temp = XFile.fromData(bytes, mimeType: mime, name: safeName);
    await temp.saveTo(path);

    await Share.shareXFiles(
      [XFile(path, mimeType: mime, name: safeName)],
      text: text,
      subject: subject,
    );
  }

  static String _mimeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.txt')) return 'text/plain';
    return 'application/octet-stream';
  }
}
