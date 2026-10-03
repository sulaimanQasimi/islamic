import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

import '../services/app_storage.dart';

import '../main.dart';
import '../models/book.dart';
import '../services/book_backend.dart';
import 'reader_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, this.backend});
  final BookBackend? backend;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late final BookBackend _backend;
  final _search = TextEditingController();
  List<Book> _books = [];
  Set<String> _favorites = {};
  List<String> _recentIds = [];
  Map<String, int> _progress = {};
  Map<String, int> _chapterCounts = {};
  String _category = 'همه';
  int _tab = 0;
  bool _loading = true;
  bool _catalogOffline = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _backend = widget.backend ?? BookBackend();
    _loadCatalog();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final books = await _backend.fetchBooks();
      final prefs = await AppStorage.getInstance();
      await prefs.setString(
        'catalogCache',
        jsonEncode({'books': books.map((book) => book.toJson()).toList()}),
      );
      if (!mounted) return;
      setState(() {
        _catalogOffline = false;
        _books = books;
        _favorites = (prefs.getStringList('favoriteBooks') ?? []).toSet();
        _recentIds = prefs.getStringList('recentBooks') ?? [];
        _progress = {
          for (final book in books)
            book.id: prefs.getInt('progress_${book.id}') ?? 0,
        };
        _chapterCounts = {
          for (final book in books)
            book.id: prefs.getInt('chapterCount_${book.id}') ?? 1,
        };
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final prefs = await AppStorage.getInstance();
      final cachedCatalog = prefs.getString('catalogCache');
      if (cachedCatalog != null) {
        try {
          final data = jsonDecode(cachedCatalog) as Map<String, dynamic>;
          final books = (data['books'] as List<dynamic>)
              .map((item) => Book.fromJson(item as Map<String, dynamic>))
              .toList();
          setState(() {
            _books = books;
            _favorites = (prefs.getStringList('favoriteBooks') ?? []).toSet();
            _recentIds = prefs.getStringList('recentBooks') ?? [];
            _progress = {
              for (final book in books)
                book.id: prefs.getInt('progress_${book.id}') ?? 0,
            };
            _chapterCounts = {
              for (final book in books)
                book.id: prefs.getInt('chapterCount_${book.id}') ?? 1,
            };
            _catalogOffline = true;
            _loading = false;
            _error = null;
          });
          return;
        } catch (_) {
          // Show the connection error when the saved catalogue is malformed.
        }
      }
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<Book> get _visibleBooks {
    var books = _books;
    if (_tab == 2) {
      books = books.where((b) => _favorites.contains(b.id)).toList();
    }
    final term = _search.text.trim().toLowerCase();
    if (term.isNotEmpty) {
      books = books
          .where(
            (b) => '${b.title} ${b.author} ${b.category}'
                .toLowerCase()
                .contains(term),
          )
          .toList();
    }
    if (_category != 'همه') {
      books = books.where((b) => b.category == _category).toList();
    }
    return books;
  }

  Future<void> _toggleFavorite(Book book) async {
    setState(
      () => _favorites.contains(book.id)
          ? _favorites.remove(book.id)
          : _favorites.add(book.id),
    );
    await (await AppStorage.getInstance()).setStringList(
      'favoriteBooks',
      _favorites.toList(),
    );
  }

  Future<void> _open(Book book) async {
    final prefs = await AppStorage.getInstance();
    final recent = prefs.getStringList('recentBooks') ?? [];
    recent.remove(book.id);
    recent.insert(0, book.id);
    await prefs.setStringList('recentBooks', recent.take(8).toList());
    if (!mounted) return;
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderPage(book: book, backend: _backend),
      ),
    );
    if (result != null && mounted) {
      final prefs = await AppStorage.getInstance();
      setState(() {
        _progress[book.id] = result;
        _chapterCounts[book.id] = prefs.getInt('chapterCount_${book.id}') ?? 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['همه', ..._books.map((b) => b.category).toSet()];
    final featured = _books.where((b) => b.featured).firstOrNull;
    final recent = _recentIds
        .map((id) => _books.where((b) => b.id == id).firstOrNull)
        .whereType<Book>()
        .firstOrNull;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: green))
              : _error != null
              ? _errorView()
              : RefreshIndicator(
                  onRefresh: _loadCatalog,
                  color: green,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _header()),
                      if (_catalogOffline)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                            child: Text(
                              'فهرست ذخیره‌شده نمایش داده می‌شود.',
                              style: TextStyle(fontSize: 11, color: green),
                            ),
                          ),
                        ),
                      if (_tab == 1) SliverToBoxAdapter(child: _searchField()),
                      if (_tab == 0 && _search.text.isEmpty) ...[
                        if (recent != null)
                          SliverToBoxAdapter(child: _continueCard(recent)),
                        if (featured != null)
                          SliverToBoxAdapter(child: _featuredCard(featured)),
                        SliverToBoxAdapter(
                          child: _sectionHeader(
                            'کتاب‌خانهٔ شما',
                            '${_books.length} کتاب',
                          ),
                        ),
                      ] else
                        SliverToBoxAdapter(
                          child: _sectionHeader(
                            _tab == 2 ? 'علاقه‌مندی‌ها' : 'جست‌وجوی کتاب',
                            '${_visibleBooks.length} کتاب',
                          ),
                        ),
                      SliverToBoxAdapter(child: _categoryBar(categories)),
                      if (_visibleBooks.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              'کتابی پیدا نشد.',
                              style: TextStyle(
                                color: ink.withValues(alpha: .55),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                          sliver: SliverGrid.builder(
                            itemCount: _visibleBooks.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: 224,
                                ),
                            itemBuilder: (context, index) =>
                                _bookCard(_visibleBooks[index]),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFE4ECE7),
          selectedIndex: _tab,
          onDestinationSelected: (value) => setState(() {
            _tab = value;
            if (value != 1) _search.clear();
          }),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              label: 'کتاب‌خانه',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_rounded),
              label: 'جست‌وجو',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border_rounded),
              label: 'علاقه‌مندی‌ها',
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.menu_book_rounded, color: Color(0xFFE8C89D)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'کتاب‌خانه',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              Text(
                'آرام بخوان، عمیق بیندیش',
                style: TextStyle(fontSize: 12, color: Color(0xFF77827A)),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _loadCatalog,
          icon: const Icon(Icons.sync_rounded, color: ink),
          tooltip: 'همگام‌سازی کتاب‌ها',
          style: IconButton.styleFrom(backgroundColor: Colors.white),
        ),
      ],
    ),
  );

  Widget _searchField() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
    child: TextField(
      controller: _search,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'عنوان، نویسنده یا موضوع کتاب…',
        prefixIcon: const Icon(Icons.search_rounded, color: green),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _search.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
      ),
    ),
  );

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: green, size: 46),
          const SizedBox(height: 14),
          const Text(
            'کتاب‌ها بارگذاری نشدند',
            style: TextStyle(
              color: ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'فایل‌های EPUB را در پوشهٔ assets/books قرار دهید و دوباره تلاش کنید.',
            style: TextStyle(color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: Colors.black45, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _loadCatalog,
            icon: const Icon(Icons.refresh),
            label: const Text('تلاش دوباره'),
            style: FilledButton.styleFrom(backgroundColor: green),
          ),
        ],
      ),
    ),
  );

  Widget _continueCard(Book book) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
    child: InkWell(
      onTap: () => _open(book),
      borderRadius: BorderRadius.circular(21),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFECE8DD),
          borderRadius: BorderRadius.circular(21),
        ),
        child: Row(
          children: [
            BookCover(book: book, width: 48, height: 62),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ادامهٔ مطالعه',
                    style: TextStyle(
                      fontSize: 11,
                      color: green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value:
                          (((_progress[book.id] ?? 0) + 1) /
                                  (_chapterCounts[book.id] ?? 1))
                              .clamp(0, 1),
                      minHeight: 4,
                      backgroundColor: Colors.white,
                      color: green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              IconData(
                0xf00a1,
                fontFamily: 'MaterialIcons',
                matchTextDirection: true,
              ),
              color: green,
              size: 30,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _featuredCard(Book book) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 2, 20, 18),
    child: Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: ink,
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF20483F), Color(0xFF183B35)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: const Color(0xFFE4C493),
                      size: 17,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'پیشنهاد کتاب‌خانه',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .72),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD2DDD5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => _open(book),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE5C495),
                    foregroundColor: ink,
                  ),
                  icon: const Icon(Icons.menu_book_rounded, size: 17),
                  label: const Text('شروع مطالعه'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          BookCover(book: book, width: 92, height: 128),
        ],
      ),
    ),
  );

  Widget _sectionHeader(String title, String detail) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 10, 22, 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
        ),
        Text(
          detail,
          style: const TextStyle(
            fontSize: 11,
            color: green,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _categoryBar(List<String> categories) => SizedBox(
    height: 51,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      scrollDirection: Axis.horizontal,
      itemCount: categories.length,
      separatorBuilder: (_, _) => const SizedBox(width: 7),
      itemBuilder: (_, index) {
        final value = categories[index];
        return ChoiceChip(
          label: Text(value),
          selected: value == _category,
          onSelected: (_) => setState(() => _category = value),
          selectedColor: const Color(0xFFDDE9E1),
          labelStyle: TextStyle(
            fontSize: 12,
            color: value == _category ? ink : Colors.black54,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(
            color: value == _category
                ? green.withValues(alpha: .25)
                : Colors.black12,
          ),
        );
      },
    ),
  );

  Widget _bookCard(Book book) => InkWell(
    onTap: () => _open(book),
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECE8DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCover(book: book, width: 57, height: 76),
              const Spacer(),
              IconButton(
                onPressed: () => _toggleFavorite(book),
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  _favorites.contains(book.id)
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _favorites.contains(book.id)
                      ? const Color(0xFFC66C5B)
                      : Colors.black38,
                  size: 20,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
          const SizedBox(height: 3),
          Text(
            book.language,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: Color(0xFF9A7651)),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(
                  book.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color: green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                book.direction == 'ltr'
                    ? Icons.format_textdirection_l_to_r
                    : Icons.format_textdirection_r_to_l,
                color: green,
                size: 15,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.book,
    required this.width,
    required this.height,
  });
  final Book book;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [book.color, book.color.withValues(alpha: .76)],
        ),
        boxShadow: [
          BoxShadow(
            color: book.color.withValues(alpha: .22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.directional(
            textDirection: TextDirection.rtl,
            start: 7,
            top: 7,
            bottom: 7,
            child: Container(
              width: 1,
              color: Colors.white.withValues(alpha: .35),
            ),
          ),
          Center(
            child: Icon(
              book.icon,
              color: Colors.white.withValues(alpha: .9),
              size: width * .42,
            ),
          ),
        ],
      ),
    ),
  );
}
