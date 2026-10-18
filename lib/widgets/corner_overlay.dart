import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A draggable quadrilateral overlay used on the crop screen: four corner
/// handles over the captured photo that the user can drag into place before
/// the perspective warp runs.
///
/// Corner coordinates passed in and reported back via [onChanged] are
/// always in the *source image's pixel space*, regardless of how the image
/// is scaled to fit on screen — callers never need to think about display
/// scaling.
class CornerOverlay extends StatefulWidget {
  const CornerOverlay({
    super.key,
    required this.imageSize,
    required this.initialCorners,
    required this.onChanged,
  });

  final Size imageSize;
  final List<Offset> initialCorners;
  final ValueChanged<List<Offset>> onChanged;

  @override
  State<CornerOverlay> createState() => _CornerOverlayState();
}

class _CornerOverlayState extends State<CornerOverlay> {
  late List<Offset> _corners;

  @override
  void initState() {
    super.initState();
    _corners = List.of(widget.initialCorners);
  }

  double _fitScale(Size image, Size box) {
    final sx = box.width / image.width;
    final sy = box.height / image.height;
    return math.min(sx, sy);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final displaySize = Size(constraints.maxWidth, constraints.maxHeight);
        final scale = _fitScale(widget.imageSize, displaySize);
        final offsetX = (displaySize.width - widget.imageSize.width * scale) / 2;
        final offsetY = (displaySize.height - widget.imageSize.height * scale) / 2;

        Offset toDisplay(Offset p) =>
            Offset(p.dx * scale + offsetX, p.dy * scale + offsetY);
        Offset toImage(Offset p) =>
            Offset((p.dx - offsetX) / scale, (p.dy - offsetY) / scale);

        final displayCorners = _corners.map(toDisplay).toList();

        return Stack(
          children: [
            CustomPaint(
              size: displaySize,
              painter: _QuadPainter(displayCorners, Theme.of(context).colorScheme.primary),
            ),
            for (var i = 0; i < _corners.length; i++)
              Positioned(
                left: displayCorners[i].dx - 16,
                top: displayCorners[i].dy - 16,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      final moved = toDisplay(_corners[i]) + details.delta;
                      final clampedDisplay = Offset(
                        moved.dx.clamp(0, displaySize.width),
                        moved.dy.clamp(0, displaySize.height),
                      );
                      _corners[i] = toImage(clampedDisplay);
                    });
                    widget.onChanged(_corners);
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuadPainter extends CustomPainter {
  _QuadPainter(this.points, this.color);

  final List<Offset> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 4) return;
    final path = Path()..addPolygon(points, true);
    canvas.drawPath(path, Paint()..color = color.withAlpha(51)); // ~0.2 alpha, broadly SDK-compatible
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _QuadPainter oldDelegate) =>
      oldDelegate.points != points;
}
