# LibreScan

[![CI](https://github.com/shubhambansal500/librescan/actions/workflows/ci.yml/badge.svg)](https://github.com/shubhambansal500/librescan/actions/workflows/ci.yml)

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

## Known build gotcha: `compileSdk 37` platform lookup

If `flutter build apk` fails with `Failed to find target with hash string
'android-37' in: <sdk>` even after `sdkmanager` reports `platforms;android-37.0`
installed: Android's SDK platform packages have moved to dotted version IDs
(`android-37.0`, `37.1`, ...), but a plain integer `compileSdk 37` (set in
`android/app/build.gradle.kts` — needed because `permission_handler_android`
requires SDK 37+) looks for a literal `android-37` folder, which no package
currently installs. Confirmed by actually hitting this while building the
project. Fix: make a local alias so the SDK has what the lookup expects —

```bash
cd "$ANDROID_HOME/platforms"
cp -r android-37.0 android-37
sed -i '' 's/AndroidVersion.ApiLevel=37.0/AndroidVersion.ApiLevel=37/' android-37/source.properties
```

This is a local SDK-installation workaround, not a repo file, so every
machine that builds this project needs it until Google ships a plain
`platforms;android-37` package (or `permission_handler_android` caps its
own requirement back down).

## Vendored dependencies

`third_party/tesseract_ocr_patched/` is a vendored, patched copy of the
[`tesseract_ocr`](https://pub.dev/packages/tesseract_ocr) package (BSD-3,
original license preserved in that folder). Its published 0.5.0 release
fails to build on current Gradle/AGP for two independent reasons — both
found and fixed by actually building this project, not guessed at:

- `android/build.gradle` called the removed `jcenter()` repository method
  (removed; the one native dependency it pulls in, `tesseract4android`,
  already resolves from the `jitpack.io` repo listed alongside it), and
  separately declared its own `buildscript { classpath '...gradle:8.2.1' }`
  (removed; the root project's `settings.gradle.kts` already supplies AGP/
  Kotlin to every module — this stale, pre-centralized-plugin-management
  block was pulling in a second, unresolvable copy of AGP's whole dependency
  graph). Also pinned a consistent Java/Kotlin JVM target (17), needed once
  the above was fixed.
- The package shipped both a real, working `TesseractOcrPlugin.java` (the
  actual `TessBaseAPI` glue) *and* a stale, non-functional Kotlin plugin-
  template stub declaring the same class — a leftover from an unfinished
  Java→Kotlin migration, and a straight compile error (`Redeclaration`) with
  both present. The stub is deleted; the working Java file is untouched.

If upstream publishes a fixed release, switch `pubspec.yaml`'s
`tesseract_ocr` entry back to a normal hosted version constraint and delete
this folder.

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

Nothing in `lib/` performs HTTP/socket I/O — everything is local file and
camera access. The release build requests no network permission at all
(verified with `aapt dump badging` on a real `flutter build apk --release`
output: just `CAMERA`, `READ_EXTERNAL_STORAGE`, and a capped legacy
`WRITE_EXTERNAL_STORAGE`). A *debug* build does show `INTERNET` — that's
Flutter's own tooling adding it for hot reload/DevTools, not anything this
app does; it disappears in release builds.

## App icon

The launcher icon source lives in `assets/icon/` (`icon_master.png` for iOS
and Android's legacy icon, `icon_foreground.png` for Android's adaptive
icon, paired with the `#3949AB` background set in `pubspec.yaml`). Regenerate
every platform icon file from those two sources with:

```bash
dart run flutter_launcher_icons
```

Edit the source PNGs (or swap in your own) and re-run that command rather
than hand-editing anything under `android/.../mipmap-*` or
`ios/.../AppIcon.appiconset` — those are generated output.

## Release signing

Release builds are signed with the debug key until you generate a real
upload keystore — fine for sideloading, not for publishing. To set one up:

```bash
cd android
keytool -genkeypair -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
cat > key.properties <<EOF
storePassword=<the password you just set>
keyPassword=<the same password>
keyAlias=upload
storeFile=upload-keystore.jks
EOF
```

`android/key.properties` and `android/*.jks` are gitignored — never commit
either. Back the `.jks` file and its password up somewhere durable (a
password manager, not just this machine) before you ever publish: losing it
means you can never ship an update to the same app listing again. Once both
files exist, `flutter build apk --release` (or `--release` of any kind)
automatically signs with them instead of the debug key — no other change
needed. `android/app/build.gradle.kts` falls back to debug signing
automatically when `key.properties` is absent, so the repo stays buildable
for anyone who clones it without your key.

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
