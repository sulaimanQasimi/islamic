import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/marefat_theme.dart';

Future<void> showQuoteCardSheet({
  required BuildContext context,
  required String quote,
  required String bookTitle,
  String? author,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _QuoteCardSheet(
      quote: quote.trim(),
      bookTitle: bookTitle,
      author: author,
    ),
  );
}

class _QuoteCardSheet extends StatelessWidget {
  const _QuoteCardSheet({
    required this.quote,
    required this.bookTitle,
    this.author,
  });

  final String quote;
  final String bookTitle;
  final String? author;

  @override
  Widget build(BuildContext context) {
    final shareText = '"$quote"\n— $bookTitle'
        '${author != null && author!.isNotEmpty ? ' · $author' : ''}\nمعرفت';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Color(0xFF0D2A26),
                    Color(0xFF1A5C4E),
                    Color(0xFF2A6B4E),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'معرفت',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFD4B978),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    quote,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFF7F4EC),
                      fontSize: 18,
                      height: 1.85,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    bookTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (author != null && author!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      author!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: shareText));
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('کارت نقل‌قول در کلیپ‌بورد کپی شد.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('کپی برای اشتراک'),
              style: FilledButton.styleFrom(
                backgroundColor: MarefatColors.forest,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('بستن'),
            ),
          ],
        ),
      ),
    );
  }
}
