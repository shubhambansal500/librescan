# LibreScan

A free, open-source, offline document scanner for Android and iOS — capture,
crop, enhance and OCR documents from your phone's camera, then export to PDF
or text. No account, no cloud sync, no ads, no analytics. MIT licensed, free
to use, modify and redistribute.

> LibreScan is an independent, original implementation. It was *not* built
> by decompiling or copying any commercial scanner app's code. It aims to
> cover the same general feature set (camera capture → crop/deskew → filter
> → OCR → PDF) using openly documented, standard techniques.

## Features

- Camera capture with flash toggle
- Page-boundary suggestion + draggable corner adjustment, then perspective
  warp ("deskew") to a flat rectangular page
- Filters: Original, Grayscale, Black & white (Otsu threshold), Enhanced
- Multi-page documents: add, reorder, delete and re-crop pages
- Fully offline OCR (bundled Tesseract — English included; see below for
  adding more languages)
- Export a document as an image-based PDF, or share its OCR'd text
- A local-only document library — everything lives in the app's own
  sandboxed storage; uninstalling the app removes everything it ever wrote

## Why it looks the way it does

This is a from-scratch v1, not a port of an existing app, and it makes a few
explicit tradeoffs favoring reliability and buildability over matching every
feature of a mature commercial scanner on day one:

- **Edge detection is pure Dart, not full computer vision.** Rather than
  depend on a native/FFI OpenCV binding (build-fragile across Flutter
  versions and platforms), `lib/services/image_processing.dart` uses a
  Sobel-gradient heuristic to *suggest* an axis-aligned crop box, then always
  lets the user drag all four corners to correct perspective/skew by hand.
  Swapping in a real contour-based detector (e.g. the `opencv_dart` package)
  behind `ImageProcessing.suggestCorners` is the natural next step; see
  Roadmap.
- **No "searchable PDF" yet.** A true searchable PDF needs per-word
  bounding boxes (hOCR/TSV) to place an invisible text layer in register
  with the page image. The bundled OCR wrapper only exposes plain extracted
  text today, so v1 ships two honest exports instead: an image PDF, and the
  recognized text as its own share sheet. See Roadmap.

## Getting started

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(stable channel) and, for native builds, Android Studio (Android) and/or
Xcode + CocoaPods (iOS).

```bash
flutter pub get
flutter run            # pick a connected device/emulator
```

Build release artifacts:

```bash
flutter build apk --release     # Android
flutter build ios --release     # iOS (needs Xcode + a signing team)
```

### Verifying without a device

```bash
flutter analyze   # static analysis
flutter test       # unit tests for the crop/filter/OCR math in image_processing.dart
```

## Adding OCR languages

1. Download the language's `.traineddata` file from
   [tesseract-ocr/tessdata_fast](https://github.com/tesseract-ocr/tessdata_fast)
   (Apache-2.0).
2. Drop it into `assets/tessdata/`.
3. Add its filename to `tessdata_config.json`'s `files` list (see the
   `flutter_tesseract_ocr` package docs).
4. Pass `language: 'xxx'` (the Tesseract language code, e.g. `'fra'`, or
   `'eng+fra'` for multiple) to `OcrService.recognizeText`.

## Architecture

```
lib/
  models/      ScanDocument, ScanPage, ScanFilter — plain data + JSON (de)serialization
  services/    DocumentStore (on-disk persistence), DocumentSession/DocumentLibrary
               (ChangeNotifier controllers), ImageProcessing (perspective warp,
               filters, edge hints — pure Dart, unit tested), OcrService, PdfExporter
  screens/     One screen per step: capture → crop → session (page list) →
               page detail (filter/OCR/redo-crop) → document viewer (saved docs)
  widgets/     CornerOverlay (draggable crop handles), PageThumb
```

Every screen that edits a page takes plain callbacks (`onUpdated`,
`onDeleted`, `onPageReady`) rather than reaching into a specific controller,
so the same screens work whether a page belongs to an in-progress session or
an already-saved document.

No network permissions are requested anywhere in the app, and nothing in
`lib/` performs HTTP/socket I/O — everything is local file and camera access.

## Roadmap

- Swap `ImageProcessing.suggestCorners`'s heuristic for a real contour-based
  detector (`opencv_dart`) for skewed/rotated source photos.
- Searchable PDF: switch to an OCR path that exposes per-word bounding boxes
  (hOCR/TSV) and overlay invisible positioned text in `PdfExporter`.
- Batch/continuous capture (auto-advance to the next page without leaving
  the camera screen).
- A document-text search box on the home screen, backed by each page's
  already-extracted `ocrText`.

## License

MIT — see [LICENSE](LICENSE). Tesseract trained-data files bundled under
`assets/tessdata/` are from
[tesseract-ocr/tessdata_fast](https://github.com/tesseract-ocr/tessdata_fast),
Apache License 2.0.

## Responsible use

Scan documents you own or are authorized to digitize. LibreScan doesn't
enforce or check this — like a flatbed scanner, what you do with it is on
you.
