import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'app_storage.dart';

class OpdsEntry {
  const OpdsEntry({
    required this.title,
    required this.author,
    required this.summary,
    required this.downloadUrl,
  });

  final String title;
  final String author;
  final String summary;
  final String downloadUrl;
}

class OpdsClient {
  OpdsClient._();

  static Future<String?> savedFeedUrl() async {
    final prefs = await AppStorage.getInstance();
    return prefs.getString('opdsFeedUrl');
  }

  static Future<void> saveFeedUrl(String url) async {
    final prefs = await AppStorage.getInstance();
    await prefs.setString('opdsFeedUrl', url.trim());
  }

  static Future<List<OpdsEntry>> fetchFeed(String url) async {
    final uri = Uri.parse(url.trim());
    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('OPDS HTTP ${res.statusCode}');
    }
    final body = utf8.decode(res.bodyBytes);
    final doc = XmlDocument.parse(body);
    final entries = <OpdsEntry>[];

    for (final entry in doc.findAllElements('entry')) {
      final title = entry.getElement('title')?.innerText.trim() ?? '';
      final authorNames = entry
          .findElements('author')
          .map((a) => a.getElement('name')?.innerText.trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      final author = authorNames.isEmpty ? 'نامشخص' : authorNames.join('، ');
      final summary = entry.getElement('summary')?.innerText.trim() ??
          entry.getElement('content')?.innerText.trim() ??
          '';
      String? download;
      for (final link in entry.findElements('link')) {
        final href = link.getAttribute('href');
        final type = (link.getAttribute('type') ?? '').toLowerCase();
        final rel = link.getAttribute('rel') ?? '';
        if (href == null) continue;
        if (type.contains('epub') ||
            rel.contains('acquisition') ||
            href.toLowerCase().endsWith('.epub')) {
          download = uri.resolve(href).toString();
          break;
        }
      }
      if (title.isEmpty || download == null) continue;
      entries.add(
        OpdsEntry(
          title: title,
          author: author.isEmpty ? 'نامشخص' : author,
          summary: summary,
          downloadUrl: download,
        ),
      );
    }
    return entries;
  }
}
