import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Stores user-picked white-noise audio files in app storage.
///
/// Why: `file_picker` paths may point to external locations that can move,
/// disappear, or become inaccessible. Saving a private copy makes the choice
/// more reliable and "permanent".
class WhiteNoiseLibraryService {
  WhiteNoiseLibraryService._();

  static final WhiteNoiseLibraryService instance = WhiteNoiseLibraryService._();

  /// Copies [sourcePath] into the app's documents directory under `white_noise/`.
  ///
  /// Returns the new absolute path on success, or null on failure.
  Future<String?> saveCustomCopy(String sourcePath) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return null;

      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}${Platform.pathSeparator}white_noise');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final base = _basename(sourcePath);
      final ext = _extension(base);
      final stem = base.substring(0, base.length - ext.length);

      final ts = DateTime.now().millisecondsSinceEpoch;
      final safeStem = _safeFileStem(stem);
      final outName = 'custom_${safeStem}_$ts$ext';
      final outPath = '${dir.path}${Platform.pathSeparator}$outName';

      await src.copy(outPath);
      return outPath;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('WhiteNoiseLibraryService.saveCustomCopy failed: $e');
      }
      return null;
    }
  }

  String _basename(String path) {
    final p = path.replaceAll('\\', '/');
    final idx = p.lastIndexOf('/');
    if (idx == -1) return p;
    return p.substring(idx + 1);
  }

  String _extension(String filename) {
    final idx = filename.lastIndexOf('.');
    if (idx <= 0) return '';
    return filename.substring(idx);
  }

  String _safeFileStem(String stem) {
    // Keep filenames simple and cross-platform.
    final cleaned = stem.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    if (cleaned.isEmpty) return 'audio';
    return cleaned.length > 32 ? cleaned.substring(0, 32) : cleaned;
  }
}
