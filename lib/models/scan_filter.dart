/// Visual treatment applied to a captured page.
///
/// Kept as a tiny enum (rather than free-form strings) so persisted
/// documents stay forward-compatible: new filters can be appended without
/// breaking [ScanFilter.values[index]] lookups for already-saved pages.
enum ScanFilter {
  original,
  grayscale,
  blackAndWhite,
  enhanced;

  String get label {
    switch (this) {
      case ScanFilter.original:
        return 'Original';
      case ScanFilter.grayscale:
        return 'Grayscale';
      case ScanFilter.blackAndWhite:
        return 'Black & white';
      case ScanFilter.enhanced:
        return 'Enhanced';
    }
  }
}
