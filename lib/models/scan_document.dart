import 'scan_page.dart';

/// A multi-page scanned document, persisted as its own JSON file inside the
/// document's storage folder (see `DocumentStore`).
class ScanDocument {
  ScanDocument({
    required this.id,
    required this.title,
    required this.pages,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  final List<ScanPage> pages;
  final DateTime createdAt;
  DateTime updatedAt;

  /// Combined OCR text of every page, in page order, separated by a form
  /// feed so a plain-text export keeps page boundaries unambiguous.
  String get combinedOcrText => pages
      .map((p) => p.ocrText ?? '')
      .where((t) => t.trim().isNotEmpty)
      .join('\n\n\x0C\n\n');

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'pages': pages.map((p) => p.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ScanDocument.fromJson(Map<String, dynamic> json) => ScanDocument(
        id: json['id'] as String,
        title: json['title'] as String,
        pages: (json['pages'] as List)
            .map((p) => ScanPage.fromJson(p as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
