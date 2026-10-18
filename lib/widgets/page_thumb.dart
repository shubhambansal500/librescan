import 'dart:io';

import 'package:flutter/material.dart';

/// A small page preview card used in page lists/grids (session screen,
/// document viewer thumbnails).
class PageThumb extends StatelessWidget {
  const PageThumb({
    super.key,
    required this.imagePath,
    this.cacheBust,
    this.selected = false,
    this.onTap,
    this.trailing,
  });

  final String imagePath;

  /// Pass the page's `imageRevision` (or similar) here. [imagePath] is
  /// reused across edits (filter change, re-crop) — without a value here
  /// that actually changes when the file's bytes do, Flutter's FileImage
  /// cache (keyed by path alone) keeps showing the pre-edit thumbnail.
  final Object? cacheBust;

  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 0.72,
              child: Image.file(
                File(imagePath),
                key: ValueKey('$imagePath#$cacheBust'),
                fit: BoxFit.cover,
              ),
            ),
            if (trailing != null) Positioned(top: 4, right: 4, child: trailing!),
          ],
        ),
      ),
    );
  }
}
