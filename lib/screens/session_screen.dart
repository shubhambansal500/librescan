import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/document_library.dart';
import '../services/document_session.dart';
import '../widgets/page_thumb.dart';
import 'capture_screen.dart';
import 'page_detail_screen.dart';

/// The in-progress multi-page document: shows every page captured so far,
/// lets the user add more, reorder, edit or delete pages, and finish by
/// naming and saving the document.
class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  bool _saving = false;

  Future<void> _addPage(BuildContext context) async {
    final session = context.read<DocumentSession>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaptureScreen(
          onPageCaptured: (page) async => session.addPage(page),
        ),
      ),
    );
  }

  Future<void> _editPage(BuildContext context, String pageId) async {
    final session = context.read<DocumentSession>();
    final page = session.pages.firstWhere((p) => p.id == pageId);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PageDetailScreen(
          page: page,
          onUpdated: (updated) async => session.replacePage(updated),
          onDeleted: () async => session.removePage(pageId),
        ),
      ),
    );
  }

  Future<void> _finish(BuildContext context) async {
    final session = context.read<DocumentSession>();
    if (session.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one page first.')),
      );
      return;
    }

    final title = await _promptTitle(context);
    if (title == null || title.trim().isEmpty) return;
    if (!context.mounted) return;

    setState(() => _saving = true);
    try {
      final library = context.read<DocumentLibrary>();
      await library.commitSession(session.pages, title.trim());
      session.clear();
      if (!context.mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save document: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _promptTitle(BuildContext context) {
    final controller = TextEditingController(
      text: 'Scan ${DateTime.now().toString().substring(0, 16)}',
    );
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name this document'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New scan'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _saving
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: () => _finish(context),
                    child: const Text('Finish'),
                  ),
          ),
        ],
      ),
      body: Consumer<DocumentSession>(
        builder: (context, session, _) {
          if (session.isEmpty) {
            return const Center(child: Text('No pages yet. Tap + to scan one.'));
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: session.pageCount,
            // ignore: deprecated_member_use
            onReorder: session.reorder,
            itemBuilder: (context, index) {
              final page = session.pages[index];
              return Padding(
                key: ValueKey(page.id),
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  height: 120,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 86,
                        child: PageThumb(
                          imagePath: page.imagePath,
                          onTap: () => _editPage(context, page.id),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Page ${index + 1} · ${page.filter.label}'),
                      ),
                      const Icon(Icons.drag_handle),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addPage(context),
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
}
