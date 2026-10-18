import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/scan_document.dart';
import '../services/document_library.dart';
import '../services/document_store.dart';
import '../services/pdf_exporter.dart';
import 'capture_screen.dart';
import 'page_detail_screen.dart';

/// Views a saved document's pages, with export/share and page-management
/// actions. Looks the document up by id each time it needs it (rather than
/// holding a stale copy) so edits made via [PageDetailScreen] are always
/// reflected after returning here.
class DocumentViewerScreen extends StatefulWidget {
  const DocumentViewerScreen({super.key, required this.documentId});

  final String documentId;

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  final _pageController = PageController();
  bool _exporting = false;

  ScanDocument? _documentFrom(DocumentLibrary library) {
    for (final doc in library.documents) {
      if (doc.id == widget.documentId) return doc;
    }
    return null;
  }

  Future<void> _addPage(BuildContext context, ScanDocument document) async {
    final library = context.read<DocumentLibrary>();
    final store = await DocumentStore.instance();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaptureScreen(
          onPageCaptured: (page) async {
            final relocated = await store.relocatePage(document.id, page);
            document.pages.add(relocated);
            await library.save(document);
          },
        ),
      ),
    );
  }

  Future<void> _editPage(BuildContext context, ScanDocument document, int index) async {
    final library = context.read<DocumentLibrary>();
    final store = await DocumentStore.instance();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PageDetailScreen(
          page: document.pages[index],
          onUpdated: (updated) async {
            final relocated = await store.relocatePage(document.id, updated);
            document.pages[index] = relocated;
            await library.save(document);
          },
          onDeleted: () async {
            document.pages.removeAt(index);
            await library.save(document);
          },
        ),
      ),
    );
    setState(() {}); // reflect any edits made while this route was pushed
  }

  Future<void> _exportPdf(ScanDocument document) async {
    setState(() => _exporting = true);
    try {
      final bytes = await PdfExporter.buildImagePdf(document);
      await Printing.sharePdf(bytes: bytes, filename: '${document.title}.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareText(ScanDocument document) async {
    final text = PdfExporter.combinedText(document);
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No OCR text yet — run OCR on a page first.')),
      );
      return;
    }
    await SharePlus.instance.share(ShareParams(text: text, subject: document.title));
  }

  Future<void> _rename(BuildContext context, ScanDocument document) async {
    final controller = TextEditingController(text: document.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename document'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (newTitle != null && newTitle.trim().isNotEmpty && context.mounted) {
      document.title = newTitle.trim();
      await context.read<DocumentLibrary>().save(document);
      setState(() {});
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentLibrary>(
      builder: (context, library, _) {
        final document = _documentFrom(library);
        if (document == null) {
          // Deleted (e.g. from the home screen) while this was open.
          return const Scaffold(body: Center(child: Text('Document no longer exists.')));
        }
        return Scaffold(
          appBar: AppBar(
            title: GestureDetector(
              onTap: () => _rename(context, document),
              child: Text(document.title, overflow: TextOverflow.ellipsis),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_a_photo_outlined),
                tooltip: 'Add page',
                onPressed: () => _addPage(context, document),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'pdf':
                      _exportPdf(document);
                    case 'text':
                      _shareText(document);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
                  PopupMenuItem(value: 'text', child: Text('Share OCR text')),
                ],
              ),
            ],
          ),
          body: document.pages.isEmpty
              ? const Center(child: Text('This document has no pages left.'))
              : Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: document.pages.length,
                      itemBuilder: (context, index) => GestureDetector(
                        onTap: () => _editPage(context, document, index),
                        child: InteractiveViewer(
                          child: Center(
                            child: Image.file(File(document.pages[index].imagePath)),
                          ),
                        ),
                      ),
                    ),
                    if (_exporting)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black26,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
