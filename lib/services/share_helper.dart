import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Copy / share helpers for text and files (PDF).
/// Uses the classic [Share] API for broad share_plus compatibility.
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

    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          mimeType: mime,
          name: safeName,
        ),
      ],
      text: text,
      subject: subject,
      fileNameOverrides: [safeName],
    );
  }

  static String _mimeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.txt')) return 'text/plain';
    return 'application/octet-stream';
  }
}
