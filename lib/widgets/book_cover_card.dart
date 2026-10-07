import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/book.dart';
import '../theme/marefat_theme.dart';

class BookCoverCard extends StatelessWidget {
  const BookCoverCard({
    super.key,
    required this.book,
    required this.onTap,
    this.progress = 0,
    this.chapterCount = 1,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.index = 0,
    this.compact = false,
  });

  final Book book;
  final VoidCallback onTap;
  final int progress;
  final int chapterCount;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final int index;
  final bool compact;

  double get _progressRatio {
    final total = chapterCount <= 0 ? 1 : chapterCount;
    return ((progress + 1) / total).clamp(0.0, 1.0);
  }

  bool get _hasStarted => progress > 0;

  @override
  Widget build(BuildContext context) {
    final gold = MarefatColors.brassSoft;
    final darkGold = MarefatColors.brass;

    return Animate(
      delay: (40 * index).ms,
      effects: [
        FadeEffect(duration: 380.ms, curve: Curves.easeOut),
        SlideEffect(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
          duration: 420.ms,
          curve: Curves.easeOutCubic,
        ),
      ],
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: book.color.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: AspectRatio(
              aspectRatio: compact ? 0.72 : 0.68,
              child: Hero(
                tag: 'cover_${book.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [
                              book.color,
                              Color.lerp(book.color, Colors.black, 0.45)!,
                              Color.lerp(book.color, const Color(0xFF0A1A18), 0.65)!,
                            ],
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: gold.withValues(alpha: 0.75),
                              width: 1.4,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          margin: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: darkGold.withValues(alpha: 0.45),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: 16,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerRight,
                              end: Alignment.centerLeft,
                              colors: [
                                Colors.black.withValues(alpha: 0.45),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 18,
                        left: 18,
                        right: 18,
                        height: 46,
                        child: CustomPaint(
                          painter: ArchOrnamentPainter(
                            color: gold.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 28, 18, 18),
                        child: Column(
                          children: [
                            const Spacer(flex: 2),
                            Text(
                              book.title,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFFFF6DF),
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                height: 1.35,
                                shadows: [
                                  Shadow(
                                    color: Colors.black87,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: gold.withValues(alpha: 0.4),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  child: Icon(
                                    book.icon,
                                    size: 13,
                                    color: gold.withValues(alpha: 0.85),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: gold.withValues(alpha: 0.4),
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
                                color: gold.withValues(alpha: 0.92),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            if (_hasStarted && chapterCount > 0)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: _progressRatio,
                                  minHeight: 3,
                                  backgroundColor: Colors.white24,
                                  color: gold,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (onFavoriteToggle != null)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.28),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: onFavoriteToggle,
                              child: Padding(
                                padding: const EdgeInsets.all(7),
                                child: Icon(
                                  isFavorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 16,
                                  color: isFavorite
                                      ? const Color(0xFFFFB4A8)
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (book.featured)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: MarefatColors.brass.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'برگزیده',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
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

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.45)
      ..cubicTo(
        size.width * 0.15,
        size.height * 0.4,
        size.width * 0.35,
        size.height * 0.05,
        size.width * 0.5,
        0,
      )
      ..cubicTo(
        size.width * 0.65,
        size.height * 0.05,
        size.width * 0.85,
        size.height * 0.4,
        size.width,
        size.height * 0.45,
      )
      ..lineTo(size.width, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ArchOrnamentPainter oldDelegate) =>
      oldDelegate.color != color;
}
