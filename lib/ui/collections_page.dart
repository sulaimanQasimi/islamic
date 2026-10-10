import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/collections_store.dart';
import '../theme/marefat_theme.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({
    super.key,
    required this.books,
    required this.onOpenBook,
  });

  final List<Book> books;
  final ValueChanged<Book> onOpenBook;

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  List<BookCollection> _collections = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await CollectionsStore.load();
    if (!mounted) return;
    setState(() {
      _collections = items;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final ctrl = TextEditingController();
    var color = 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, refresh) => AlertDialog(
            title: const Text('قفسهٔ جدید'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'نام قفسه',
                    hintText: 'مثلاً اخلاق، دعا، تفسیر',
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (var i = 0; i < BookCollection.palette.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: GestureDetector(
                          onTap: () => refresh(() => color = i),
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: BookCollection.palette[i],
                            child: color == i
                                ? const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('لغو'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ساخت'),
              ),
            ],
          ),
        ),
      ),
    );
    final name = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true) return;
    await CollectionsStore.create(name, colorIndex: color);
    await _load();
  }

  Future<void> _openCollection(BookCollection collection) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _CollectionDetailPage(
          collection: collection,
          books: widget.books,
          onOpenBook: widget.onOpenBook,
          onChanged: _load,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('قفسه‌ها')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _create,
          icon: const Icon(Icons.create_new_folder_rounded),
          label: const Text('قفسهٔ جدید'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _collections.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'قفسه‌ای نیست.\nکتاب‌ها را در قفسه‌های موضوعی سازماندهی کنید.',
                        textAlign: TextAlign.center,
                        style: TextStyle(height: 1.7, color: MarefatColors.muted),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: _collections.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final c = _collections[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        tileColor: c.color.withValues(alpha: 0.12),
                        leading: CircleAvatar(
                          backgroundColor: c.color,
                          child: Text(
                            '${c.bookIds.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text('${c.bookIds.length} کتاب'),
                        trailing: const Icon(Icons.chevron_left_rounded),
                        onTap: () => _openCollection(c),
                        onLongPress: () async {
                          final del = await showDialog<bool>(
                            context: context,
                            builder: (context) => Directionality(
                              textDirection: TextDirection.rtl,
                              child: AlertDialog(
                                title: Text('حذف «${c.name}»؟'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('لغو'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('حذف'),
                                  ),
                                ],
                              ),
                            ),
                          );
                          if (del == true) {
                            await CollectionsStore.delete(c.id);
                            await _load();
                          }
                        },
                      );
                    },
                  ),
      ),
    );
  }
}

class _CollectionDetailPage extends StatefulWidget {
  const _CollectionDetailPage({
    required this.collection,
    required this.books,
    required this.onOpenBook,
    required this.onChanged,
  });

  final BookCollection collection;
  final List<Book> books;
  final ValueChanged<Book> onOpenBook;
  final Future<void> Function() onChanged;

  @override
  State<_CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<_CollectionDetailPage> {
  late BookCollection _collection = widget.collection;

  Future<void> _reload() async {
    final all = await CollectionsStore.load();
    final found = all.where((c) => c.id == _collection.id);
    if (found.isNotEmpty && mounted) {
      setState(() => _collection = found.first);
    }
    await widget.onChanged();
  }

  Future<void> _addBooks() async {
    final selected = {..._collection.bookIds};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, refresh) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            builder: (context, controller) => Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'افزودن کتاب به قفسه',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: widget.books.length,
                    itemBuilder: (context, index) {
                      final book = widget.books[index];
                      final on = selected.contains(book.id);
                      return CheckboxListTile(
                        value: on,
                        title: Text(book.title),
                        subtitle: Text(book.author),
                        onChanged: (v) => refresh(() {
                          if (v == true) {
                            selected.add(book.id);
                          } else {
                            selected.remove(book.id);
                          }
                        }),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('ذخیره'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    await CollectionsStore.update(
      _collection.copyWith(bookIds: selected.toList()),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final books = widget.books
        .where((b) => _collection.bookIds.contains(b.id))
        .toList();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_collection.name),
          actions: [
            IconButton(
              onPressed: _addBooks,
              icon: const Icon(Icons.library_add_rounded),
              tooltip: 'مدیریت کتاب‌ها',
            ),
          ],
        ),
        body: books.isEmpty
            ? Center(
                child: TextButton.icon(
                  onPressed: _addBooks,
                  icon: const Icon(Icons.add),
                  label: const Text('افزودن کتاب'),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: books.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final book = books[index];
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    tileColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.45),
                    title: Text(
                      book.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(book.author),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                      widget.onOpenBook(book);
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () async {
                        await CollectionsStore.toggleBook(
                          _collection.id,
                          book.id,
                        );
                        await _reload();
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
