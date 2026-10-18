import 'dart:io';

import 'package:flutter/material.dart';

/// A small page preview card used in page lists/grids (session screen,
/// document viewer thumbnails).
class PageThumb extends StatelessWidget {
  const PageThumb({
    super.key,
    required this.imagePath,
    this.selected = false,
    this.onTap,
    this.trailing,
  });

  final String imagePath;
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
              child: Image.file(File(imagePath), fit: BoxFit.cover),
            ),
            if (trailing != null) Positioned(top: 4, right: 4, child: trailing!),
          ],
        ),
      ),
    );
  }
}
