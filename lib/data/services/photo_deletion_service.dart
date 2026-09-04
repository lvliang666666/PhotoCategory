import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../models/photo_model.dart';
import '../repositories/photo_repository.dart';

/// Permanently removes copies imported into this app.
///
/// The source photo selected from the device gallery is never touched. File
/// deletion is restricted to the app's own photos directory so a malformed
/// database path cannot delete an arbitrary user file.
class PhotoDeletionService {
  final PhotoRepository _photos = PhotoRepository();

  Future<BatchOperationResult> deleteImportedPhotos(
      List<PhotoModel> photos) async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = p.normalize(p.absolute(
      p.join(appDir.path, AppConstants.photosDirName),
    ));
    final failed = <int>[];

    for (final photo in photos) {
      final id = photo.id;
      if (id == null) continue;
      try {
        final localPath = p.normalize(p.absolute(photo.localPath));
        if (photo.localPath.isEmpty || !p.isWithin(photosDir, localPath)) {
          failed.add(id);
          continue;
        }

        final file = File(localPath);
        if (await file.exists()) await file.delete();
        if (!await _photos.deletePhoto(id)) failed.add(id);
      } catch (_) {
        failed.add(id);
      }
    }

    return BatchOperationResult(
      successCount: photos.length - failed.length,
      failCount: failed.length,
      failedPhotoIds: failed,
    );
  }
}
