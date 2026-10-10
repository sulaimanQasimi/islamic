import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/book.dart';
import '../models/text_highlight.dart';
import '../services/app_storage.dart';
import '../services/book_backend.dart';
import '../services/book_cache.dart';
import '../services/dictionary_service.dart';
import '../services/epub_parser.dart';
import '../services/night_auto.dart';
import '../services/reading_goals.dart';
import '../services/reading_history.dart';
import '../theme/marefat_theme.dart';
import '../widgets/epub_html_view.dart';
import '../widgets/quote_card_sheet.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, required this.book, required this.backend});
  final Book book;
  final BookBackend backend;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> with WidgetsBindingObserver {
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
  final List<TextHighlight> _highlights = [];
  final _scroll = ScrollController();

  DateTime? _sessionStarted;
  int _pendingSeconds = 0;
  Timer? _focusTimer;
  int _focusRemainingSec = 0;
  bool _focusActive = false;

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

  List<TextHighlight> get _chapterHighlights =>
      _highlights.where((h) => h.chapter == _chapter).toList();

  TextAlign get _bodyAlign => switch (_align) {
    'left' => TextAlign.left,
    'right' => TextAlign.right,
    'center' => TextAlign.center,
    _ => TextAlign.justify,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionStarted = DateTime.now();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusTimer?.cancel();
    _flushReadingTime();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseSessionClock();
    } else if (state == AppLifecycleState.resumed) {
      _sessionStarted = DateTime.now();
    }
  }

  void _pauseSessionClock() {
    final started = _sessionStarted;
    if (started == null) return;
    _pendingSeconds += DateTime.now().difference(started).inSeconds;
    _sessionStarted = null;
  }

  Future<void> _flushReadingTime() async {
    _pauseSessionClock();
    if (_pendingSeconds < 15) {
      _pendingSeconds = 0;
      return;
    }
    final secs = _pendingSeconds;
    _pendingSeconds = 0;
    await ReadingGoals.addSeconds(secs);
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
        _highlights
          ..clear()
          ..addAll(_loadHighlights(prefs));
        _loading = false;
      });
      if (await NightAuto.isNightNow()) {
        if (mounted) {
          setState(() => _theme = NightAuto.readerNightThemeIndex);
        }
      }
      // Persist migrated legacy highlights once.
      if (_highlights.isNotEmpty &&
          (prefs.getString('highlights_json_${widget.book.id}') == null ||
              prefs.getString('highlights_json_${widget.book.id}')!.isEmpty)) {
        await _saveNotes();
      }
      await ReadingHistory.record(
        bookId: widget.book.id,
        title: widget.book.title,
        author: widget.book.author,
        chapter: _chapter,
      );
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

  List<TextHighlight> _loadHighlights(AppStorage prefs) {
    final jsonKey = 'highlights_json_${widget.book.id}';
    final fromJson = TextHighlight.decodeList(prefs.getString(jsonKey));
    if (fromJson.isNotEmpty) return fromJson;

    final legacy = prefs.getStringList('highlights_${widget.book.id}') ?? [];
    if (legacy.isEmpty) return const [];
    return [
      for (final entry in legacy)
        if (entry.trim().isNotEmpty) TextHighlight.fromLegacy(entry),
    ];
  }

  Future<void> _saveNotes() async {
    final prefs = await AppStorage.getInstance();
    await prefs.setStringList(
      'bookmarks_${widget.book.id}',
      _bookmarks.map((n) => n.toString()).toList(),
    );
    await prefs.setString(
      'highlights_json_${widget.book.id}',
      TextHighlight.encodeList(_highlights),
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

  void _setChapter(int value) {
    if (_document == null) return;
    setState(() => _chapter = value.clamp(0, _document!.chapters.length - 1));
    _saveProgress();
    ReadingHistory.record(
      bookId: widget.book.id,
      title: widget.book.title,
      author: widget.book.author,
      chapter: _chapter,
    );
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

  Future<void> _addHighlight() async {
    final selected = _selectedText.trim();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('برای برجسته‌سازی، بخشی از متن را انتخاب کنید.'),
        ),
      );
      return;
    }
    if (selected.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('متن انتخاب‌شده خیلی کوتاه است.')),
      );
      return;
    }

    final existing = _highlights.where(
      (h) => h.chapter == _chapter && h.text == selected,
    );
    if (existing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('این متن قبلاً برجسته شده است.')),
      );
      return;
    }

    var colorIndex = 0;
    final noteController = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: MarefatColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, refresh) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  22,
                  14,
                  22,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    const SizedBox(height: 16),
                    const Text(
                      'برجسته‌سازی متن',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: MarefatColors.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: TextHighlight.palette[colorIndex]
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        selected,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        textDirection: _contentDirection,
                        style: const TextStyle(
                          height: 1.6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'رنگ',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (var i = 0; i < TextHighlight.palette.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: GestureDetector(
                              onTap: () => refresh(() => colorIndex = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: TextHighlight.palette[i],
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colorIndex == i
                                        ? MarefatColors.forest
                                        : Colors.black26,
                                    width: colorIndex == i ? 3 : 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'یادداشت (اختیاری)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.highlight_rounded),
                      label: const Text('ذخیره برجسته‌سازی'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('لغو'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    final note = noteController.text.trim();
    noteController.dispose();
    if (confirmed != true || !mounted) return;

    final highlight = TextHighlight(
      id: 'h_${DateTime.now().microsecondsSinceEpoch}',
      chapter: _chapter,
      text: selected,
      colorIndex: colorIndex,
      note: note.isEmpty ? null : note,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    setState(() {
      _highlights.insert(0, highlight);
      _selectedText = '';
    });
    await _saveNotes();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('متن برجسته و ذخیره شد.')),
    );
  }

  Future<void> _removeHighlight(TextHighlight highlight) async {
    setState(() => _highlights.removeWhere((h) => h.id == highlight.id));
    await _saveNotes();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('برجسته‌سازی حذف شد.')),
    );
  }

  Future<void> _updateHighlight(TextHighlight updated) async {
    final index = _highlights.indexWhere((h) => h.id == updated.id);
    if (index < 0) return;
    setState(() => _highlights[index] = updated);
    await _saveNotes();
  }

  Future<void> _showHighlights() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: MarefatColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, refresh) {
            final items = [..._highlights]
              ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
            return Directionality(
              textDirection: TextDirection.rtl,
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.62,
                minChildSize: 0.4,
                maxChildSize: 0.92,
                builder: (context, controller) {
                  return SafeArea(
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'برجسته‌شده‌ها',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: MarefatColors.ink,
                                  ),
                                ),
                              ),
                              if (items.isNotEmpty)
                                IconButton(
                                  tooltip: 'خروجی',
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _exportHighlights();
                                  },
                                  icon: const Icon(Icons.ios_share_rounded),
                                ),
                              Text(
                                '${items.length}',
                                style: TextStyle(
                                  color: MarefatColors.forest.withValues(
                                    alpha: 0.8,
                                  ),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: items.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(28),
                                    child: Text(
                                      'هنوز متنی برجسته نکرده‌اید.\nمتن را انتخاب کنید و دکمه برجسته‌سازی را بزنید.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        height: 1.7,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  controller: controller,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    4,
                                    16,
                                    24,
                                  ),
                                  itemCount: items.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final item = items[index];
                                    final chapterTitle =
                                        (_document != null &&
                                                item.chapter >= 0 &&
                                                item.chapter <
                                                    _document!
                                                        .chapters.length)
                                            ? _document!
                                                .chapters[item.chapter].title
                                            : 'فصل ${item.chapter + 1}';
                                    return Material(
                                      color: item.color.withValues(alpha: 0.28),
                                      borderRadius: BorderRadius.circular(16),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _setChapter(item.chapter);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 12,
                                                    height: 12,
                                                    decoration: BoxDecoration(
                                                      color: item.color,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: Colors.black26,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      chapterTitle,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: MarefatColors
                                                            .forest,
                                                      ),
                                                    ),
                                                  ),
                                                  PopupMenuButton<String>(
                                                    onSelected: (action) async {
                                                      if (action == 'delete') {
                                                        await _removeHighlight(
                                                          item,
                                                        );
                                                        refresh(() {});
                                                      } else if (action
                                                          .startsWith(
                                                        'color_',
                                                      )) {
                                                        final color =
                                                            int.parse(
                                                          action.substring(6),
                                                        );
                                                        await _updateHighlight(
                                                          item.copyWith(
                                                            colorIndex: color,
                                                          ),
                                                        );
                                                        refresh(() {});
                                                      } else if (action ==
                                                          'note') {
                                                        await _editHighlightNote(
                                                          item,
                                                        );
                                                        refresh(() {});
                                                      } else if (action ==
                                                          'quote') {
                                                        await showQuoteCardSheet(
                                                          context: context,
                                                          quote: item.text,
                                                          bookTitle:
                                                              widget.book.title,
                                                          author:
                                                              widget.book.author,
                                                        );
                                                      }
                                                    },
                                                    itemBuilder: (context) => [
                                                      const PopupMenuItem(
                                                        value: 'quote',
                                                        child: Text(
                                                          'کارت نقل‌قول',
                                                        ),
                                                      ),
                                                      const PopupMenuItem(
                                                        value: 'note',
                                                        child: Text(
                                                          'ویرایش یادداشت',
                                                        ),
                                                      ),
                                                      ...List.generate(
                                                        TextHighlight
                                                            .palette.length,
                                                        (i) => PopupMenuItem(
                                                          value: 'color_$i',
                                                          child: Row(
                                                            children: [
                                                              Container(
                                                                width: 14,
                                                                height: 14,
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color:
                                                                      TextHighlight
                                                                          .palette[i],
                                                                  shape: BoxShape
                                                                      .circle,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                              Text(
                                                                TextHighlight
                                                                    .paletteLabels[i],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      const PopupMenuDivider(),
                                                      const PopupMenuItem(
                                                        value: 'delete',
                                                        child: Text(
                                                          'حذف',
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                item.text,
                                                maxLines: 4,
                                                overflow: TextOverflow.ellipsis,
                                                textDirection:
                                                    _contentDirection,
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
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black
                                                        .withValues(
                                                      alpha: 0.55,
                                                    ),
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
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editHighlightNote(TextHighlight item) async {
    final controller = TextEditingController(text: item.note ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('یادداشت برجسته‌سازی'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'یادداشت خود را بنویسید…',
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
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
    final note = controller.text.trim();
    controller.dispose();
    if (saved != true) return;
    await _updateHighlight(
      item.copyWith(note: note, clearNote: note.isEmpty),
    );
  }

  Future<void> _exportHighlights() async {
    if (_highlights.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برجسته‌سازی‌ای برای خروجی نیست.')),
      );
      return;
    }
    final buf = StringBuffer('برجسته‌شده‌های «${widget.book.title}»\n');
    buf.writeln('—'.padRight(28, '—'));
    final sorted = [..._highlights]
      ..sort((a, b) {
        final c = a.chapter.compareTo(b.chapter);
        return c != 0 ? c : a.createdAtMs.compareTo(b.createdAtMs);
      });
    for (final h in sorted) {
      buf.writeln();
      buf.writeln('فصل ${h.chapter + 1}');
      buf.writeln(h.text);
      if (h.note != null && h.note!.isNotEmpty) {
        buf.writeln('یادداشت: ${h.note}');
      }
    }
    buf.writeln('\nمعرفت');
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('برجسته‌شده‌ها کپی شدند.')),
    );
  }

  Future<void> _lookupSelection() async {
    final word = DictionaryService.normalize(_selectedText);
    if (word.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('واژه‌ای را برای معنا انتخاب کنید.')),
      );
      return;
    }
    final meaning = DictionaryService.lookup(word);
    final suggestions = DictionaryService.suggestions(word);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: MarefatColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                word,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: MarefatColors.forest,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                meaning ??
                    'معنای مستقیمی پیدا نشد. چند واژهٔ نزدیک:',
                style: const TextStyle(height: 1.7, fontWeight: FontWeight.w600),
              ),
              if (meaning == null) ...[
                const SizedBox(height: 12),
                for (final s in suggestions.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '• ${s.key}: ${s.value}',
                      style: const TextStyle(height: 1.5, fontSize: 13),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startFocusMode() async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: MarefatColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'حالت تمرکز',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'نوار ابزار پنهان می‌شود تا زمان تمرکز تمام شود.',
                style: TextStyle(color: MarefatColors.muted),
              ),
              const SizedBox(height: 16),
              for (final m in [10, 15, 25, 45])
                ListTile(
                  title: Text('$m دقیقه'),
                  onTap: () => Navigator.pop(context, m),
                ),
              if (_focusActive)
                TextButton(
                  onPressed: () => Navigator.pop(context, 0),
                  child: const Text('پایان تمرکز'),
                ),
            ],
          ),
        ),
      ),
    );
    if (minutes == null) return;
    _focusTimer?.cancel();
    if (minutes == 0) {
      setState(() {
        _focusActive = false;
        _focusRemainingSec = 0;
        _chromeVisible = true;
      });
      return;
    }
    setState(() {
      _focusActive = true;
      _focusRemainingSec = minutes * 60;
      _chromeVisible = false;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _focusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_focusRemainingSec <= 1) {
        timer.cancel();
        setState(() {
          _focusActive = false;
          _focusRemainingSec = 0;
          _chromeVisible = true;
        });
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('زمان تمرکز به پایان رسید.')),
        );
        return;
      }
      setState(() => _focusRemainingSec--);
    });
  }

  String _formatFocus(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
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
                                        subtitle: _focusActive
                                            ? 'تمرکز ${_formatFocus(_focusRemainingSec)}'
                                            : _isOffline
                                                ? 'آماده برای مطالعهٔ آفلاین'
                                                : 'همگام‌سازی شد',
                                        foreground: _foreground,
                                        bookmarked:
                                            _bookmarks.contains(_chapter),
                                        highlightCount: _highlights.length,
                                        onBack: () =>
                                            Navigator.pop(context, _chapter),
                                        onSearch: _findInBook,
                                        onBookmark: _toggleBookmark,
                                        onHighlights: _showHighlights,
                                        onFocus: _startFocusMode,
                                        onSettings: _openSettings,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            if (_focusActive)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                color: MarefatColors.forest.withValues(
                                  alpha: 0.12,
                                ),
                                child: Text(
                                  'تمرکز · ${_formatFocus(_focusRemainingSec)}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _foreground,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
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
                                  onSelectionChanged: (selection) {
                                    final text = selection?.plainText ?? '';
                                    if (text == _selectedText) return;
                                    setState(() => _selectedText = text);
                                  },
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
                                            EpubHtmlView(
                                              html: current.html.isNotEmpty
                                                  ? current.html
                                                  : '<p>${_escapeHtml(current.body)}</p>',
                                              style: TextStyle(
                                                fontSize: _fontSize,
                                                height: _lineHeight,
                                                color: _foreground,
                                              ),
                                              textAlign: _bodyAlign,
                                              textDirection: _contentDirection,
                                              highlights: _chapterHighlights,
                                              darkHighlights: _theme == 2,
                                            ),
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
                                hasSelection: _selectedText.trim().length >= 2,
                                highlightCount: _chapterHighlights.length,
                                onPrev: () => _setChapter(_chapter - 1),
                                onNext: () => _setChapter(_chapter + 1),
                                onChapter: _setChapter,
                                onHighlight: _addHighlight,
                                onHighlights: _showHighlights,
                                onLookup: _lookupSelection,
                                onQuote: () {
                                  final text = _selectedText.trim();
                                  if (text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'برای کارت نقل‌قول متن را انتخاب کنید.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  showQuoteCardSheet(
                                    context: context,
                                    quote: text,
                                    bookTitle: widget.book.title,
                                    author: widget.book.author,
                                  );
                                },
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
    required this.highlightCount,
    required this.onBack,
    required this.onSearch,
    required this.onBookmark,
    required this.onHighlights,
    required this.onFocus,
    required this.onSettings,
  });

  final String title;
  final String subtitle;
  final Color foreground;
  final bool bookmarked;
  final int highlightCount;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onBookmark;
  final VoidCallback onHighlights;
  final VoidCallback onFocus;
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
            onPressed: onFocus,
            icon: Icon(Icons.timer_outlined, color: foreground),
            tooltip: 'حالت تمرکز',
          ),
          IconButton(
            onPressed: onHighlights,
            tooltip: 'برجسته‌شده‌ها',
            icon: Badge(
              isLabelVisible: highlightCount > 0,
              label: Text(
                '$highlightCount',
                style: const TextStyle(fontSize: 10),
              ),
              child: Icon(Icons.border_color_rounded, color: foreground),
            ),
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
    required this.hasSelection,
    required this.highlightCount,
    required this.onPrev,
    required this.onNext,
    required this.onChapter,
    required this.onHighlight,
    required this.onHighlights,
    required this.onLookup,
    required this.onQuote,
    required this.onContents,
    required this.onFontDown,
    required this.onFontUp,
  });

  final Color foreground;
  final Color background;
  final int chapter;
  final int total;
  final double fontSize;
  final bool hasSelection;
  final int highlightCount;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<int> onChapter;
  final VoidCallback onHighlight;
  final VoidCallback onHighlights;
  final VoidCallback onLookup;
  final VoidCallback onQuote;
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
                    tooltip: hasSelection
                        ? 'برجسته‌سازی انتخاب'
                        : 'ابتدا متن را انتخاب کنید',
                    icon: Icon(
                      Icons.highlight_alt_rounded,
                      color: hasSelection
                          ? MarefatColors.forest
                          : foreground.withValues(alpha: 0.55),
                    ),
                  ),
                  IconButton(
                    onPressed: onLookup,
                    tooltip: 'معنای واژه',
                    icon: Icon(
                      Icons.menu_book_outlined,
                      color: hasSelection
                          ? MarefatColors.forest
                          : foreground.withValues(alpha: 0.55),
                    ),
                  ),
                  IconButton(
                    onPressed: onQuote,
                    tooltip: 'کارت نقل‌قول',
                    icon: Icon(
                      Icons.format_quote_rounded,
                      color: hasSelection
                          ? MarefatColors.brass
                          : foreground.withValues(alpha: 0.55),
                    ),
                  ),
                  IconButton(
                    onPressed: onHighlights,
                    tooltip: 'فهرست برجسته‌شده‌ها',
                    icon: Badge(
                      isLabelVisible: highlightCount > 0,
                      label: Text(
                        '$highlightCount',
                        style: const TextStyle(fontSize: 10),
                      ),
                      child: Icon(
                        Icons.collections_bookmark_rounded,
                        color: foreground,
                      ),
                    ),
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
