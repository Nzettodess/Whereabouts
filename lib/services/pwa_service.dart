import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class PWAService {
  static final PWAService _instance = PWAService._internal();
  factory PWAService() => _instance;
  PWAService._internal();

  /// Check if the PWA install prompt is available (Android/Chrome) or if it's iOS
  bool isInstallPromptAvailable() {
    if (!kIsWeb) return false;
    try {
      return js.context.callMethod('isPWAInstallAvailable') ?? false;
    } catch (e) {
      debugPrint('Error checking PWA install availability: $e');
      return false;
    }
  }

  /// Trigger the manually exposed PWA install prompt
  void triggerInstall() {
    if (!kIsWeb) return;
    try {
      js.context.callMethod('triggerPWAInstall');
    } catch (e) {
      debugPrint('Error triggering PWA install: $e');
    }
  }
}
