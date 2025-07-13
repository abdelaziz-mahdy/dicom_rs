import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:dicom_rs/dicom_rs.dart';
import 'package:path/path.dart' as path;
import 'file_selector_service.dart';
import '../screens/dicom_loading_screen.dart';

/// High-performance DICOM validation service using CPU cores and isolates
class DicomIsolateValidator {
  static int get _coreCount => Platform.numberOfProcessors;

  /// Validate files using isolates distributed across CPU cores
  static Future<List<DicomFileData>> validateFilesWithIsolates(
    List<File> files,
  ) async {
    final coreCount = _coreCount;
    debugPrint('🚀 ISOLATE: Using $coreCount CPU cores for DICOM validation');
    
    if (files.isEmpty) return [];
    
    // Distribute files across CPU cores
    final batches = _distributeFilesAcrossCores(files, coreCount);
    debugPrint('🚀 ISOLATE: Split ${files.length} files into ${batches.length} batches');
    
    // Start progress tracking
    DicomLoadingProgressNotifier.notify(
      DicomLoadingProgressEvent.processing(
        fileName: 'Starting validation on $coreCount CPU cores...',
        processed: 0,
        total: files.length,
      ),
    );
    
    // Create isolates for each batch
    final isolateFutures = <Future<List<DicomFileData>>>[];
    final progressPorts = <ReceivePort>[];
    
    for (int i = 0; i < batches.length; i++) {
      final progressPort = ReceivePort();
      progressPorts.add(progressPort);
      
      // Listen to progress from this isolate
      _listenToIsolateProgress(progressPort, i, batches.length);
      
      // Start isolate validation
      isolateFutures.add(_validateBatchInIsolate(
        batches[i], 
        i, 
        progressPort.sendPort,
      ));
    }
    
    try {
      // Wait for all isolates to complete
      final results = await Future.wait(isolateFutures);
      
      // Close progress ports
      for (final port in progressPorts) {
        port.close();
      }
      
      // Combine results from all isolates
      final allValidFiles = <DicomFileData>[];
      for (final batchResult in results) {
        allValidFiles.addAll(batchResult);
      }
      
      if (allValidFiles.isEmpty) {
        debugPrint('❌ ISOLATE: No valid DICOM files found - this likely indicates DicomHandler() cannot work in isolates');
        debugPrint('❌ ISOLATE: The dicom_rs package may require main thread context for native bindings');
      } else {
        debugPrint('✅ ISOLATE: Validation complete - ${allValidFiles.length}/${files.length} valid DICOM files');
      }
      
      DicomLoadingProgressNotifier.notify(
        DicomLoadingProgressEvent.completed(totalLoaded: allValidFiles.length),
      );
      
      return allValidFiles;
      
    } catch (e) {
      // Close progress ports on error
      for (final port in progressPorts) {
        port.close();
      }
      
      debugPrint('❌ ISOLATE: Validation failed: $e');
      DicomLoadingProgressNotifier.notify(
        DicomLoadingProgressEvent.error('Validation failed: $e'),
      );
      rethrow;
    }
  }

  /// Distribute files evenly across available CPU cores
  static List<List<File>> _distributeFilesAcrossCores(List<File> files, int coreCount) {
    final batches = <List<File>>[];
    final filesPerCore = (files.length / coreCount).ceil();
    
    for (int i = 0; i < coreCount && i * filesPerCore < files.length; i++) {
      final startIndex = i * filesPerCore;
      final endIndex = ((i + 1) * filesPerCore).clamp(0, files.length);
      batches.add(files.sublist(startIndex, endIndex));
    }
    
    return batches;
  }

  /// Listen to progress updates from an isolate
  static void _listenToIsolateProgress(ReceivePort progressPort, int isolateIndex, int totalIsolates) {
    progressPort.listen((message) {
      if (message is Map<String, dynamic>) {
        final processed = message['processed'] as int? ?? 0;
        final total = message['total'] as int? ?? 0;
        final fileName = message['fileName'] as String? ?? '';
        final isComplete = message['complete'] as bool? ?? false;
        final isError = message['error'] as bool? ?? false;
        
        if (isComplete) {
          debugPrint('✅ ISOLATE $isolateIndex: Completed validation of $total files');
        } else if (isError) {
          debugPrint('❌ ISOLATE $isolateIndex: $fileName');
        } else {
          debugPrint('🔄 ISOLATE $isolateIndex: $fileName ($processed/$total)');
          
          // Report progress to UI
          DicomLoadingProgressNotifier.notify(
            DicomLoadingProgressEvent.processing(
              fileName: 'Core ${isolateIndex + 1}/$totalIsolates: $fileName',
              processed: processed,
              total: total,
            ),
          );
        }
      }
    });
  }

  /// Validate a batch of files in an isolate
  static Future<List<DicomFileData>> _validateBatchInIsolate(
    List<File> batch,
    int isolateIndex,
    SendPort progressPort,
  ) async {
    final receivePort = ReceivePort();
    
    try {
      await Isolate.spawn(
        _isolateValidationWorker,
        _IsolateValidationParams(
          files: batch,
          isolateIndex: isolateIndex,
          responsePort: receivePort.sendPort,
          progressPort: progressPort,
        ),
      );
      
      // Wait for result from isolate
      final result = await receivePort.first as List<DicomFileData>;
      return result;
      
    } finally {
      receivePort.close();
    }
  }

  /// Isolate worker function for DICOM validation
  static void _isolateValidationWorker(_IsolateValidationParams params) async {
    final validFiles = <DicomFileData>[];
    
    try {
      // Initialize RustLib in this isolate
      await RustLib.init();
      for (int i = 0; i < params.files.length; i++) {
        final file = params.files[i];
        final fileName = path.basename(file.path);
        
        // Report progress
        params.progressPort.send({
          'processed': i + 1,
          'total': params.files.length,
          'fileName': fileName,
          'complete': false,
        });
        
        try {
          // Read file bytes
          final bytes = await file.readAsBytes();
          
          // Validate DICOM and extract metadata in one pass
          final handler = DicomHandler();
          final metadata = await handler.getMetadata(bytes);
          
          // If we got here, it's a valid DICOM file
          validFiles.add(DicomFileData(
            name: fileName,
            bytes: bytes,
            fullPath: file.path,
            metadata: metadata,
          ));
          
        } catch (e) {
          // DON'T HIDE ERRORS - Report them for debugging
          params.progressPort.send({
            'processed': i + 1,
            'total': params.files.length,
            'fileName': 'ERROR: $fileName - $e',
            'complete': false,
            'error': true,
          });
          continue;
        }
      }
      
      // Report completion
      params.progressPort.send({
        'processed': params.files.length,
        'total': params.files.length,
        'fileName': 'Completed',
        'complete': true,
      });
      
      // Send results back to main isolate
      params.responsePort.send(validFiles);
      
    } catch (e) {
      // Send error back to main isolate
      params.responsePort.send(<DicomFileData>[]);
    }
  }
}

/// Parameters for isolate validation worker
class _IsolateValidationParams {
  final List<File> files;
  final int isolateIndex;
  final SendPort responsePort;
  final SendPort progressPort;

  _IsolateValidationParams({
    required this.files,
    required this.isolateIndex,
    required this.responsePort,
    required this.progressPort,
  });
}