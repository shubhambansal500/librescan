import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/scan_page.dart';
import '../services/image_processing.dart';
import '../widgets/corner_overlay.dart';

const _uuid = Uuid();

/// Lets the user confirm/adjust the page boundary on a freshly captured (or
/// re-edited) photo, then runs the perspective warp and hands the resulting
/// [ScanPage] to [onPageReady].
///
/// This screen has no opinion on *where* that page goes — the caller
/// decides whether it's a new page being added to an in-progress session or
/// a replacement for a page in an already-saved document. That keeps this
/// screen reusable for both "scan a new page" and "redo crop" flows.
class CropScreen extends StatefulWidget {
  const CropScreen({
    super.key,
    required this.rawImagePath,
    required this.onPageReady,
    this.existingPageId,
    this.initialCorners,
  });

  /// Path to the untouched source photo — always the original capture, even
  /// when re-cropping a page that was already filtered.
  final String rawImagePath;

  final Future<void> Function(ScanPage page) onPageReady;

  /// When re-cropping an existing page, its id (so the result keeps the
  /// same id rather than becoming a new page).
  final String? existingPageId;
  final List<double>? initialCorners;

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  ui.Image? _decoded;
  List<Offset> _corners = const [];
  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.rawImagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      List<Offset> corners;
      final stored = widget.initialCorners;
      if (stored != null && stored.length == 8) {
        corners = [
          Offset(stored[0], stored[1]),
          Offset(stored[2], stored[3]),
          Offset(stored[4], stored[5]),
          Offset(stored[6], stored[7]),
        ];
      } else {
        corners = ImageProcessing.suggestCorners(bytes);
      }

      if (!mounted) return;
      setState(() {
        _decoded = frame.image;
        _corners = corners;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load photo: $e');
    }
  }

  Future<void> _confirm() async {
    final decoded = _decoded;
    if (decoded == null || _processing) return;
    setState(() => _processing = true);
    try {
      final rawBytes = await File(widget.rawImagePath).readAsBytes();
      final warped = ImageProcessing.warpPerspective(rawBytes, _corners);

      final pageId = widget.existingPageId ?? _uuid.v4();
      final tempDir = Directory.systemTemp;
      final warpedPath = '${tempDir.path}/librescan_${pageId}_warped.jpg';
      await File(warpedPath).writeAsBytes(warped, flush: true);

      final page = ScanPage(
        id: pageId,
        originalImagePath: widget.rawImagePath,
        warpedImagePath: warpedPath,
        imagePath: warpedPath,
        corners: _corners.expand((o) => [o.dx, o.dy]).toList(),
      );

      await widget.onPageReady(page);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not process photo: $e';
        _processing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adjust corners'),
        actions: [
          TextButton(
            onPressed: _decoded == null || _processing ? null : _confirm,
            child: _processing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Use photo'),
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
          : _decoded == null
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('Drag the corners to match the page edges.'),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned.fill(
                              child: Image.file(
                                File(widget.rawImagePath),
                                fit: BoxFit.contain,
                              ),
                            ),
                            CornerOverlay(
                              imageSize: Size(
                                _decoded!.width.toDouble(),
                                _decoded!.height.toDouble(),
                              ),
                              initialCorners: _corners,
                              onChanged: (corners) => _corners = corners,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
