import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/document_library.dart';
import 'services/document_session.dart';
import 'services/document_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await DocumentStore.instance();
  runApp(LibreScanApp(store: store));
}

/// Root widget: wires up the two app-lifetime controllers — the saved
/// document library, and the in-progress capture session — above the
/// Navigator so every pushed screen can reach them via [Provider].
class LibreScanApp extends StatelessWidget {
  const LibreScanApp({super.key, required this.store});

  final DocumentStore store;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DocumentSession()),
        ChangeNotifierProvider(create: (_) => DocumentLibrary(store)),
      ],
      child: MaterialApp(
        title: 'LibreScan',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
