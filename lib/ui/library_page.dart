import 'dart:convert';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/book.dart';
import '../services/app_storage.dart';
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
        } catch (e) {
          debugPrint('Could not restore cached catalog: $e');
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

  Future<void> _open(Book book) async {
    if (!mounted) return;
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderPage(book: book, backend: _backend),
      ),
    );
    if (result != null && mounted) {
      final updatedPrefs = await AppStorage.getInstance();
      setState(() {
        _progress[book.id] = result;
        _chapterCounts[book.id] =
            updatedPrefs.getInt('chapterCount_${book.id}') ?? 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['همه', ..._books.map((b) => b.category).toSet()];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F5F0),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: green))
              : _error != null
              ? _errorView()
              : RefreshIndicator(
                  onRefresh: _loadCatalog,
                  color: green,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(child: _header()),
                      if (_catalogOffline)
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: green.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.cloud_off_rounded,
                                  size: 16,
                                  color: green,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'حالت آفلاین: فهرست ذخیره‌شده نمایش داده می‌شود.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_tab == 1) SliverToBoxAdapter(child: _searchField()),
                      SliverToBoxAdapter(
                        child: _sectionHeader(
                          _tab == 2
                              ? 'علاقه‌مندی‌ها'
                              : (_tab == 1 ? 'جست‌وجو' : 'کتاب‌خانه'),
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
                                color: ink.withValues(alpha: 0.55),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 220,
                                  mainAxisSpacing: 18,
                                  crossAxisSpacing: 18,
                                  childAspectRatio: 0.68,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final book = _visibleBooks[index];
                              return BookCoverCard(
                                book: book,
                                onTap: () => _open(book),
                              );
                            }, childCount: _visibleBooks.length),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: Colors.white,
          indicatorColor: green.withValues(alpha: 0.12),
          selectedIndex: _tab,
          onDestinationSelected: (value) => setState(() {
            _tab = value;
            if (value != 1) _search.clear();
          }),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              selectedIcon: Icon(Icons.grid_view_rounded, color: green),
              label: 'کتاب‌خانه',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_rounded),
              selectedIcon: Icon(Icons.search_rounded, color: green),
              label: 'جست‌وجو',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_outline_rounded),
              selectedIcon: Icon(Icons.favorite_rounded, color: green),
              label: 'علاقه‌مندی‌ها',
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.menu_book_rounded,
            color: Color(0xFFF1D4A8),
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'کتاب‌خانهٔ من',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: ink,
                ),
              ),
              Text(
                'آرام بخوان، عمیق بیندیش',
                style: TextStyle(fontSize: 11, color: Color(0xFF7E8981)),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _loadCatalog,
          icon: const Icon(Icons.sync_rounded, color: ink),
          tooltip: 'همگام‌سازی',
        ),
      ],
    ),
  );

  Widget _searchField() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E4DA)),
      ),
      child: TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'عنوان، نویسنده یا موضوع...',
          prefixIcon: const Icon(Icons.search_rounded, color: green),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _search.clear();
                    setState(() {});
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    ),
  );

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: green, size: 44),
          const SizedBox(height: 12),
          const Text(
            'خطا در بارگذاری فهرست',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ink,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loadCatalog,
            style: FilledButton.styleFrom(backgroundColor: green),
            child: const Text('تلاش دوباره'),
          ),
        ],
      ),
    ),
  );

  Widget _sectionHeader(String title, String detail) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: ink,
          ),
        ),
        Text(
          detail,
          style: const TextStyle(
            fontSize: 12,
            color: green,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _categoryBar(List<String> categories) => SizedBox(
    height: 44,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      scrollDirection: Axis.horizontal,
      itemCount: categories.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, index) {
        final value = categories[index];
        final isSelected = value == _category;
        return ChoiceChip(
          label: Text(value),
          selected: isSelected,
          onSelected: (_) => setState(() => _category = value),
          selectedColor: green,
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : ink.withValues(alpha: 0.7),
          ),
          backgroundColor: Colors.white,
          side: BorderSide(color: isSelected ? green : const Color(0xFFE2DDD2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    ),
  );
}

class BookCoverCard extends StatelessWidget {
  const BookCoverCard({super.key, required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const goldColor = Color(0xFFF3DE97);
    const darkGold = Color(0xFFC7A855);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [book.color, Color.lerp(book.color, Colors.black, 0.42)!],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Outer gold geometric border
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: goldColor.withValues(alpha: 0.7),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              // Inner second line border
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: darkGold.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                ),
              ),
              // Spine edge texture (book fold shadow)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 14,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Islamic arch top curve decoration
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                height: 52,
                child: CustomPaint(
                  painter: ArchOrnamentPainter(
                    color: goldColor.withValues(alpha: 0.65),
                  ),
                ),
              ),
              // Book Title & Author inside cover
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 22,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 3),
                      Text(
                        book.title,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFFFF7DC),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1.35,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Center divider ornament
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: goldColor.withValues(alpha: 0.4),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              Icons.spa_rounded,
                              size: 12,
                              color: goldColor.withValues(alpha: 0.7),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: goldColor.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        book.author,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: goldColor.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          shadows: const [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArchOrnamentPainter extends CustomPainter {
  const ArchOrnamentPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, size.height * 0.45);
    // Pointed Islamic arch profile
    path.cubicTo(
      size.width * 0.15,
      size.height * 0.4,
      size.width * 0.35,
      size.height * 0.05,
      size.width * 0.5,
      0,
    );
    path.cubicTo(
      size.width * 0.65,
      size.height * 0.05,
      size.width * 0.85,
      size.height * 0.4,
      size.width,
      size.height * 0.45,
    );
    path.lineTo(size.width, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
