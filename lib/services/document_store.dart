import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/scan_document.dart';
import '../models/scan_page.dart';
import '../utils/image_file_cache.dart';

const _uuid = Uuid();

/// Local-only persistence for scanned documents.
///
/// Layout on disk (under the app's documents directory):
///   librescan/
///     `<documentId>`/
///       document.json   — the ScanDocument, including page metadata
///       `<pageId>`_orig.jpg
///       `<pageId>`.jpg     — current cropped + filtered render
///
/// There is no database, no cloud sync and no network access anywhere in
/// this class — everything lives in the app's own sandboxed storage, so
/// uninstalling the app removes everything it ever wrote.
class DocumentStore {
  DocumentStore._(this._root);

  final Directory _root;

  static DocumentStore? _instance;

  static Future<DocumentStore> instance() async {
    if (_instance != null) return _instance!;
    final docsDir = await getApplicationDocumentsDirectory();
    final root = Directory('${docsDir.path}/librescan');
    await root.create(recursive: true);
    _instance = DocumentStore._(root);
    return _instance!;
  }

  Directory folderFor(String documentId) => Directory('${_root.path}/$documentId');

  Future<Directory> ensureFolder(String documentId) async {
    final dir = folderFor(documentId);
    await dir.create(recursive: true);
    return dir;
  }

  Future<List<ScanDocument>> listDocuments() async {
    if (!await _root.exists()) return [];
    final docs = <ScanDocument>[];
    for (final entry in _root.listSync()) {
      if (entry is! Directory) continue;
      final file = File('${entry.path}/document.json');
      if (!await file.exists()) continue;
      try {
        final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        docs.add(ScanDocument.fromJson(json));
      } catch (_) {
        // Skip a corrupted/partially-written document rather than failing
        // the whole library listing.
        continue;
      }
    }
    docs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return docs;
  }

  Future<void> save(ScanDocument document) async {
    document.updatedAt = DateTime.now();
    final dir = await ensureFolder(document.id);
    final file = File('${dir.path}/document.json');
    await file.writeAsString(jsonEncode(document.toJson()));
  }

  Future<void> delete(String documentId) async {
    final dir = folderFor(documentId);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  String pagePath(String documentId, String pageId, {bool original = false}) {
    final suffix = original ? '_orig.jpg' : '.jpg';
    return '${folderFor(documentId).path}/$pageId$suffix';
  }

  String warpedPagePath(String documentId, String pageId) =>
      '${folderFor(documentId).path}/${pageId}_warped.jpg';

  /// Ensures [page]'s image files live inside [documentId]'s own storage
  /// folder, copying them out of wherever they currently are (typically a
  /// temp file written by the crop screen) if needed, and returns a page
  /// with the corrected paths. Safe to call repeatedly / on a page whose
  /// files are already in place — those paths are left untouched.
  Future<ScanPage> relocatePage(String documentId, ScanPage page) async {
    await ensureFolder(documentId);
    final targetOriginal = pagePath(documentId, page.id, original: true);
    final targetWarped = warpedPagePath(documentId, page.id);
    final targetImage = pagePath(documentId, page.id);

    Future<String> relocate(String src, String dst) async {
      if (src == dst) return dst;
      await File(src).copy(dst);
      // dst (the document's canonical page path) is reused across edits —
      // a page that's already been saved and then re-filtered/re-cropped
      // copies back onto the same dst each time. Without evicting, any
      // Image.file already showing that path keeps the pre-edit bytes.
      await evictImageFileCache(dst);
      return dst;
    }

    final newOriginal = await relocate(page.originalImagePath, targetOriginal);
    final newWarped = await relocate(page.warpedImagePath, targetWarped);
    // imagePath may currently equal warpedImagePath (no filter applied yet)
    // or point at a separately-filtered file.
    final newImage = page.imagePath == page.warpedImagePath
        ? newWarped
        : await relocate(page.imagePath, targetImage);

    return ScanPage(
      id: page.id,
      originalImagePath: newOriginal,
      warpedImagePath: newWarped,
      imagePath: newImage,
      corners: page.corners,
      filter: page.filter,
      ocrText: page.ocrText,
      imageRevision: page.imageRevision + 1,
      createdAt: page.createdAt,
    );
  }

  /// Turns an in-progress [DocumentSession]'s pages into a persisted
  /// [ScanDocument]: creates the document's folder, relocates every page's
  /// images into it, and saves `document.json`.
  Future<ScanDocument> commitSession(List<ScanPage> pages, String title) async {
    final documentId = _uuid.v4();
    await ensureFolder(documentId);

    final committedPages = <ScanPage>[];
    for (final page in pages) {
      committedPages.add(await relocatePage(documentId, page));
    }

    final document = ScanDocument(id: documentId, title: title, pages: committedPages);
    await save(document);
    return document;
  }
}
