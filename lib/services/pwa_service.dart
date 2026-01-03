import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class PWAService {
  static final PWAService _instance = PWAService._internal();
  factory PWAService() => _instance;
  PWAService._internal();

  /// Check if running on iOS
  bool _isIOS() {
    if (!kIsWeb) return false;
    try {
      final userAgent = js.context['navigator']['userAgent'] as String? ?? '';
      return userAgent.contains('iPhone') || 
             userAgent.contains('iPad') || 
             userAgent.contains('iPod');
    } catch (e) {
      return false;
    }
  }

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

  /// Determine whether to show the Install App button in the drawer.
  /// Always shows on iOS because Safari can't reliably detect if PWA is installed.
  bool shouldShowInstallButton() {
    if (!kIsWeb) return false;
    
    // Always show on iOS - Safari can't reliably detect installation status
    if (_isIOS()) return true;
    
    // For other platforms, use the standard check
    return isInstallPromptAvailable();
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

  /// Reload the current page (useful for PWA users to refresh content)
  void reloadPage() {
    if (!kIsWeb) return;
    try {
      js.context['location'].callMethod('reload');
    } catch (e) {
      debugPrint('Error reloading page: $e');
    }
  }
}
