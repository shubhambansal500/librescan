import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/scan_page.dart';
import 'crop_screen.dart';

/// Live camera preview with a shutter button and flash toggle. A successful
/// capture hands the raw photo off to [CropScreen]; nothing here mutates the
/// in-progress document session directly.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, required this.onPageCaptured});

  final Future<void> Function(ScanPage page) onPageCaptured;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  CameraController? _controller;
  Future<void>? _initializeFuture;
  FlashMode _flashMode = FlashMode.off;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeFuture = _setUp();
  }

  Future<void> _setUp() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No camera was found on this device.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.setFlashMode(_flashMode);
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (e) {
      setState(() => _error = 'Could not start the camera: $e');
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null) return;
    final next = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await controller.setFlashMode(next);
    setState(() => _flashMode = next);
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      final addedPage = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CropScreen(
            rawImagePath: file.path,
            onPageReady: widget.onPageCaptured,
          ),
        ),
      );
      if (!mounted) return;
      if (addedPage == true) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Capture failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan a page'),
        actions: [
          IconButton(
            icon: Icon(_flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on),
            onPressed: _controller == null ? null : _toggleFlash,
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initializeFuture,
        builder: (context, snapshot) {
          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, style: const TextStyle(color: Colors.white)),
              ),
            );
          }
          final controller = _controller;
          if (controller == null || !controller.value.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              _FullScreenCameraPreview(controller: controller),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: GestureDetector(
                    onTap: _capturing ? null : _capture,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white54, width: 4),
                      ),
                      child: _capturing
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Fills the available space with the camera feed, cropping (not
/// stretching) to match the screen's aspect ratio.
///
/// [CameraPreview] already sizes and rotates itself correctly on its own —
/// its `build()` wraps its texture in the right `AspectRatio` (inverted for
/// portrait) and a `RotatedBox` for the current device orientation. The
/// first version of this widget wrapped `CameraPreview` in a *second*,
/// independently-computed `AspectRatio` to drive the fill/crop math — under
/// `Stack(fit: StackFit.expand)`'s tight constraints that outer wrapper has
/// no freedom to size itself by ratio, so it degenerated to the exact
/// screen box and forced `CameraPreview`'s texture to stretch to match,
/// which is what actually caused the distortion. Fixed by giving
/// `CameraPreview` only `Center`'s *loose* constraints — so its own correct
/// internal sizing genuinely applies — and using a separately-estimated
/// ratio purely as a `Transform.scale` multiplier, which can only ever
/// zoom uniformly and so can't introduce stretching even if the estimate
/// is imperfect.
class _FullScreenCameraPreview extends StatelessWidget {
  const _FullScreenCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        // This screen is locked to portrait (see main.dart), so
        // CameraPreview's own internal logic uses 1/aspectRatio — matching
        // that here only affects how much we zoom, not correctness.
        final estimatedPreviewRatio = 1 / controller.value.aspectRatio;
        var scale = size.aspectRatio / estimatedPreviewRatio;
        if (scale < 1) scale = 1 / scale;
        return ClipRect(
          child: Transform.scale(
            scale: scale,
            child: Center(child: CameraPreview(controller)),
          ),
        );
      },
    );
  }
}
