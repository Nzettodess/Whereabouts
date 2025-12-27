import 'package:flutter/foundation.dart';

/// Centralized logging service for the application.
/// Provides debug, info, warning, and error level logging.
/// Only logs in debug mode to prevent production log spam.
class AppLogger {
  final String _tag;
  
  /// Create a logger with a specific tag (usually the class name)
  const AppLogger(this._tag);
  
  /// Factory constructor for creating loggers with class type
  factory AppLogger.forType(Type type) => AppLogger(type.toString());

  /// Log debug information (development only)
  void debug(String message) {
    if (kDebugMode) {
      debugPrint('[$_tag] DEBUG: $message');
    }
  }

  /// Log informational messages
  void info(String message) {
    if (kDebugMode) {
      debugPrint('[$_tag] INFO: $message');
    }
  }

  /// Log warnings
  void warning(String message) {
    if (kDebugMode) {
      debugPrint('[$_tag] ⚠️ WARNING: $message');
    }
  }

  /// Log errors with optional stack trace
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[$_tag] ❌ ERROR: $message');
      if (error != null) {
        debugPrint('[$_tag] Exception: $error');
      }
      if (stackTrace != null) {
        debugPrint('[$_tag] StackTrace: $stackTrace');
      }
    }
  }

  /// Log method entry (useful for tracing)
  void trace(String methodName, [Map<String, dynamic>? params]) {
    if (kDebugMode) {
      final paramStr = params != null ? ' with ${params.entries.map((e) => '${e.key}=${e.value}').join(', ')}' : '';
      debugPrint('[$_tag] → $methodName$paramStr');
    }
  }
}

/// Global logger instance for quick access
final appLog = AppLogger('App');
