import 'dart:io';

import 'package:flutter/widgets.dart';

/// Flutter's [FileImage] cache is keyed by file path, not file contents —
/// overwriting a file in place (crop, filter, redo-crop all do this, to
/// avoid piling up a new file per edit) leaves every `Image.file` for that
/// path showing the stale bytes until the cache entry is evicted. Call this
/// right after writing new bytes to a path that may already be on-screen.
Future<void> evictImageFileCache(String path) {
  return FileImage(File(path)).evict();
}
