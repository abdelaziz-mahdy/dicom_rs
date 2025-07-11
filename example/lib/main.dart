import 'package:flutter/material.dart';
import 'package:dicom_rs/dicom_rs.dart';
import 'screens/dicom_viewer_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the Rust library for DICOM operations
  await RustLib.init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DICOM Viewer - Complex Demo with Minimal API',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      home: const DicomViewerScreen(),
    );
  }
}
