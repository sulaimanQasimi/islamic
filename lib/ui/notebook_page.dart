import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/book.dart';
import '../services/notebook_store.dart';
import '../theme/marefat_theme.dart';

class NotebookPage extends StatefulWidget {
  const NotebookPage({
    super.key,
    required this.books,
    required this.onOpenBook,
  });

  final List<Book> books;
  final ValueChanged<Book> onOpenBook;

  @override
  State<NotebookPage> createState() => _NotebookPageState();
}

class _NotebookPageState extends State<NotebookPage> {
  List<NotebookEntry> _items = [];
  bool _loading = true;
  bool _notesOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final titles = {for (final b in widget.books) b.id: b.title};
    final items = await NotebookStore.loadAll(bookTitles: titles);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  List<NotebookEntry> get _visible {
    if (!_notesOnly) return _items;
    return _items
        .where((e) => e.note != null && e.note!.trim().isNotEmpty)
        .toList();
  }

  Book? _bookFor(String id) {
    try {
      return widget.books.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _addFree() async {
    final textCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    Book? selected = widget.books.isEmpty ? null : widget.books.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, refresh) => AlertDialog(
            title: const Text('یادداشت جدید'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Book>(
                    value: selected,
                    items: [
                      for (final b in widget.books)
                        DropdownMenuItem(value: b, child: Text(b.title)),
                    ],
                    onChanged: (v) => refresh(() => selected = v),
                    decoration: const InputDecoration(labelText: 'کتاب'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: textCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'متن / نقل',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'یادداشت',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('لغو'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ذخیره'),
              ),
            ],
          ),
        ),
      ),
    );
    final text = textCtrl.text.trim();
    final note = noteCtrl.text.trim();
    textCtrl.dispose();
    noteCtrl.dispose();
    if (ok != true || selected == null || (text.isEmpty && note.isEmpty)) {
      return;
    }
    await NotebookStore.addFreeNote(
      bookId: selected!.id,
      bookTitle: selected!.title,
      chapter: 0,
      text: text.isEmpty ? note : text,
      note: text.isEmpty ? null : note,
    );
    await _load();
  }

  Future<void> _export() async {
    final text = NotebookStore.exportText(_visible);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('دفترچه در کلیپ‌بورد کپی شد.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('دفترچهٔ یادداشت'),
          actions: [
            IconButton(
              tooltip: 'فقط یادداشت‌دار',
              onPressed: () => setState(() => _notesOnly = !_notesOnly),
              icon: Icon(
                _notesOnly
                    ? Icons.filter_alt_rounded
                    : Icons.filter_alt_outlined,
              ),
            ),
            IconButton(
              tooltip: 'خروجی',
              onPressed: visible.isEmpty ? null : _export,
              icon: const Icon(Icons.ios_share_rounded),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: widget.books.isEmpty ? null : _addFree,
          icon: const Icon(Icons.note_add_rounded),
          label: const Text('یادداشت'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : visible.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'هنوز یادداشت یا برجسته‌سازی‌ای نیست.\nدر خواننده متن را برجسته کنید یا اینجا یادداشت بسازید.',
                        textAlign: TextAlign.center,
                        style: TextStyle(height: 1.7, color: MarefatColors.muted),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      final book = _bookFor(item.bookId);
                      return Material(
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: book == null
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  widget.onOpenBook(book);
                                },
                          onLongPress: item.fromHighlight
                              ? null
                              : () async {
                                  await NotebookStore.deleteFreeNote(item.id);
                                  await _load();
                                },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      item.fromHighlight
                                          ? Icons.highlight_rounded
                                          : Icons.edit_note_rounded,
                                      size: 18,
                                      color: MarefatColors.forest,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${item.bookTitle} · فصل ${item.chapter + 1}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: MarefatColors.forest,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.text,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    height: 1.65,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (item.note != null &&
                                    item.note!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    item.note!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: MarefatColors.muted,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
