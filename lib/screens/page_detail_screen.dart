import 'dart:io';

import 'package:flutter/material.dart';

import '../models/scan_filter.dart';
import '../models/scan_page.dart';
import '../services/image_processing.dart';
import '../services/ocr_service.dart';
import '../utils/image_file_cache.dart';
import 'crop_screen.dart';

/// Per-page editing: pick a filter, re-run the crop, run OCR and view/copy
/// its text, or delete the page.
///
/// Deliberately takes plain callbacks ([onUpdated], [onDeleted]) instead of
/// reaching into a specific controller, so it works the same whether the
/// page belongs to an in-progress [DocumentSession] or an already-saved
/// document being revisited from the library.
class PageDetailScreen extends StatefulWidget {
  const PageDetailScreen({
    super.key,
    required this.page,
    required this.onUpdated,
    required this.onDeleted,
  });

  final ScanPage page;
  final Future<void> Function(ScanPage updated) onUpdated;
  final Future<void> Function() onDeleted;

  @override
  State<PageDetailScreen> createState() => _PageDetailScreenState();
}

class _PageDetailScreenState extends State<PageDetailScreen> {
  late ScanPage _page;
  bool _busyFilter = false;
  bool _busyOcr = false;

  @override
  void initState() {
    super.initState();
    _page = widget.page;
  }

  Future<void> _applyFilter(ScanFilter filter) async {
    if (_busyFilter || _page.filter == filter) return;
    setState(() => _busyFilter = true);
    try {
      final baseBytes = await File(_page.warpedImagePath).readAsBytes();
      final filtered = ImageProcessing.applyFilter(baseBytes, filter);
      // Overwrite the page's current rendered image in place; warpedImagePath
      // (the unfiltered base) is left untouched so filters stay reversible.
      await File(_page.imagePath).writeAsBytes(filtered, flush: true);
      // Flutter's FileImage cache is keyed by path, not contents — without
      // this, every Image.file for this path (here and any thumbnail
      // elsewhere) keeps showing the pre-filter bytes.
      await evictImageFileCache(_page.imagePath);
      setState(() {
        _page.filter = filter;
        _page.imageRevision++;
      });
      await widget.onUpdated(_page);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not apply filter: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyFilter = false);
    }
  }

  Future<void> _runOcr() async {
    if (_busyOcr) return;
    setState(() => _busyOcr = true);
    try {
      final text = await OcrService.recognizeText(_page.imagePath);
      setState(() => _page.ocrText = text);
      await widget.onUpdated(_page);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyOcr = false);
    }
  }

  Future<void> _redoCrop() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CropScreen(
          rawImagePath: _page.originalImagePath,
          existingPageId: _page.id,
          initialCorners: _page.corners,
          previousImageRevision: _page.imageRevision,
          onPageReady: (updated) async {
            // A re-crop resets the filter to Original: it re-derives a
            // fresh warpedImagePath, and any previous filtered render no
            // longer applies to it.
            setState(() => _page = updated);
            await widget.onUpdated(updated);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Page'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await widget.onDeleted();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      // Android (targeting SDK 35+) draws edge-to-edge by default now — a
      // Scaffold body is no longer automatically padded clear of the system
      // nav bar, so fixed bottom controls need an explicit SafeArea or they
      // render partly behind it.
      body: SafeArea(
        child: Column(
          children: [
          Expanded(
            child: InteractiveViewer(
              child: Center(
                child: Image.file(
                  File(_page.imagePath),
                  key: ValueKey('${_page.imagePath}#${_page.imageRevision}'),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final filter in ScanFilter.values)
                  ChoiceChip(
                    label: Text(filter.label),
                    selected: _page.filter == filter,
                    onSelected: _busyFilter ? null : (_) => _applyFilter(filter),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _redoCrop,
                    icon: const Icon(Icons.crop),
                    label: const Text('Redo crop'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busyOcr ? null : _runOcr,
                    icon: _busyOcr
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.text_fields),
                    label: Text(_page.ocrText == null ? 'Run OCR' : 'Re-run OCR'),
                  ),
                ),
              ],
            ),
          ),
          if (_page.ocrText != null && _page.ocrText!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _page.ocrText!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
