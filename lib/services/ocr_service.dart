import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';

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
    final text = await TesseractOcr.extractText(
      imagePath,
      config: OCRConfig(language: language, engine: OCREngine.tesseract),
    );
    return text.trim();
  }
}
