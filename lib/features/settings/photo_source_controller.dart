import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

class PhotoSourceController extends ChangeNotifier {
  bool firstUseCompleted = false;
  int dataRevision = 0;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    firstUseCompleted =
        prefs.getBool(AppConstants.prefFirstUseCompleted) ?? false;
    // Remove preferences left by versions that supported system indexing.
    await prefs.remove('sync_system_gallery');
    await prefs.remove('last_system_gallery_sync');
    notifyListeners();
  }

  Future<void> completeFirstUse() async {
    firstUseCompleted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefFirstUseCompleted, true);
    notifyListeners();
  }

  void notifyLibraryRestored() {
    dataRevision++;
    notifyListeners();
  }
}
