import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/scan_document.dart';

/// Builds export artifacts from a [ScanDocument]. Everything here runs
/// locally; nothing is uploaded anywhere.
///
/// v1 ships two honest export shapes rather than a half-working
/// "searchable PDF": an image-based PDF, and the OCR text as plain text.
/// A true searchable PDF needs per-word bounding boxes (hOCR/TSV) to place
/// an invisible text layer in register with the image — the bundled OCR
/// wrapper only exposes plain extracted text today. See README.md
/// "Roadmap" before wiring that up, so the text layer doesn't silently end
/// up misaligned or missing for some pages.
class PdfExporter {
  const PdfExporter._();

  /// Pixels are assumed to have been captured at roughly this density when
  /// computing each PDF page's physical size. It only affects how large the
  /// page looks when printed — not image quality, which is unaffected.
  static const double _assumedCaptureDpi = 150;

  static Future<Uint8List> buildImagePdf(ScanDocument document) async {
    final pdf = pw.Document();

    for (final page in document.pages) {
      final bytes = await File(page.imagePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      final pxWidth = (decoded?.width ?? 1000).toDouble();
      final pxHeight = (decoded?.height ?? 1400).toDouble();

      final pageFormat = PdfPageFormat(
        pxWidth * PdfPageFormat.inch / _assumedCaptureDpi,
        pxHeight * PdfPageFormat.inch / _assumedCaptureDpi,
      );

      final memoryImage = pw.MemoryImage(bytes);
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.Image(memoryImage, fit: pw.BoxFit.fill),
        ),
      );
    }

    return pdf.save();
  }

  /// OCR text for every page, page-separated. Empty if no page has been OCR'd.
  static String combinedText(ScanDocument document) => document.combinedOcrText;
}
