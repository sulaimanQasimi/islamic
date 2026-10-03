import 'package:flutter/material.dart';

import '../services/app_storage.dart';

import '../main.dart';
import '../models/book.dart';
import '../services/book_backend.dart';
import '../services/book_cache.dart';
import '../services/epub_parser.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, required this.book, required this.backend});
  final Book book;
  final BookBackend backend;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  EpubDocument? _document;
  String? _error;
  bool _loading = true;
  bool _isOffline = false;
  double _fontSize = 22;
  double _lineHeight = 2;
  int _theme = 0;
  int _chapter = 0;
  String _font = 'سریف';
  String _selectedText = '';
  final Set<int> _bookmarks = {};
  final Set<String> _highlights = {};
  final _scroll = ScrollController();

  static const _palettes = <(Color, Color)>[
    (Color(0xFFF7F4EC), Color(0xFF28352F)),
    (Color(0xFFFFFEFA), Color(0xFF302F2B)),
    (Color(0xFF252A28), Color(0xFFE7E3D7)),
    (Color(0xFFF3E6CC), Color(0xFF4B3D2B)),
  ];
  Color get _background => _palettes[_theme].$1;
  Color get _foreground => _palettes[_theme].$2;
  TextDirection get _contentDirection => widget.book.textDirection;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await AppStorage.getInstance();
      final bytes = await BookCache.read(widget.book.id);
      final cached = bytes != null;
      final epubBytes =
          bytes ?? await widget.backend.downloadBytes(widget.book);
      final doc = EpubParser.parse(
        epubBytes,
        fallbackTitle: widget.book.title,
        fallbackAuthor: widget.book.author,
      );
      await prefs.setInt('chapterCount_${widget.book.id}', doc.chapters.length);
      if (!cached) await BookCache.write(widget.book.id, epubBytes);
      if (!mounted) return;
      setState(() {
        _document = doc;
        _isOffline = true;
        _chapter = (prefs.getInt('progress_${widget.book.id}') ?? 0).clamp(
          0,
          doc.chapters.length - 1,
        );
        _fontSize = prefs.getDouble('readerFontSize') ?? 22;
        _lineHeight = prefs.getDouble('readerLineHeight') ?? 2;
        _theme = (prefs.getInt('readerTheme') ?? 0).clamp(
          0,
          _palettes.length - 1,
        );
        _font = prefs.getString('readerFont') ?? 'سریف';
        _bookmarks.addAll(
          prefs.getStringList('bookmarks_${widget.book.id}')?.map(int.parse) ??
              [],
        );
        _highlights.addAll(
          prefs.getStringList('highlights_${widget.book.id}') ?? [],
        );
        _loading = false;
      });
      if (!cached && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('کتاب برای مطالعهٔ آفلاین آماده شد.'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _saveProgress() async {
    final prefs = await AppStorage.getInstance();
    await prefs.setInt('progress_${widget.book.id}', _chapter);
    final count = _document?.chapters.length;
    if (count != null) {
      await prefs.setInt('chapterCount_${widget.book.id}', count);
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await AppStorage.getInstance();
    await prefs.setStringList(
      'bookmarks_${widget.book.id}',
      _bookmarks.map((n) => n.toString()).toList(),
    );
    await prefs.setStringList(
      'highlights_${widget.book.id}',
      _highlights.toList(),
    );
  }

  void _setChapter(int value) {
    if (_document == null) return;
    setState(() => _chapter = value.clamp(0, _document!.chapters.length - 1));
    _saveProgress();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _toggleBookmark() {
    setState(
      () => _bookmarks.contains(_chapter)
          ? _bookmarks.remove(_chapter)
          : _bookmarks.add(_chapter),
    );
    _saveNotes();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _bookmarks.contains(_chapter)
              ? 'نشانک این فصل ذخیره شد.'
              : 'نشانک برداشته شد.',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _addHighlight() {
    if (_selectedText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('برای برجسته‌سازی، بخشی از متن را انتخاب کنید.'),
        ),
      );
      return;
    }
    setState(() => _highlights.add(_selectedText.trim()));
    _saveNotes();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('یادداشت به برجسته‌شده‌ها افزوده شد.')),
    );
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'تنظیمات مطالعه',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'اندازهٔ قلم',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Row(
                  children: [
                    const Text('آ'),
                    Expanded(
                      child: Slider(
                        value: _fontSize,
                        min: 17,
                        max: 34,
                        divisions: 17,
                        onChanged: (v) {
                          setState(() => _fontSize = v);
                          refresh(() {});
                          _saveReaderSettings();
                        },
                      ),
                    ),
                    const Text('آ', style: TextStyle(fontSize: 25)),
                  ],
                ),
                const Text(
                  'فاصلهٔ خط‌ها',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Slider(
                  value: _lineHeight,
                  min: 1.5,
                  max: 2.6,
                  divisions: 11,
                  onChanged: (v) {
                    setState(() => _lineHeight = v);
                    refresh(() {});
                    _saveReaderSettings();
                  },
                ),
                const Text(
                  'نوع قلم',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['سریف', 'ساده']
                      .map(
                        (name) => ChoiceChip(
                          label: Text(name),
                          selected: _font == name,
                          onSelected: (_) {
                            setState(() => _font = name);
                            refresh(() {});
                            _saveReaderSettings();
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'رنگ صفحه',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(
                    _palettes.length,
                    (i) => GestureDetector(
                      onTap: () {
                        setState(() => _theme = i);
                        refresh(() {});
                        _saveReaderSettings();
                      },
                      child: Container(
                        margin: const EdgeInsetsDirectional.only(end: 12),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _palettes[i].$1,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _theme == i ? green : Colors.black12,
                            width: _theme == i ? 3 : 1,
                          ),
                        ),
                        child: _theme == i
                            ? Icon(
                                Icons.check,
                                color: _palettes[i].$2,
                                size: 18,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveReaderSettings() async {
    final prefs = await AppStorage.getInstance();
    await prefs.setDouble('readerFontSize', _fontSize);
    await prefs.setDouble('readerLineHeight', _lineHeight);
    await prefs.setInt('readerTheme', _theme);
    await prefs.setString('readerFont', _font);
  }

  void _showContents() {
    final chapters = _document?.chapters ?? [];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'فهرست کتاب',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 10),
              ...chapters.asMap().entries.map(
                (entry) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE4ECE7),
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(color: green),
                    ),
                  ),
                  title: Text(entry.value.title),
                  trailing: _bookmarks.contains(entry.key)
                      ? const Icon(Icons.bookmark_rounded, color: green)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _setChapter(entry.key);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _findInBook() async {
    final controller = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('جست‌وجو در کتاب'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'واژه یا عبارت را بنویسید',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لغو'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('جست‌وجو'),
            ),
          ],
        ),
      ),
    );
    if (query == null || query.trim().isEmpty || _document == null) return;
    final index = _document!.chapters.indexWhere(
      (chapter) =>
          chapter.body.toLowerCase().contains(query.trim().toLowerCase()),
    );
    if (index < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('این عبارت در کتاب پیدا نشد.')),
        );
      }
    } else {
      _setChapter(index);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('عبارت در فصل ${index + 1} پیدا شد.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final document = _document;
    final current = document == null ? null : document.chapters[_chapter];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          leading: IconButton(
            onPressed: () => Navigator.pop(context, _chapter),
            icon: Icon(Icons.arrow_back_rounded, color: _foreground),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                document?.title ?? widget.book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _foreground,
                ),
              ),
              Text(
                _isOffline
                    ? (_contentDirection == TextDirection.ltr
                          ? 'LTR · آماده برای مطالعه'
                          : 'RTL · آماده برای مطالعه')
                    : 'در حال بارگذاری',
                style: TextStyle(
                  fontSize: 10,
                  color: _foreground.withValues(alpha: .6),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _findInBook,
              icon: Icon(Icons.search_rounded, color: _foreground),
              tooltip: 'جست‌وجو در کتاب',
            ),
            IconButton(
              onPressed: _toggleBookmark,
              icon: Icon(
                _bookmarks.contains(_chapter)
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: _foreground,
              ),
              tooltip: 'نشانک فصل',
            ),
            IconButton(
              onPressed: _openSettings,
              icon: Icon(Icons.tune_rounded, color: _foreground),
              tooltip: 'تنظیمات',
            ),
            const SizedBox(width: 5),
          ],
        ),
        body: _loading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: green),
                    SizedBox(height: 14),
                    Text('کتاب در حال بارگذاری است…'),
                  ],
                ),
              )
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.menu_book_outlined,
                        color: green,
                        size: 44,
                      ),
                      const SizedBox(height: 12),
                      const Text('بازکردن کتاب ممکن نشد.'),
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _load();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('تلاش دوباره'),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  LinearProgressIndicator(
                    value: (_chapter + 1) / document!.chapters.length,
                    minHeight: 2,
                    color: green,
                    backgroundColor: _foreground.withValues(alpha: .08),
                  ),
                  Expanded(
                    child: SelectionArea(
                      onSelectionChanged: (selection) =>
                          _selectedText = selection?.plainText ?? '',
                      child: Scrollbar(
                        controller: _scroll,
                        child: SingleChildScrollView(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(27, 30, 27, 30),
                          child: Directionality(
                            textDirection: _contentDirection,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        current!.title,
                                        textAlign: _contentDirection ==
                                                TextDirection.rtl
                                            ? TextAlign.right
                                            : TextAlign.left,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: green,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (_bookmarks.contains(_chapter))
                                      const Icon(
                                        Icons.bookmark_rounded,
                                        color: green,
                                        size: 18,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 23),
                                SelectableText(
                                  current.body,
                                  textDirection: _contentDirection,
                                  style: TextStyle(
                                    fontSize: _fontSize,
                                    height: _lineHeight,
                                    color: _foreground,
                                    fontFamily: _font == 'سریف'
                                        ? 'serif'
                                        : null,
                                  ),
                                  textAlign: TextAlign.justify,
                                ),
                                if (_highlights.isNotEmpty) ...[
                                  const SizedBox(height: 30),
                                  Divider(
                                    color: _foreground.withValues(alpha: .12),
                                  ),
                                  Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: const Text(
                                      'برجسته‌شده‌ها',
                                      style: TextStyle(
                                        color: green,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  ..._highlights.map(
                                    (text) => Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Container(
                                        padding: const EdgeInsets.all(11),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFEDAA)
                                              .withValues(
                                                alpha: _theme == 2 ? .2 : .65,
                                              ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          text,
                                          textDirection: _contentDirection,
                                          style: TextStyle(
                                            color: _foreground,
                                            fontSize: 14,
                                            height: 1.7,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 45),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(17, 7, 17, 14),
                    decoration: BoxDecoration(
                      color: _background,
                      border: Border(
                        top: BorderSide(
                          color: _foreground.withValues(alpha: .08),
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => _setChapter(_chapter - 1),
                              icon: Icon(
                                Icons.chevron_right_rounded,
                                color: _foreground,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    'فصل ${_chapter + 1} از ${document.chapters.length}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _foreground.withValues(alpha: .62),
                                    ),
                                  ),
                                  if (document.chapters.length > 1)
                                    Slider(
                                      value: _chapter.toDouble(),
                                      min: 0,
                                      max: (document.chapters.length - 1)
                                          .toDouble(),
                                      onChanged: (value) =>
                                          _setChapter(value.round()),
                                      activeColor: green,
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _setChapter(_chapter + 1),
                              icon: Icon(
                                Icons.chevron_left_rounded,
                                color: _foreground,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: _addHighlight,
                              icon: const Icon(Icons.highlight_alt_rounded),
                              label: const Text('برجسته‌سازی'),
                            ),
                            TextButton.icon(
                              onPressed: _showContents,
                              icon: const Icon(Icons.list_rounded),
                              label: const Text('فهرست'),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () {
                                setState(
                                  () => _fontSize = (_fontSize - 1)
                                      .clamp(17, 34)
                                      .toDouble(),
                                );
                                _saveReaderSettings();
                              },
                              icon: Icon(Icons.remove, color: _foreground),
                            ),
                            Text(
                              '${_fontSize.round()}',
                              style: TextStyle(color: _foreground),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(
                                  () => _fontSize = (_fontSize + 1)
                                      .clamp(17, 34)
                                      .toDouble(),
                                );
                                _saveReaderSettings();
                              },
                              icon: Icon(Icons.add, color: _foreground),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
