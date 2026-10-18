import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/document_library.dart';
import 'services/document_session.dart';
import 'services/document_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Locked to portrait: the capture screen's full-screen camera preview
  // (see capture_screen.dart's _FullScreenCameraPreview) estimates its
  // crop/zoom using the portrait-specific aspect ratio CameraPreview itself
  // uses internally; a document scanner also has little reason to support
  // landscape in the first place.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
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
