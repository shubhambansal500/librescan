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
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String originalImagePath;
  String warpedImagePath;
  String imagePath;

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
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
