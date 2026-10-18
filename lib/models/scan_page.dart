import 'scan_filter.dart';

/// A single scanned page within a [ScanDocument].
///
/// Three image files are tracked per page so filters are always
/// non-destructive and re-croppable:
///  - [originalImagePath]: the raw, un-cropped camera capture.
///  - [warpedImagePath]: that capture after perspective-correction/crop,
///    with no filter applied — the clean base every filter is computed from.
///  - [imagePath]: [warpedImagePath] with [filter] applied; what's shown in
///    previews, OCR'd and exported.
class ScanPage {
  ScanPage({
    required this.id,
    required this.originalImagePath,
    required this.warpedImagePath,
    required this.imagePath,
    this.corners,
    this.filter = ScanFilter.original,
    this.ocrText,
    this.imageRevision = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String originalImagePath;
  String warpedImagePath;
  String imagePath;

  /// Bumped every time [imagePath]'s bytes are rewritten in place (filter
  /// change, re-crop, or re-saving into a document's canonical path) —
  /// fold into any cache key for an `Image.file(File(imagePath))` showing
  /// this page, since Flutter's FileImage cache is keyed by path alone and
  /// won't notice the file's contents changed otherwise.
  int imageRevision;

  /// The four crop corners last used, in source-image pixel coordinates,
  /// ordered top-left, top-right, bottom-right, bottom-left. Stored flat as
  /// `[x0, y0, x1, y1, x2, y2, x3, y3]` for simple JSON round-tripping.
  List<double>? corners;

  ScanFilter filter;
  String? ocrText;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalImagePath': originalImagePath,
        'warpedImagePath': warpedImagePath,
        'imagePath': imagePath,
        'corners': corners,
        'filter': filter.name,
        'ocrText': ocrText,
        'imageRevision': imageRevision,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ScanPage.fromJson(Map<String, dynamic> json) => ScanPage(
        id: json['id'] as String,
        originalImagePath: json['originalImagePath'] as String,
        warpedImagePath: json['warpedImagePath'] as String? ?? json['imagePath'] as String,
        imagePath: json['imagePath'] as String,
        corners: (json['corners'] as List?)?.map((e) => (e as num).toDouble()).toList(),
        filter: ScanFilter.values.firstWhere(
          (f) => f.name == json['filter'],
          orElse: () => ScanFilter.original,
        ),
        ocrText: json['ocrText'] as String?,
        imageRevision: (json['imageRevision'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
