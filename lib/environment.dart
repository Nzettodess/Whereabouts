class Environment {
  // These values can be overridden with --dart-define at build time
  static const String calendarificApiKey = String.fromEnvironment(
    'CALENDARIFIC_API_KEY',
    defaultValue: '', // Empty for security - must be provided at build time
  );
  
  static const String festivoApiKey = String.fromEnvironment(
    'FESTIVO_API_KEY',
    defaultValue: '',
  );
  
  static const String googleCalendarApiKey = String.fromEnvironment(
    'GOOGLE_CALENDAR_API_KEY',
    defaultValue: '',
  );
  
  // Helper to check if all keys are configured
  static bool get isConfigured {
    return calendarificApiKey.isNotEmpty &&
           festivoApiKey.isNotEmpty &&
           googleCalendarApiKey.isNotEmpty;
  }
  
  // Helper to get missing keys
  static List<String> get missingKeys {
    final missing = <String>[];
    if (calendarificApiKey.isEmpty) missing.add('CALENDARIFIC_API_KEY');
    if (festivoApiKey.isEmpty) missing.add('FESTIVO_API_KEY');
    if (googleCalendarApiKey.isEmpty) missing.add('GOOGLE_CALENDAR_API_KEY');
    return missing;
  }
}
