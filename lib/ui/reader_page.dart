import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_html/flutter_html.dart';

import '../models/book.dart';
import '../services/app_storage.dart';
import '../services/book_backend.dart';
import '../services/book_cache.dart';
import '../services/epub_parser.dart';
import '../theme/marefat_theme.dart';

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
  bool _chromeVisible = true;
  double _fontSize = 22;
  double _lineHeight = 2;
  int _theme = 0;
  int _chapter = 0;
  String _align = 'justify';
  String _selectedText = '';
  final Set<int> _bookmarks = {};
  final Set<String> _highlights = {};
  final _scroll = ScrollController();

  static const _palettes = <(Color, Color, String)>[
    (Color(0xFFF7F4EC), Color(0xFF28352F), 'کاغذی'),
    (Color(0xFFFFFEFA), Color(0xFF302F2B), 'روشن'),
    (Color(0xFF1A2421), Color(0xFFE7E3D7), 'شب'),
    (Color(0xFFF3E6CC), Color(0xFF4B3D2B), 'سپیده'),
  ];
  static const _alignOptions = <(String, IconData, String)>[
    ('right', Icons.format_align_right_rounded, 'راست'),
    ('center', Icons.format_align_center_rounded, 'وسط'),
    ('left', Icons.format_align_left_rounded, 'چپ'),
    ('justify', Icons.format_align_justify_rounded, 'دوطرفه'),
  ];

  Color get _background => _palettes[_theme].$1;
  Color get _foreground => _palettes[_theme].$2;
  TextDirection get _contentDirection => widget.book.textDirection;

  List<String> get _chapterHighlights => _highlights
      .map((entry) {
        final sep = entry.indexOf('|');
        if (sep < 0) return entry;
        final chapter = int.tryParse(entry.substring(0, sep));
        return chapter == _chapter ? entry.substring(sep + 1) : null;
      })
      .whereType<String>()
      .toList();

  TextAlign get _bodyAlign => switch (_align) {
    'left' => TextAlign.left,
    'right' => TextAlign.right,
    'center' => TextAlign.center,
    _ => TextAlign.justify,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
        _isOffline = cached;
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
        _align = _normalizeAlign(prefs.getString('readerAlign'));
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
          const SnackBar(content: Text('کتاب برای مطالعهٔ آفلاین آماده شد.')),
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

  Future<void> _saveReaderSettings() async {
    final prefs = await AppStorage.getInstance();
    await prefs.setDouble('readerFontSize', _fontSize);
    await prefs.setDouble('readerLineHeight', _lineHeight);
    await prefs.setInt('readerTheme', _theme);
    await prefs.setString('readerAlign', _align);
  }

  String _normalizeAlign(String? value) {
    const allowed = {'left', 'right', 'center', 'justify'};
    if (value != null && allowed.contains(value)) return value;
    return 'justify';
  }

  String _escapeHtml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('\n\n', '</p><p>')
      .replaceAll('\n', '<br/>');

  Map<String, Style> _readerHtmlStyles() {
    final base = Style(
      fontSize: FontSize(_fontSize),
      lineHeight: LineHeight(_lineHeight),
      color: _foreground,
      textAlign: _bodyAlign,
      direction: _contentDirection,
      margin: Margins.zero,
      padding: HtmlPaddings.zero,
    );
    Style heading(double scale) => Style(
      fontSize: FontSize(_fontSize * scale),
      lineHeight: LineHeight((_lineHeight * 0.92).clamp(1.2, 2.2)),
      color: _foreground,
      fontWeight: FontWeight.w800,
      textAlign: _bodyAlign,
      direction: _contentDirection,
      margin: Margins.only(top: 18, bottom: 10),
    );

    return {
      'html': Style(backgroundColor: Colors.transparent),
      'body': base,
      'div': base,
      'span': Style(
        fontSize: FontSize(_fontSize),
        lineHeight: LineHeight(_lineHeight),
        color: _foreground,
        direction: _contentDirection,
      ),
      'p': Style(
        fontSize: FontSize(_fontSize),
        lineHeight: LineHeight(_lineHeight),
        color: _foreground,
        textAlign: _bodyAlign,
        direction: _contentDirection,
        margin: Margins.only(bottom: 14),
      ),
      'h1': heading(1.45),
      'h2': heading(1.3),
      'h3': heading(1.18),
      'h4': heading(1.1),
      'h5': heading(1.05),
      'h6': heading(1.0),
      'i': Style(fontStyle: FontStyle.italic, color: _foreground),
      'em': Style(fontStyle: FontStyle.italic, color: _foreground),
      'b': Style(fontWeight: FontWeight.w800, color: _foreground),
      'strong': Style(fontWeight: FontWeight.w800, color: _foreground),
      'blockquote': Style(
        fontSize: FontSize(_fontSize),
        lineHeight: LineHeight(_lineHeight),
        color: _foreground.withValues(alpha: 0.92),
        fontStyle: FontStyle.italic,
        padding: HtmlPaddings.symmetric(horizontal: 14, vertical: 8),
        margin: Margins.symmetric(vertical: 12),
        border: Border(
          right: _contentDirection == TextDirection.rtl
              ? BorderSide(color: MarefatColors.forest.withValues(alpha: 0.45), width: 3)
              : BorderSide.none,
          left: _contentDirection == TextDirection.ltr
              ? BorderSide(color: MarefatColors.forest.withValues(alpha: 0.45), width: 3)
              : BorderSide.none,
        ),
      ),
      'ul': Style(
        margin: Margins.only(bottom: 12),
        padding: HtmlPaddings.only(
          right: _contentDirection == TextDirection.rtl ? 18 : 0,
          left: _contentDirection == TextDirection.ltr ? 18 : 0,
        ),
        color: _foreground,
        fontSize: FontSize(_fontSize),
        lineHeight: LineHeight(_lineHeight),
      ),
      'ol': Style(
        margin: Margins.only(bottom: 12),
        padding: HtmlPaddings.only(
          right: _contentDirection == TextDirection.rtl ? 18 : 0,
          left: _contentDirection == TextDirection.ltr ? 18 : 0,
        ),
        color: _foreground,
        fontSize: FontSize(_fontSize),
        lineHeight: LineHeight(_lineHeight),
      ),
      'li': Style(
        color: _foreground,
        fontSize: FontSize(_fontSize),
        lineHeight: LineHeight(_lineHeight),
        margin: Margins.only(bottom: 6),
      ),
      'a': Style(
        color: MarefatColors.forest,
        textDecoration: TextDecoration.underline,
      ),
      'hr': Style(
        margin: Margins.symmetric(vertical: 16),
        border: Border(top: BorderSide(color: _foreground.withValues(alpha: 0.15))),
      ),
      'table': Style(
        color: _foreground,
        fontSize: FontSize(_fontSize * 0.92),
        margin: Margins.symmetric(vertical: 12),
      ),
      'td': Style(
        padding: HtmlPaddings.all(6),
        color: _foreground,
        fontSize: FontSize(_fontSize * 0.92),
        border: Border.all(color: _foreground.withValues(alpha: 0.12)),
      ),
      'th': Style(
        padding: HtmlPaddings.all(6),
        color: _foreground,
        fontWeight: FontWeight.w800,
        fontSize: FontSize(_fontSize * 0.92),
        border: Border.all(color: _foreground.withValues(alpha: 0.12)),
      ),
      'img': Style(
        width: Width(100, Unit.percent),
        alignment: Alignment.center,
        margin: Margins.symmetric(vertical: 14),
        display: Display.block,
      ),
      'sup': Style(fontSize: FontSize(_fontSize * 0.72)),
      'sub': Style(fontSize: FontSize(_fontSize * 0.72)),
    };
  }

  void _setChapter(int value) {
    if (_document == null) return;
    setState(() => _chapter = value.clamp(0, _document!.chapters.length - 1));
    _saveProgress();
    if (_scroll.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(0);
      });
    }
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
    setState(() => _highlights.add('$_chapter|${_selectedText.trim()}'));
    _saveNotes();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('یادداشت به برجسته‌شده‌ها افزوده شد.')),
    );
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: MarefatColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                const SizedBox(height: 18),
                const Text(
                  'تنظیمات مطالعه',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: MarefatColors.ink,
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
                const SizedBox(height: 12),
                const Text(
                  'تراز متن',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _alignOptions
                      .map(
                        (option) => ChoiceChip(
                          avatar: Icon(option.$2, size: 18),
                          label: Text(option.$3),
                          selected: _align == option.$1,
                          onSelected: (_) {
                            setState(() => _align = option.$1);
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
                Wrap(
                  spacing: 10,
                  children: List.generate(_palettes.length, (i) {
                    final selected = _theme == i;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _theme = i);
                        refresh(() {});
                        _saveReaderSettings();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: _palettes[i].$1,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? MarefatColors.forest
                                : Colors.black12,
                            width: selected ? 2.5 : 1,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: MarefatColors.forest.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            _palettes[i].$3,
                            style: TextStyle(
                              color: _palettes[i].$2,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContents() {
    final chapters = _document?.chapters ?? [];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MarefatColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, controller) => SafeArea(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'فهرست کتاب',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: MarefatColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                ...chapters.asMap().entries.map(
                  (entry) => ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    selected: entry.key == _chapter,
                    selectedTileColor: MarefatColors.forest.withValues(
                      alpha: 0.1,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: MarefatColors.mistDeep,
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(
                          color: MarefatColors.forest,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(
                      entry.value.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    trailing: _bookmarks.contains(entry.key)
                        ? const Icon(
                            Icons.bookmark_rounded,
                            color: MarefatColors.forest,
                          )
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

  void _toggleChrome() {
    setState(() => _chromeVisible = !_chromeVisible);
    SystemChrome.setEnabledSystemUIMode(
      _chromeVisible
          ? SystemUiMode.edgeToEdge
          : SystemUiMode.immersiveSticky,
    );
  }

  @override
  Widget build(BuildContext context) {
    final document = _document;
    final current = document == null ? null : document.chapters[_chapter];
    final progressValue = document == null
        ? 0.0
        : (_chapter + 1) / document.chapters.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: _theme == 2
              ? Brightness.light
              : Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: _background,
          body: _loading
              ? _LoadingView(background: _background, foreground: _foreground)
              : _error != null
                  ? _ErrorView(
                      background: _background,
                      foreground: _foreground,
                      error: _error!,
                      onRetry: () {
                        setState(() {
                          _loading = true;
                          _error = null;
                        });
                        _load();
                      },
                      onBack: () => Navigator.pop(context, _chapter),
                    )
                  : Stack(
                      children: [
                        Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              height: _chromeVisible
                                  ? MediaQuery.paddingOf(context).top + 56
                                  : MediaQuery.paddingOf(context).top,
                              color: _background,
                              child: _chromeVisible
                                  ? SafeArea(
                                      bottom: false,
                                      child: _ReaderAppBar(
                                        title:
                                            document?.title ?? widget.book.title,
                                        subtitle: _isOffline
                                            ? 'آماده برای مطالعهٔ آفلاین'
                                            : 'همگام‌سازی شد',
                                        foreground: _foreground,
                                        bookmarked:
                                            _bookmarks.contains(_chapter),
                                        onBack: () =>
                                            Navigator.pop(context, _chapter),
                                        onSearch: _findInBook,
                                        onBookmark: _toggleBookmark,
                                        onSettings: _openSettings,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            LinearProgressIndicator(
                              value: progressValue,
                              minHeight: 2.5,
                              color: MarefatColors.forest,
                              backgroundColor: _foreground.withValues(
                                alpha: 0.08,
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: _toggleChrome,
                                child: SelectionArea(
                                  onSelectionChanged: (selection) =>
                                      _selectedText =
                                          selection?.plainText ?? '',
                                  child: Scrollbar(
                                    controller: _scroll,
                                    child: SingleChildScrollView(
                                      controller: _scroll,
                                      padding: const EdgeInsets.fromLTRB(
                                        28,
                                        28,
                                        28,
                                        120,
                                      ),
                                      child: Directionality(
                                        textDirection: _contentDirection,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                              current!.title,
                                              textAlign:
                                                  _contentDirection ==
                                                          TextDirection.rtl
                                                      ? TextAlign.right
                                                      : TextAlign.left,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: MarefatColors.forest,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 22),
                                            Html(
                                              data: current.html.isNotEmpty
                                                  ? current.html
                                                  : '<p>${_escapeHtml(current.body)}</p>',
                                              style: _readerHtmlStyles(),
                                            ),
                                            if (_chapterHighlights
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 30),
                                              Divider(
                                                color: _foreground.withValues(
                                                  alpha: 0.12,
                                                ),
                                              ),
                                              const Directionality(
                                                textDirection:
                                                    TextDirection.rtl,
                                                child: Text(
                                                  'برجسته‌شده‌ها',
                                                  style: TextStyle(
                                                    color: MarefatColors.forest,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              ..._chapterHighlights.map(
                                                (text) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    top: 10,
                                                  ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                      12,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFFFEDAA,
                                                      ).withValues(
                                                        alpha: _theme == 2
                                                            ? 0.2
                                                            : 0.65,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        14,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      text,
                                                      textDirection:
                                                          _contentDirection,
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
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_chromeVisible)
                          Positioned(
                            left: 14,
                            right: 14,
                            bottom: 14,
                            child: SafeArea(
                              top: false,
                              child: _ReaderDock(
                                foreground: _foreground,
                                background: _background,
                                chapter: _chapter,
                                total: document!.chapters.length,
                                fontSize: _fontSize,
                                onPrev: () => _setChapter(_chapter - 1),
                                onNext: () => _setChapter(_chapter + 1),
                                onChapter: _setChapter,
                                onHighlight: _addHighlight,
                                onContents: _showContents,
                                onFontDown: () {
                                  setState(
                                    () => _fontSize = (_fontSize - 1)
                                        .clamp(17, 34)
                                        .toDouble(),
                                  );
                                  _saveReaderSettings();
                                },
                                onFontUp: () {
                                  setState(
                                    () => _fontSize = (_fontSize + 1)
                                        .clamp(17, 34)
                                        .toDouble(),
                                  );
                                  _saveReaderSettings();
                                },
                              ).animate().fadeIn(duration: 220.ms).slideY(
                                    begin: 0.12,
                                    curve: Curves.easeOutCubic,
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

class _ReaderAppBar extends StatelessWidget {
  const _ReaderAppBar({
    required this.title,
    required this.subtitle,
    required this.foreground,
    required this.bookmarked,
    required this.onBack,
    required this.onSearch,
    required this.onBookmark,
    required this.onSettings,
  });

  final String title;
  final String subtitle;
  final Color foreground;
  final bool bookmarked;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onBookmark;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(Icons.arrow_back_rounded, color: foreground),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: foreground.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onSearch,
            icon: Icon(Icons.search_rounded, color: foreground),
            tooltip: 'جست‌وجو',
          ),
          IconButton(
            onPressed: onBookmark,
            icon: Icon(
              bookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: foreground,
            ),
            tooltip: 'نشانک',
          ),
          IconButton(
            onPressed: onSettings,
            icon: Icon(Icons.tune_rounded, color: foreground),
            tooltip: 'تنظیمات',
          ),
        ],
      ),
    );
  }
}

class _ReaderDock extends StatelessWidget {
  const _ReaderDock({
    required this.foreground,
    required this.background,
    required this.chapter,
    required this.total,
    required this.fontSize,
    required this.onPrev,
    required this.onNext,
    required this.onChapter,
    required this.onHighlight,
    required this.onContents,
    required this.onFontDown,
    required this.onFontUp,
  });

  final Color foreground;
  final Color background;
  final int chapter;
  final int total;
  final double fontSize;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<int> onChapter;
  final VoidCallback onHighlight;
  final VoidCallback onContents;
  final VoidCallback onFontDown;
  final VoidCallback onFontUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: foreground.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
                tooltip: 'فصل قبل',
                icon: Icon(Icons.chevron_left_rounded, color: foreground),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'فصل ${chapter + 1} از $total',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: foreground.withValues(alpha: 0.65),
                      ),
                    ),
                    if (total > 1)
                      Slider(
                        value: chapter.toDouble(),
                        min: 0,
                        max: (total - 1).toDouble(),
                        onChanged: (value) => onChapter(value.round()),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onNext,
                tooltip: 'فصل بعد',
                icon: Icon(Icons.chevron_right_rounded, color: foreground),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: onHighlight,
                    tooltip: 'برجسته‌سازی',
                    icon: Icon(Icons.highlight_alt_rounded, color: foreground),
                  ),
                  IconButton(
                    onPressed: onContents,
                    tooltip: 'فهرست',
                    icon: Icon(Icons.list_rounded, color: foreground),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: onFontDown,
                    tooltip: 'کوچک‌تر',
                    icon: Icon(Icons.remove_rounded, color: foreground),
                  ),
                  Text(
                    '${fontSize.round()}',
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    onPressed: onFontUp,
                    tooltip: 'بزرگ‌تر',
                    icon: Icon(Icons.add_rounded, color: foreground),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.background, required this.foreground});
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: background,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: MarefatColors.forest)
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1200.ms, color: MarefatColors.brassSoft),
          const SizedBox(height: 16),
          Text(
            'معرفت در حال گشودن کتاب است…',
            style: TextStyle(
              color: foreground.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.background,
    required this.foreground,
    required this.error,
    required this.onRetry,
    required this.onBack,
  });

  final Color background;
  final Color foreground;
  final String error;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: background,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, color: MarefatColors.forest, size: 44),
            const SizedBox(height: 12),
            Text(
              'بازکردن کتاب ممکن نشد.',
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: foreground.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('تلاش دوباره'),
            ),
            TextButton(onPressed: onBack, child: const Text('بازگشت')),
          ],
        ),
      ),
    ),
  );
}
