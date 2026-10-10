import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/book.dart';
import '../theme/marefat_theme.dart';
import 'book_cover_card.dart';

Future<void> showBookDetailSheet({
  required BuildContext context,
  required Book book,
  required int progress,
  required int chapterCount,
  required bool isFavorite,
  required VoidCallback onToggleFavorite,
  required VoidCallback onOpen,
  Uint8List? coverBytes,
  List<Book> related = const [],
  ValueChanged<Book>? onOpenRelated,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _BookDetailSheet(
      book: book,
      coverBytes: coverBytes,
      progress: progress,
      chapterCount: chapterCount,
      isFavorite: isFavorite,
      onToggleFavorite: onToggleFavorite,
      onOpen: onOpen,
      related: related,
      onOpenRelated: onOpenRelated,
    ),
  );
}

class _BookDetailSheet extends StatefulWidget {
  const _BookDetailSheet({
    required this.book,
    required this.progress,
    required this.chapterCount,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onOpen,
    this.coverBytes,
    this.related = const [],
    this.onOpenRelated,
  });

  final Book book;
  final Uint8List? coverBytes;
  final int progress;
  final int chapterCount;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onOpen;
  final List<Book> related;
  final ValueChanged<Book>? onOpenRelated;

  @override
  State<_BookDetailSheet> createState() => _BookDetailSheetState();
}

class _BookDetailSheetState extends State<_BookDetailSheet> {
  late bool _favorite = widget.isFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final book = widget.book;
    final progress = widget.progress;
    final chapterCount = widget.chapterCount;
    final total = chapterCount <= 0 ? 1 : chapterCount;
    final ratio = ((progress + 1) / total).clamp(0.0, 1.0);
    final started = progress > 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.only(top: 48),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MarefatColors.mistDeep,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 118,
                      child: BookCoverCard(
                        book: book,
                        coverBytes: widget.coverBytes,
                        onTap: () {},
                        compact: true,
                        progress: progress,
                        chapterCount: chapterCount,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ).animate().fadeIn(duration: 280.ms),
                          const SizedBox(height: 6),
                          Text(
                            book.author,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: MarefatColors.forest,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MetaChip(icon: Icons.category_outlined, label: book.category),
                              _MetaChip(icon: Icons.translate_rounded, label: book.language),
                              if (book.direction == 'ltr')
                                const _MetaChip(
                                  icon: Icons.format_textdirection_l_to_r,
                                  label: 'LTR',
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            started
                                ? 'پیشرفت مطالعه: فصل ${progress + 1} از $total'
                                : 'هنوز شروع نشده',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: MarefatColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: started ? ratio : 0,
                              minHeight: 6,
                              backgroundColor: MarefatColors.mistDeep,
                              color: MarefatColors.forest,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (book.description.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      book.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: MarefatColors.muted,
                        height: 1.7,
                      ),
                    ),
                  ),
                ],
                if (book.translator.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'ترجمه: ${book.translator}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: MarefatColors.brass,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (widget.related.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'کتاب‌های مرتبط',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 108,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.related.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final related = widget.related[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onOpenRelated?.call(related);
                          },
                          child: Container(
                            width: 150,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: MarefatColors.mist.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: MarefatColors.mistDeep),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  related.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  related.category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: MarefatColors.forest,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onOpen();
                        },
                        icon: Icon(
                          started
                              ? Icons.menu_book_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(started ? 'ادامه مطالعه' : 'شروع مطالعه'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      onPressed: () {
                        setState(() => _favorite = !_favorite);
                        widget.onToggleFavorite();
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: _favorite
                            ? const Color(0xFFFFE8E4)
                            : MarefatColors.mistDeep,
                        foregroundColor: _favorite
                            ? const Color(0xFFC45C4A)
                            : MarefatColors.ink,
                      ),
                      icon: Icon(
                        _favorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: MarefatColors.mist.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: MarefatColors.mistDeep),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: MarefatColors.forest),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: MarefatColors.ink,
          ),
        ),
      ],
    ),
  );
}
