import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/scan_document.dart';
import '../services/document_library.dart';
import '../services/document_session.dart';
import '../widgets/page_thumb.dart';
import 'capture_screen.dart';
import 'document_viewer_screen.dart';
import 'session_screen.dart';
import 'settings_screen.dart';

/// The document library: every scan saved on this device, newest first.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _startNewScan(BuildContext context) async {
    final session = context.read<DocumentSession>();
    session.clear();
    final addedFirstPage = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CaptureScreen(
          onPageCaptured: (page) async => session.addPage(page),
        ),
      ),
    );
    if (addedFirstPage == true && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SessionScreen()),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, ScanDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${document.title}"?'),
        content: const Text('This removes the document and its pages from this device. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<DocumentLibrary>().delete(document.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LibreScan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Consumer<DocumentLibrary>(
        builder: (context, library, _) {
          if (library.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (library.documents.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.document_scanner_outlined,
                        size: 64, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 16),
                    const Text(
                      'No scans yet.\nTap + to scan your first document.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.62,
            ),
            itemCount: library.documents.length,
            itemBuilder: (context, index) {
              final document = library.documents[index];
              return GestureDetector(
                onLongPress: () => _confirmDelete(context, document),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: PageThumb(
                        imagePath: document.pages.first.imagePath,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DocumentViewerScreen(documentId: document.id),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      document.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${document.pages.length} page${document.pages.length == 1 ? '' : 's'}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startNewScan(context),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('New scan'),
      ),
    );
  }
}
