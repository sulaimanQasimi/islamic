import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/book.dart';
import '../services/app_storage.dart';
import '../services/book_backend.dart';
import '../services/book_cache.dart';
import '../services/epub_parser.dart';
import '../theme/marefat_theme.dart';
import '../widgets/book_cover_card.dart';
import '../widgets/book_detail_sheet.dart';
import '../widgets/marefat_backdrop.dart';
import '../widgets/shimmer_library.dart';
import 'reader_page.dart';

enum LibrarySort { title, author, progress, featured }

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.backend});
  final BookBackend? backend;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final BookBackend _backend;
  final _search = TextEditingController();
  List<Book> _books = [];
  Set<String> _favorites = {};
  Map<String, int> _progress = {};
  Map<String, int> _chapterCounts = {};
  final Map<String, Uint8List> _covers = {};
  String _category = 'همه';
  LibrarySort _sort = LibrarySort.featured;
  int _tab = 0;
  bool _loading = true;
  bool _catalogOffline = false;
  bool _gridView = true;
  String? _error;
  ThemeMode _themeMode = ThemeMode.system;

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
        _applyPrefs(prefs, books);
        _loading = false;
      });
      _loadCovers(books);
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
            _applyPrefs(prefs, books);
            _catalogOffline = true;
            _loading = false;
            _error = null;
          });
          _loadCovers(books);
          return;
        } catch (restoreError) {
          debugPrint('Could not restore cached catalog: $restoreError');
        }
      }
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// Pull cover / first-page images from each EPUB (cached after first extract).
  Future<void> _loadCovers(List<Book> books) async {
    for (final book in books) {
      if (!mounted) return;
      if (_covers.containsKey(book.id)) continue;

      try {
        var cover = await BookCache.readCover(book.id);
        if (cover == null || cover.isEmpty) {
          final cachedEpub = await BookCache.read(book.id);
          final epubBytes = cachedEpub ?? await _backend.downloadBytes(book);
          if (cachedEpub == null) {
            await BookCache.write(book.id, epubBytes);
          }
          cover = EpubParser.extractCover(epubBytes);
          if (cover != null && cover.isNotEmpty) {
            await BookCache.writeCover(book.id, cover);
          }
        }
        final bytes = cover;
        if (bytes != null && bytes.isNotEmpty && mounted) {
          setState(() => _covers[book.id] = bytes);
        }
      } catch (error) {
        debugPrint('Cover extract failed for ${book.id}: $error');
      }
    }
  }

  void _applyPrefs(AppStorage prefs, List<Book> books) {
    _favorites = (prefs.getStringList('favoriteBooks') ?? []).toSet();
    _progress = {
      for (final book in books)
        book.id: prefs.getInt('progress_${book.id}') ?? 0,
    };
    _chapterCounts = {
      for (final book in books)
        book.id: prefs.getInt('chapterCount_${book.id}') ?? 1,
    };
    final theme = prefs.getString('appThemeMode');
    _themeMode = switch (theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _gridView = prefs.getBool('libraryGridView') ?? true;
  }

  List<Book> get _filtered {
    var books = List<Book>.from(_books);
    if (_tab == 2) {
      books = books.where((b) => _favorites.contains(b.id)).toList();
    }
    final term = _search.text.trim().toLowerCase();
    if (term.isNotEmpty) {
      books = books
          .where(
            (b) => '${b.title} ${b.author} ${b.category} ${b.description}'
                .toLowerCase()
                .contains(term),
          )
          .toList();
    }
    if (_category != 'همه' && _tab == 0) {
      books = books.where((b) => b.category == _category).toList();
    }
    switch (_sort) {
      case LibrarySort.title:
        books.sort((a, b) => a.title.compareTo(b.title));
      case LibrarySort.author:
        books.sort((a, b) => a.author.compareTo(b.author));
      case LibrarySort.progress:
        books.sort(
          (a, b) => (_progress[b.id] ?? 0).compareTo(_progress[a.id] ?? 0),
        );
      case LibrarySort.featured:
        books.sort((a, b) {
          if (a.featured != b.featured) return a.featured ? -1 : 1;
          return a.title.compareTo(b.title);
        });
    }
    return books;
  }

  List<Book> get _continueReading {
    final items = _books
        .where((b) => (_progress[b.id] ?? 0) > 0)
        .toList()
      ..sort((a, b) => (_progress[b.id] ?? 0).compareTo(_progress[a.id] ?? 0));
    return items.take(8).toList();
  }

  List<Book> get _featured =>
      _books.where((b) => b.featured).take(6).toList();

  int get _startedCount =>
      _books.where((b) => (_progress[b.id] ?? 0) > 0).length;

  Future<void> _toggleFavorite(String id) async {
    final prefs = await AppStorage.getInstance();
    setState(() {
      if (_favorites.contains(id)) {
        _favorites.remove(id);
      } else {
        _favorites.add(id);
      }
    });
    await prefs.setStringList('favoriteBooks', _favorites.toList());
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final prefs = await AppStorage.getInstance();
    setState(() => _themeMode = mode);
    await prefs.setString(
      'appThemeMode',
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
    if (!mounted) return;
    MarefatAppScope.of(context)?.onThemeModeChanged(mode);
  }

  Future<void> _setGridView(bool value) async {
    final prefs = await AppStorage.getInstance();
    setState(() => _gridView = value);
    await prefs.setBool('libraryGridView', value);
  }

  Future<void> _open(Book book) async {
    if (!mounted) return;
    final result = await Navigator.push<int>(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: ReaderPage(book: book, backend: _backend),
        ),
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

  Future<void> _showDetail(Book book) async {
    await showBookDetailSheet(
      context: context,
      book: book,
      coverBytes: _covers[book.id],
      progress: _progress[book.id] ?? 0,
      chapterCount: _chapterCounts[book.id] ?? 1,
      isFavorite: _favorites.contains(book.id),
      onToggleFavorite: () => _toggleFavorite(book.id),
      onOpen: () => _open(book),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: MarefatBackdrop(
        dark: dark,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: _loading
                ? const ShimmerLibrary()
                : _error != null
                    ? _errorView()
                    : IndexedStack(
                        index: _tab,
                        children: [
                          _LibraryTab(
                            books: _filtered,
                            allBooks: _books,
                            continueReading: _continueReading,
                            featured: _featured,
                            favorites: _favorites,
                            progress: _progress,
                            chapterCounts: _chapterCounts,
                            covers: _covers,
                            category: _category,
                            sort: _sort,
                            gridView: _gridView,
                            catalogOffline: _catalogOffline,
                            startedCount: _startedCount,
                            favoriteCount: _favorites.length,
                            onRefresh: _loadCatalog,
                            onCategory: (v) => setState(() => _category = v),
                            onSort: (v) => setState(() => _sort = v),
                            onGridView: _setGridView,
                            onOpen: _open,
                            onDetail: _showDetail,
                            onFavorite: _toggleFavorite,
                          ),
                          _SearchTab(
                            controller: _search,
                            books: _filtered,
                            favorites: _favorites,
                            progress: _progress,
                            chapterCounts: _chapterCounts,
                            covers: _covers,
                            onChanged: () => setState(() {}),
                            onOpen: _showDetail,
                            onFavorite: _toggleFavorite,
                          ),
                          _FavoritesTab(
                            books: _filtered,
                            favorites: _favorites,
                            progress: _progress,
                            chapterCounts: _chapterCounts,
                            covers: _covers,
                            gridView: _gridView,
                            onOpen: _showDetail,
                            onFavorite: _toggleFavorite,
                            onBrowse: () => setState(() => _tab = 0),
                          ),
                          _SettingsTab(
                            themeMode: _themeMode,
                            bookCount: _books.length,
                            startedCount: _startedCount,
                            favoriteCount: _favorites.length,
                            onThemeMode: _setThemeMode,
                            onRefresh: _loadCatalog,
                          ),
                        ],
                      ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (value) => setState(() {
              _tab = value;
              if (value != 1) _search.clear();
            }),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.auto_stories_outlined),
                selectedIcon: Icon(Icons.auto_stories_rounded),
                label: 'کتاب‌خانه',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_rounded),
                selectedIcon: Icon(Icons.manage_search_rounded),
                label: 'جست‌وجو',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_outline_rounded),
                selectedIcon: Icon(Icons.favorite_rounded),
                label: 'علاقه‌مندی',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_rounded),
                selectedIcon: Icon(Icons.tune_rounded),
                label: 'تنظیمات',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: MarefatColors.forest.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: MarefatColors.forest,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'خطا در بارگذاری فهرست',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'اتصال را بررسی کنید یا دوباره تلاش کنید.',
            style: TextStyle(color: MarefatColors.muted),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: _loadCatalog, child: const Text('تلاش دوباره')),
        ],
      ),
    ),
  );
}

/// Inherited notifier so settings can update app-level ThemeMode.
class MarefatAppScope extends InheritedWidget {
  const MarefatAppScope({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required super.child,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  static MarefatAppScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MarefatAppScope>();

  @override
  bool updateShouldNotify(MarefatAppScope oldWidget) =>
      themeMode != oldWidget.themeMode;
}

class _LibraryTab extends StatelessWidget {
  const _LibraryTab({
    required this.books,
    required this.allBooks,
    required this.continueReading,
    required this.featured,
    required this.favorites,
    required this.progress,
    required this.chapterCounts,
    required this.covers,
    required this.category,
    required this.sort,
    required this.gridView,
    required this.catalogOffline,
    required this.startedCount,
    required this.favoriteCount,
    required this.onRefresh,
    required this.onCategory,
    required this.onSort,
    required this.onGridView,
    required this.onOpen,
    required this.onDetail,
    required this.onFavorite,
  });

  final List<Book> books;
  final List<Book> allBooks;
  final List<Book> continueReading;
  final List<Book> featured;
  final Set<String> favorites;
  final Map<String, int> progress;
  final Map<String, int> chapterCounts;
  final Map<String, Uint8List> covers;
  final String category;
  final LibrarySort sort;
  final bool gridView;
  final bool catalogOffline;
  final int startedCount;
  final int favoriteCount;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onCategory;
  final ValueChanged<LibrarySort> onSort;
  final ValueChanged<bool> onGridView;
  final ValueChanged<Book> onOpen;
  final ValueChanged<Book> onDetail;
  final ValueChanged<String> onFavorite;

  @override
  Widget build(BuildContext context) {
    final categories = ['همه', ...allBooks.map((b) => b.category).toSet()];

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: MarefatColors.forest,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(child: _BrandHeader(bookCount: allBooks.length)),
          if (catalogOffline)
            SliverToBoxAdapter(
              child: _OfflineBanner(),
            ),
          SliverToBoxAdapter(
            child: _StatsRow(
              bookCount: allBooks.length,
              startedCount: startedCount,
              favoriteCount: favoriteCount,
            ),
          ),
          if (continueReading.isNotEmpty)
            SliverToBoxAdapter(
              child: _ContinueSection(
                books: continueReading,
                progress: progress,
                chapterCounts: chapterCounts,
                covers: covers,
                onOpen: onOpen,
              ),
            ),
          if (featured.isNotEmpty)
            SliverToBoxAdapter(
              child: _FeaturedSection(
                books: featured,
                favorites: favorites,
                progress: progress,
                chapterCounts: chapterCounts,
                covers: covers,
                onDetail: onDetail,
                onFavorite: onFavorite,
              ),
            ),
          SliverToBoxAdapter(
            child: _SectionToolbar(
              title: 'همهٔ کتاب‌ها',
              detail: '${books.length} عنوان',
              sort: sort,
              gridView: gridView,
              onSort: onSort,
              onGridView: onGridView,
            ),
          ),
          SliverToBoxAdapter(
            child: _CategoryBar(
              categories: categories,
              selected: category,
              onSelected: onCategory,
            ),
          ),
          if (books.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('کتابی پیدا نشد.')),
            )
          else if (gridView)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.68,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final book = books[index];
                  return BookCoverCard(
                    book: book,
                    index: index,
                    coverBytes: covers[book.id],
                    progress: progress[book.id] ?? 0,
                    chapterCount: chapterCounts[book.id] ?? 1,
                    isFavorite: favorites.contains(book.id),
                    onFavoriteToggle: () => onFavorite(book.id),
                    onTap: () => onDetail(book),
                  );
                }, childCount: books.length),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
              sliver: SliverList.separated(
                itemCount: books.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final book = books[index];
                  return _BookListTile(
                    book: book,
                    coverBytes: covers[book.id],
                    progress: progress[book.id] ?? 0,
                    chapterCount: chapterCounts[book.id] ?? 1,
                    isFavorite: favorites.contains(book.id),
                    onTap: () => onDetail(book),
                    onFavorite: () => onFavorite(book.id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.bookCount});
  final int bookCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MarefatColors.ink, MarefatColors.forest],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: MarefatColors.forest.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.brightness_5_rounded,
              color: MarefatColors.brassSoft,
              size: 26,
            ),
          ).animate().scale(
            begin: const Offset(0.85, 0.85),
            duration: 500.ms,
            curve: Curves.easeOutBack,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'معرفت',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                    height: 1.1,
                    color: theme.colorScheme.onSurface,
                  ),
                ).animate().fadeIn(duration: 400.ms).slideX(
                      begin: 0.08,
                      curve: Curves.easeOutCubic,
                    ),
                const SizedBox(height: 2),
                Text(
                  'گنجینهٔ دانش · $bookCount کتاب',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: MarefatColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: MarefatColors.forest.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: MarefatColors.forest.withValues(alpha: 0.2)),
    ),
    child: const Row(
      children: [
        Icon(Icons.cloud_off_rounded, size: 16, color: MarefatColors.forest),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'حالت آفلاین: فهرست ذخیره‌شده نمایش داده می‌شود.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: MarefatColors.forest,
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.bookCount,
    required this.startedCount,
    required this.favoriteCount,
  });

  final int bookCount;
  final int startedCount;
  final int favoriteCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              label: 'کتاب',
              value: '$bookCount',
              icon: Icons.menu_book_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              label: 'در حال خواندن',
              value: '$startedCount',
              icon: Icons.timelapse_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              label: 'علاقه‌مندی',
              value: '$favoriteCount',
              icon: Icons.favorite_rounded,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 80.ms, duration: 400.ms);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: (dark ? MarefatColors.nightSurface : Colors.white)
            .withValues(alpha: dark ? 0.9 : 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: MarefatColors.mistDeep.withValues(alpha: dark ? 0.2 : 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: MarefatColors.brass),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: MarefatColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueSection extends StatelessWidget {
  const _ContinueSection({
    required this.books,
    required this.progress,
    required this.chapterCounts,
    required this.covers,
    required this.onOpen,
  });

  final List<Book> books;
  final Map<String, int> progress;
  final Map<String, int> chapterCounts;
  final Map<String, Uint8List> covers;
  final ValueChanged<Book> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Text(
            'ادامهٔ مطالعه',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ),
        SizedBox(
          height: 108,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final book = books[index];
              final p = progress[book.id] ?? 0;
              final total = chapterCounts[book.id] ?? 1;
              final ratio = ((p + 1) / total).clamp(0.0, 1.0);
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onOpen(book),
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    width: 260,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: [
                          book.color.withValues(alpha: 0.92),
                          Color.lerp(book.color, MarefatColors.ink, 0.45)!,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 54,
                            height: 78,
                            child: covers[book.id] != null
                                ? Image.memory(
                                    covers[book.id]!,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                  )
                                : DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      border: Border.all(
                                        color: MarefatColors.brassSoft
                                            .withValues(alpha: 0.55),
                                      ),
                                    ),
                                    child: Icon(
                                      book.icon,
                                      color: MarefatColors.brassSoft,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                book.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'فصل ${p + 1} از $total',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 4,
                                  backgroundColor: Colors.white24,
                                  color: MarefatColors.brassSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate(delay: (60 * index).ms).fadeIn().slideX(begin: 0.06);
            },
          ),
        ),
      ],
    );
  }
}

class _FeaturedSection extends StatelessWidget {
  const _FeaturedSection({
    required this.books,
    required this.favorites,
    required this.progress,
    required this.chapterCounts,
    required this.covers,
    required this.onDetail,
    required this.onFavorite,
  });

  final List<Book> books;
  final Set<String> favorites;
  final Map<String, int> progress;
  final Map<String, int> chapterCounts;
  final Map<String, Uint8List> covers;
  final ValueChanged<Book> onDetail;
  final ValueChanged<String> onFavorite;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text(
            'برگزیده‌ها',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ),
        SizedBox(
          height: 210,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final book = books[index];
              return SizedBox(
                width: 140,
                child: BookCoverCard(
                  book: book,
                  index: index,
                  coverBytes: covers[book.id],
                  progress: progress[book.id] ?? 0,
                  chapterCount: chapterCounts[book.id] ?? 1,
                  isFavorite: favorites.contains(book.id),
                  onFavoriteToggle: () => onFavorite(book.id),
                  onTap: () => onDetail(book),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SectionToolbar extends StatelessWidget {
  const _SectionToolbar({
    required this.title,
    required this.detail,
    required this.sort,
    required this.gridView,
    required this.onSort,
    required this.onGridView,
  });

  final String title;
  final String detail;
  final LibrarySort sort;
  final bool gridView;
  final ValueChanged<LibrarySort> onSort;
  final ValueChanged<bool> onGridView;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: MarefatColors.forest,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<LibrarySort>(
            tooltip: 'مرتب‌سازی',
            initialValue: sort,
            onSelected: onSort,
            itemBuilder: (context) => const [
              PopupMenuItem(value: LibrarySort.featured, child: Text('برگزیده')),
              PopupMenuItem(value: LibrarySort.title, child: Text('عنوان')),
              PopupMenuItem(value: LibrarySort.author, child: Text('نویسنده')),
              PopupMenuItem(value: LibrarySort.progress, child: Text('پیشرفت')),
            ],
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.sort_rounded, color: MarefatColors.ink),
            ),
          ),
          IconButton(
            tooltip: gridView ? 'نمای فهرستی' : 'نمای شبکه‌ای',
            onPressed: () => onGridView(!gridView),
            icon: Icon(
              gridView ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
              color: MarefatColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final value = categories[index];
          final isSelected = value == selected;
          return ChoiceChip(
            label: Text(value),
            selected: isSelected,
            onSelected: (_) => onSelected(value),
            selectedColor: MarefatColors.forest,
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? Colors.white
                  : MarefatColors.ink.withValues(alpha: 0.75),
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.8),
            side: BorderSide(
              color: isSelected ? MarefatColors.forest : MarefatColors.mistDeep,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          );
        },
      ),
    );
  }
}

class _BookListTile extends StatelessWidget {
  const _BookListTile({
    required this.book,
    required this.progress,
    required this.chapterCount,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
    this.coverBytes,
  });

  final Book book;
  final Uint8List? coverBytes;
  final int progress;
  final int chapterCount;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final total = chapterCount <= 0 ? 1 : chapterCount;
    final ratio = ((progress + 1) / total).clamp(0.0, 1.0);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (dark ? MarefatColors.nightSurface : Colors.white)
                .withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: MarefatColors.mistDeep.withValues(alpha: dark ? 0.25 : 1),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 54,
                  height: 74,
                  child: coverBytes != null
                      ? Image.memory(
                          coverBytes!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: [
                                book.color,
                                Color.lerp(book.color, Colors.black, 0.4)!,
                              ],
                            ),
                          ),
                          child: Icon(
                            book.icon,
                            color: MarefatColors.brassSoft,
                            size: 22,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${book.author} · ${book.category}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: MarefatColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress > 0 ? ratio : 0,
                        minHeight: 4,
                        backgroundColor: MarefatColors.mistDeep,
                        color: MarefatColors.forest,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onFavorite,
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFavorite
                      ? const Color(0xFFC45C4A)
                      : MarefatColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchTab extends StatelessWidget {
  const _SearchTab({
    required this.controller,
    required this.books,
    required this.favorites,
    required this.progress,
    required this.chapterCounts,
    required this.covers,
    required this.onChanged,
    required this.onOpen,
    required this.onFavorite,
  });

  final TextEditingController controller;
  final List<Book> books;
  final Set<String> favorites;
  final Map<String, int> progress;
  final Map<String, int> chapterCounts;
  final Map<String, Uint8List> covers;
  final VoidCallback onChanged;
  final ValueChanged<Book> onOpen;
  final ValueChanged<String> onFavorite;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'جست‌وجو در معرفت',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                onChanged: (_) => onChanged(),
                decoration: InputDecoration(
                  hintText: 'عنوان، نویسنده، موضوع یا توضیح…',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: MarefatColors.forest,
                  ),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            controller.clear();
                            onChanged();
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: books.isEmpty
              ? Center(
                  child: Text(
                    controller.text.isEmpty
                        ? 'عبارت جست‌وجو را وارد کنید.'
                        : 'نتیجه‌ای یافت نشد.',
                    style: const TextStyle(color: MarefatColors.muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  itemCount: books.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final book = books[index];
                    return _BookListTile(
                      book: book,
                      coverBytes: covers[book.id],
                      progress: progress[book.id] ?? 0,
                      chapterCount: chapterCounts[book.id] ?? 1,
                      isFavorite: favorites.contains(book.id),
                      onTap: () => onOpen(book),
                      onFavorite: () => onFavorite(book.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab({
    required this.books,
    required this.favorites,
    required this.progress,
    required this.chapterCounts,
    required this.covers,
    required this.gridView,
    required this.onOpen,
    required this.onFavorite,
    required this.onBrowse,
  });

  final List<Book> books;
  final Set<String> favorites;
  final Map<String, int> progress;
  final Map<String, int> chapterCounts;
  final Map<String, Uint8List> covers;
  final bool gridView;
  final ValueChanged<Book> onOpen;
  final ValueChanged<String> onFavorite;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.favorite_border_rounded,
                size: 48,
                color: MarefatColors.brass,
              ),
              const SizedBox(height: 12),
              const Text(
                'هنوز علاقه‌مندی ندارید',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'با لمس قلب روی جلد کتاب، آن را اینجا نگه دارید.',
                textAlign: TextAlign.center,
                style: TextStyle(color: MarefatColors.muted),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onBrowse,
                child: const Text('مرور کتاب‌خانه'),
              ),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              'علاقه‌مندی‌ها',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ),
        if (gridView)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 18,
                crossAxisSpacing: 16,
                childAspectRatio: 0.68,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final book = books[index];
                return BookCoverCard(
                  book: book,
                  index: index,
                  coverBytes: covers[book.id],
                  progress: progress[book.id] ?? 0,
                  chapterCount: chapterCounts[book.id] ?? 1,
                  isFavorite: favorites.contains(book.id),
                  onFavoriteToggle: () => onFavorite(book.id),
                  onTap: () => onOpen(book),
                );
              }, childCount: books.length),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            sliver: SliverList.separated(
              itemCount: books.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final book = books[index];
                return _BookListTile(
                  book: book,
                  coverBytes: covers[book.id],
                  progress: progress[book.id] ?? 0,
                  chapterCount: chapterCounts[book.id] ?? 1,
                  isFavorite: favorites.contains(book.id),
                  onTap: () => onOpen(book),
                  onFavorite: () => onFavorite(book.id),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.themeMode,
    required this.bookCount,
    required this.startedCount,
    required this.favoriteCount,
    required this.onThemeMode,
    required this.onRefresh,
  });

  final ThemeMode themeMode;
  final int bookCount;
  final int startedCount;
  final int favoriteCount;
  final ValueChanged<ThemeMode> onThemeMode;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Text(
          'تنظیمات معرفت',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'ظاهر برنامه و همگام‌سازی فهرست',
          style: theme.textTheme.bodyMedium?.copyWith(color: MarefatColors.muted),
        ),
        const SizedBox(height: 22),
        _SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'پوسته',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 12),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('روشن'),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('سیستم'),
                    icon: Icon(Icons.brightness_auto_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('تیره'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (value) => onThemeMode(value.first),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SettingsCard(
          child: Column(
            children: [
              _InfoRow(label: 'تعداد کتاب‌ها', value: '$bookCount'),
              const Divider(height: 22),
              _InfoRow(label: 'کتاب‌های شروع‌شده', value: '$startedCount'),
              const Divider(height: 22),
              _InfoRow(label: 'علاقه‌مندی‌ها', value: '$favoriteCount'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.tonalIcon(
          onPressed: onRefresh,
          icon: const Icon(Icons.sync_rounded),
          label: const Text('همگام‌سازی فهرست'),
        ),
        const SizedBox(height: 28),
        Center(
          child: Column(
            children: [
              Text(
                'معرفت',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: MarefatColors.forest,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'نسخه ۱.۰ · کتاب‌خانهٔ خواندنی',
                style: TextStyle(color: MarefatColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (dark ? MarefatColors.nightSurface : Colors.white)
            .withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MarefatColors.mistDeep.withValues(alpha: dark ? 0.25 : 1),
        ),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: MarefatColors.forest,
        ),
      ),
    ],
  );
}
