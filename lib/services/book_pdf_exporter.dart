import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/book.dart';
import 'epub_parser.dart';

/// Builds a shareable PDF from an EPUB document.
class BookPdfExporter {
  BookPdfExporter._();

  static Future<Uint8List> build({
    required Book book,
    required EpubDocument document,
    int? maxChapters,
  }) async {
    final rtl = book.direction == 'rtl';
    final baseFont = rtl
        ? await PdfGoogleFonts.notoNaskhArabicRegular()
        : await PdfGoogleFonts.notoSerifRegular();
    final boldFont = rtl
        ? await PdfGoogleFonts.notoNaskhArabicBold()
        : await PdfGoogleFonts.notoSerifBold();

    final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
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
            'معرفت · ${book.title}',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
              font: baseFont,
            ),
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
              font: baseFont,
            ),
          ),
        ),
        build: (context) => [
          pw.Text(
            book.title,
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              font: boldFont,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            book.author,
            style: pw.TextStyle(
              fontSize: 13,
              color: PdfColors.teal800,
              font: baseFont,
            ),
          ),
          if (book.description.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              book.description,
              style: pw.TextStyle(
                fontSize: 11,
                lineSpacing: 4,
                color: PdfColors.grey700,
                font: baseFont,
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
                chapters[i].title.isEmpty
                    ? 'فصل ${i + 1}'
                    : chapters[i].title,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  font: boldFont,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Paragraph(
              text: chapters[i].body.trim().isEmpty
                  ? '—'
                  : chapters[i].body.trim(),
              style: pw.TextStyle(
                fontSize: 11.5,
                lineSpacing: 5,
                font: baseFont,
              ),
            ),
            pw.SizedBox(height: 16),
          ],
        ],
      ),
    );

    return pdf.save();
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
