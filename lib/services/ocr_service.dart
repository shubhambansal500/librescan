import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

/// Thin wrapper around the bundled, fully offline Tesseract OCR engine.
///
/// No network calls are made; recognition runs entirely on-device using the
/// trained-data files bundled under `assets/tessdata/` (see pubspec.yaml).
class OcrService {
  const OcrService._();

  /// Languages whose `.traineddata` file ships in `assets/tessdata/`.
  /// Extend this (and add the matching asset) to support more languages —
  /// see README.md "Adding OCR languages".
  static const List<String> bundledLanguages = ['eng'];

  static Future<String> recognizeText(
    String imagePath, {
    String language = 'eng',
  }) async {
    final text = await FlutterTesseractOcr.extractText(
      imagePath,
      language: language,
      args: {
        'psm': '4', // assume a single column of text of variable sizes
        'preserve_interword_spaces': '1',
      },
    );
    return text.trim();
  }
}
