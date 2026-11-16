import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/feedback/interaction_feedback.dart';
import 'core/security/app_lock_controller.dart';
import 'core/security/private_album_controller.dart';
import 'core/theme/app_theme_controller.dart';
import 'data/services/photo_import_service.dart';
import 'features/home/home_controller.dart';
import 'features/settings/photo_source_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted theme preference before running the app.
  final themeController = AppThemeController();
  await themeController.load();
  final photoSourceController = PhotoSourceController();
  await photoSourceController.load();
  final appLockController = AppLockController();
  await appLockController.load();
  final privateAlbumController = PrivateAlbumController();
  await privateAlbumController.load();
  final interactionFeedbackController = InteractionFeedbackController();
  await interactionFeedbackController.load();

  // Fill in content fingerprints for photos imported before dedup existed.
  // Fire-and-forget: batches with pauses, never blocks the UI.
  unawaited(PhotoImportService.backfillContentHashes());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeController),
        ChangeNotifierProvider(create: (_) => HomeController()),
        ChangeNotifierProvider.value(value: photoSourceController),
        ChangeNotifierProvider.value(value: appLockController),
        ChangeNotifierProvider.value(value: privateAlbumController),
        ChangeNotifierProvider.value(value: interactionFeedbackController),
      ],
      child: const PhotoStorerApp(),
    ),
  );
}
