import 'package:flutter/foundation.dart';

import '../models/scan_document.dart';
import '../models/scan_page.dart';
import 'document_store.dart';

/// Backs the home-screen library list: the set of already-saved documents.
class DocumentLibrary extends ChangeNotifier {
  DocumentLibrary(this._store) {
    refresh();
  }

  final DocumentStore _store;

  List<ScanDocument> documents = [];
  bool loading = true;

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    documents = await _store.listDocuments();
    loading = false;
    notifyListeners();
  }

  Future<void> save(ScanDocument document) async {
    await _store.save(document);
    await refresh();
  }

  /// Persists an in-progress capture session's pages as a brand-new
  /// document, copying their temp-file images into permanent storage.
  Future<ScanDocument> commitSession(List<ScanPage> pages, String title) async {
    final document = await _store.commitSession(pages, title);
    await refresh();
    return document;
  }

  Future<void> delete(String documentId) async {
    await _store.delete(documentId);
    await refresh();
  }
}
