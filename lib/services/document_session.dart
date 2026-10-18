import 'package:flutter/foundation.dart';

import '../models/scan_page.dart';

/// Holds the pages captured so far for a document that hasn't been saved
/// yet. Cleared once the user finishes and the pages are handed off to a
/// [ScanDocument] and persisted via `DocumentStore`.
class DocumentSession extends ChangeNotifier {
  final List<ScanPage> _pages = [];

  List<ScanPage> get pages => List.unmodifiable(_pages);
  bool get isEmpty => _pages.isEmpty;
  int get pageCount => _pages.length;

  void addPage(ScanPage page) {
    _pages.add(page);
    notifyListeners();
  }

  void replacePage(ScanPage updated) {
    final index = _pages.indexWhere((p) => p.id == updated.id);
    if (index == -1) return;
    _pages[index] = updated;
    notifyListeners();
  }

  void removePage(String pageId) {
    _pages.removeWhere((p) => p.id == pageId);
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final page = _pages.removeAt(oldIndex);
    _pages.insert(newIndex, page);
    notifyListeners();
  }

  void clear() {
    _pages.clear();
    notifyListeners();
  }
}
