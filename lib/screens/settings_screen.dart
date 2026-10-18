import 'package:flutter/material.dart';
import '../services/ocr_service.dart';

/// About / info screen. LibreScan has no accounts, no cloud sync and no
/// in-app settings that need a network connection — this page is mostly
/// here to be upfront about what the app does and doesn't do.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About LibreScan')),
      body: ListView(
        // Extra bottom padding: Android draws edge-to-edge by default now.
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text(
            'LibreScan is a free, open-source document scanner.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Everything — capture, crop, filters and OCR — runs on this '
            'device. LibreScan makes no network requests, has no account, '
            'no ads, and no analytics. Uninstalling the app removes '
            'everything it stored.',
          ),
          const SizedBox(height: 24),
          const ListTile(
            leading: Icon(Icons.text_fields_outlined),
            title: Text('OCR languages bundled'),
            subtitle: Text('English (eng). See the README for how to add more.'),
            contentPadding: EdgeInsets.zero,
          ),
          const ListTile(
            leading: Icon(Icons.code_outlined),
            title: Text('Source code & license'),
            subtitle: Text('MIT licensed — see LICENSE in the project repository'),
            contentPadding: EdgeInsets.zero,
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('OCR engine'),
            subtitle: Text('Tesseract OCR, bundled fully offline'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 24),
          Text('Bundled languages: ${OcrService.bundledLanguages.join(', ')}'),
        ],
      ),
    );
  }
}
