import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/book.dart';
import 'epub_parser.dart';

/// Builds a shareable PDF from an EPUB document without images.
class BookPdfExporter {
  BookPdfExporter._();

  static Future<Uint8List> build({
    required Book book,
    required EpubDocument document,
    int? maxChapters,
  }) async {
    final rtl = book.direction == 'rtl';

    // Load fonts and cross-script fallbacks to avoid missing glyph errors
    final arabicRegular = await PdfGoogleFonts.notoNaskhArabicRegular();
    final arabicBold = await PdfGoogleFonts.notoNaskhArabicBold();
    final latinRegular = await PdfGoogleFonts.notoSerifRegular();
    final latinBold = await PdfGoogleFonts.notoSerifBold();

    final baseFont = rtl ? arabicRegular : latinRegular;
    final boldFont = rtl ? arabicBold : latinBold;
    final fallbackFont = rtl ? latinRegular : arabicRegular;

    final theme = pw.ThemeData.withFont(
      base: baseFont,
      bold: boldFont,
      fontFallback: [fallbackFont],
    );

    final pdf = pw.Document(theme: theme);
    final chapters = maxChapters == null
        ? document.chapters
        : document.chapters.take(maxChapters).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Container(
          alignment: rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          margin: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Text(
            rtl ? 'معرفت · ${book.title}' : 'Marefat · ${book.title}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
        ),
        build: (context) => [
          pw.Text(
            book.title,
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            book.author,
            style: const pw.TextStyle(
              fontSize: 13,
              color: PdfColors.teal800,
            ),
          ),
          if (book.description.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              book.description,
              style: const pw.TextStyle(
                fontSize: 11,
                lineSpacing: 4,
                color: PdfColors.grey700,
              ),
            ),
          ],
          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 12),
          for (var i = 0; i < chapters.length; i++) ...[
            pw.Header(
              level: 1,
              child: pw.Text(
                chapters[i].title.trim().isEmpty
                    ? (rtl ? 'فصل ${i + 1}' : 'Chapter ${i + 1}')
                    : chapters[i].title,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            // Strips HTML/image tags and splits text to prevent layout overflow
            ..._buildTextParagraphs(chapters[i].body),
            pw.SizedBox(height: 16),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  /// Removes any inline images, HTML tags, or Markdown image references,
  /// then splits the clean content into individual pw.Paragraph elements.
  static List<pw.Widget> _buildTextParagraphs(String body) {
    if (body.trim().isEmpty) {
      return [pw.Paragraph(text: '—')];
    }

    // Strip HTML <img> tags
    var sanitized = body.replaceAll(
      RegExp(r'<img[^>]*>', caseSensitive: false),
      '',
    );

    // Strip Markdown images: ![alt](url)
    sanitized = sanitized.replaceAll(
      RegExp(r'!\[.*?\]\(.*?\)', caseSensitive: false),
      '',
    );

    // Strip remaining common HTML formatting tags from EPUB body text
    sanitized = sanitized.replaceAll(RegExp(r'</?(p|div|span|br|b|i|em|strong)[^>]*>', caseSensitive: false), '\n');

    final paragraphs = sanitized
        .split(RegExp(r'\r?\n+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (paragraphs.isEmpty) {
      return [pw.Paragraph(text: '—')];
    }

    return paragraphs
        .map(
          (text) => pw.Paragraph(
            text: text,
            style: const pw.TextStyle(
              fontSize: 11.5,
              lineSpacing: 5,
            ),
          ),
        )
        .toList();
  }

  static String fileNameFor(Book book) {
    final base = book.title
        .trim()
        .replaceAll(RegExp(r'[^\w\s\-\u0600-\u06FF]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final safe = base.isEmpty ? book.id : base;
    return 'Marefat_${safe}.pdf';
  }
}