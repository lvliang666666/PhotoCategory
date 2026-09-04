import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

class FileUtils {
  FileUtils._();

  /// Generate a unique filename with the original extension preserved.
  /// Uses a random 8-char hex string to keep filenames reasonably short
  /// while avoiding collisions.
  static String generateUniqueFileName(String originalName) {
    final ext = p.extension(originalName);
    final random = Random();
    final bytes = List<int>.generate(8, (_) => random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
    return '$hex$ext';
  }

  /// Ensure the given directory exists, creating it if necessary.
  static Future<Directory> ensureDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Delete a file at [path]. Returns true if the file was deleted
  /// or already didn't exist; returns false if deletion failed for
  /// reasons other than the file not existing.
  static Future<bool> deleteFileIfExists(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
