import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/backup_service.dart';
import '../services/book_backend.dart';
import '../theme/marefat_theme.dart';
import 'dictionary_page.dart';
import 'highlights_browser_page.dart';
import 'library_search_page.dart';
import 'opds_page.dart';
import 'stats_page.dart';
import 'study_plans_page.dart';

class ToolsHubPage extends StatelessWidget {
  const ToolsHubPage({
    super.key,
    required this.books,
    required this.backend,
    required this.onOpenBook,
    required this.onOpenBookChapter,
  });

  final List<Book> books;
  final BookBackend backend;
  final ValueChanged<Book> onOpenBook;
  final void Function(Book book, int chapter) onOpenBookChapter;

  @override
  Widget build(BuildContext context) {
    Future<void> open(Widget page) async {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('ابزارهای معرفت')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _tile(
              Icons.bar_chart_rounded,
              'آمار مطالعه',
              'دقایق، streak و کتاب‌های تمام‌شده',
              () => open(const StatsPage()),
            ),
            _tile(
              Icons.manage_search_rounded,
              'جست‌وجوی سراسری',
              'جست‌وجو در متن همهٔ کتاب‌های کش‌شده',
              () => open(
                LibrarySearchPage(
                  books: books,
                  backend: backend,
                  onOpenHit: onOpenBookChapter,
                ),
              ),
            ),
            _tile(
              Icons.sell_outlined,
              'جست‌وجوی برجسته‌ها',
              'فیلتر برچسب و متن برجسته‌شده‌ها',
              () => open(
                HighlightsBrowserPage(
                  books: books,
                  onOpen: onOpenBookChapter,
                ),
              ),
            ),
            _tile(
              Icons.checklist_rtl_rounded,
              'برنامه‌های مطالعه',
              'مسیر مطالعاتی با موعد',
              () => open(
                StudyPlansPage(books: books, onOpenBook: onOpenBook),
              ),
            ),
            _tile(
              Icons.menu_book_rounded,
              'واژه‌نامهٔ شخصی',
              'واژه‌های خودتان + واژه‌نامهٔ پیش‌فرض',
              () => open(const DictionaryPage()),
            ),
            _tile(
              Icons.cloud_rounded,
              'فهرست OPDS',
              'اتصال به کاتالوگ راه دور',
              () => open(const OpdsPage()),
            ),
            _tile(
              Icons.backup_rounded,
              'پشتیبان‌گیری',
              'خروجی ZIP از پیشرفت، برجسته‌ها و تنظیمات',
              () async {
                await BackupService.exportAndShare(
                  bookIds: books.map((b) => b.id).toList(),
                );
              },
            ),
            _tile(
              Icons.restore_rounded,
              'بازیابی از JSON',
              'چسباندن محتوای marefat_backup.json',
              () => _restoreJson(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restoreJson(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('بازیابی'),
          content: TextField(
            controller: ctrl,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: '{ "version": 1, "values": ... }',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لغو'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('بازیابی'),
            ),
          ],
        ),
      ),
    );
    final raw = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || raw.isEmpty) return;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final n = await BackupService.restoreFromJsonMap(data);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$n مورد بازیابی شد. برنامه را از نو اجرا کنید.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('بازیابی ناموفق: $e')),
        );
      }
    }
  }

  Widget _tile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: MarefatColors.forest),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: onTap,
      ),
    );
  }
}
