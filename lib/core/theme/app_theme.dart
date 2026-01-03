import 'package:flutter/material.dart';

/// AppTheme: macOS/iOS-inspired design system
/// - Apple SF system fonts for native feel
/// - iOS-style colors with proper contrast (WCAG 4.5:1+)
/// - Consistent 16px card radius, 12px button radius
/// - OLED-optimized dark mode
class AppTheme {
  // ============ BRAND COLORS ============
  // Kept for backwards compatibility, now blended with iOS palette
  static const Color _primaryPurple = Color(0xFF5856D6); // iOS-style purple
  static const Color _accentOrange = Color(0xFFFF9500); // iOS orange
  
  // ============ iOS SYSTEM COLORS ============
  static const Color _iosBlue = Color(0xFF007AFF);
  static const Color _iosGreen = Color(0xFF34C759);
  
  // ============ LIGHT MODE PALETTE ============
  static const Color _lightBackground = Color(0xFFF2F2F7); // iOS system gray 6
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSecondaryBg = Color(0xFFE5E5EA); // iOS system gray 5
  
  // ============ DARK MODE PALETTE ============
  static const Color _darkBackground = Color(0xFF000000); // True OLED black
  static const Color _darkSurface = Color(0xFF1C1C1E); // iOS dark elevated
  static const Color _darkSurfaceElevated = Color(0xFF2C2C2E); // iOS dark elevated 2
  static const Color _darkSurfaceHighest = Color(0xFF3A3A3C); // iOS dark elevated 3

  // ============ TYPOGRAPHY ============
  // Apple system fonts with cross-platform fallbacks
  static const String _fontFamily = '-apple-system';
  static const List<String> _fontFallback = [
    'BlinkMacSystemFont',
    'SF Pro Display', 
    'Segoe UI',
    'Roboto', 
    'Helvetica Neue',
    'Arial', 
    'sans-serif'
  ];

  /// Build text theme with Apple-style typography
  /// - Slightly heavier weights for better legibility
  /// - Consistent letter spacing
  static TextTheme _buildTextTheme(TextTheme base, {bool isDark = false}) {
    final Color textColor = isDark ? Colors.white : const Color(0xFF000000);
    final Color secondaryColor = isDark ? const Color(0xFFEBEBF5) : const Color(0xFF3C3C43);
    
    return base.copyWith(
      // Display styles - for large headers
      displayLarge: base.displayLarge?.copyWith(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFallback,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: textColor,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFallback,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: textColor,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFallback,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: textColor,
      ),
      // Headline styles - for section headers
      headlineLarge: base.headlineLarge?.copyWith(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFallback,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: textColor,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFallback,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: textColor,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFallback,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: textColor,
      ),
      // Title styles - for card titles, list items
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFallback,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: textColor,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFallback,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: textColor,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFallback,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: textColor,
      ),
      // Body styles - for main content
      bodyLarge: base.bodyLarge?.copyWith(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFallback,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: textColor,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFallback,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: secondaryColor,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFallback,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        color: secondaryColor.withOpacity(0.8),
      ),
      // Label styles - for buttons, chips
      labelLarge: base.labelLarge?.copyWith(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFallback,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: textColor,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFallback,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        color: secondaryColor,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFallback,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        color: secondaryColor.withOpacity(0.7),
      ),
    );
  }

  // ============ LIGHT THEME ============
  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryPurple,
        brightness: Brightness.light,
        primary: _primaryPurple,
        secondary: _accentOrange,
        surface: _lightSurface,
        surfaceContainerHighest: _lightSecondaryBg,
        onSurface: const Color(0xFF000000), // Maximum contrast
        onSurfaceVariant: const Color(0xFF3C3C43), // iOS secondary label
      ),
      scaffoldBackgroundColor: _lightBackground,
      textTheme: _buildTextTheme(base.textTheme, isDark: false),
      
      // AppBar - subtle glass effect
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF000000)),
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          color: const Color(0xFF000000),
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      
      // Cards - iOS-style with subtle shadow
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // iOS standard
        ),
        color: _lightSurface,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        shadowColor: Colors.black.withOpacity(0.08),
      ),
      
      // Dialogs - slightly smaller radius for iOS feel
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _lightSurface,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.15),
        surfaceTintColor: Colors.transparent,
      ),
      
      // FAB - iOS tinted style
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _accentOrange,
        foregroundColor: Colors.white,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      
      // Buttons - iOS-style rounded
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontFamilyFallback: _fontFallback,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontFamilyFallback: _fontFallback,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: Colors.grey.shade300),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontFamilyFallback: _fontFallback,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
      ),
      
      // Input fields - iOS style
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSecondaryBg.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryPurple, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          color: const Color(0xFF3C3C43).withOpacity(0.6),
        ),
      ),
      
      // Chips - iOS tag style
      chipTheme: ChipThemeData(
        backgroundColor: _lightSecondaryBg,
        selectedColor: _primaryPurple,
        labelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide.none,
      ),
      
      // ListTile - iOS style padding
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 12,
      ),
      
      // Divider - subtle
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 0.5,
        space: 0,
      ),
      
      // Switch - iOS green when active
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _iosGreen;
          return Colors.grey.shade300;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      
      // Checkbox - iOS blue when checked
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _iosBlue;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: Colors.grey.shade400, width: 1.5),
      ),
      
      // Bottom sheet - iOS style
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
        dragHandleColor: Color(0xFFE5E5EA),
      ),
      
      // Snackbar - simple style (floating causes issues during theme rebuilds)
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1C1C1E),
        contentTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  // ============ DARK THEME ============
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryPurple,
        brightness: Brightness.dark,
        primary: const Color(0xFF8E8AFF), // Brighter purple for dark mode visibility
        secondary: _accentOrange,
        surface: _darkSurface,
        surfaceContainerHighest: _darkSurfaceHighest,
        onSurface: Colors.white,
        onSurfaceVariant: const Color(0xFFEBEBF5).withOpacity(0.6), // iOS secondary label dark
      ),
      scaffoldBackgroundColor: _darkBackground,
      textTheme: _buildTextTheme(base.textTheme, isDark: true),
      
      // AppBar - glass effect
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      
      // Cards - elevated dark surface
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: _darkSurface,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      ),
      
      // Dialogs
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _darkSurfaceElevated,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      
      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _accentOrange,
        foregroundColor: Colors.white,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      
      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontFamilyFallback: _fontFallback,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontFamilyFallback: _fontFallback,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: Colors.grey.shade700),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontFamilyFallback: _fontFallback,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
      ),
      
      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8E8AFF), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          color: Colors.white.withOpacity(0.4),
        ),
      ),
      
      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: _darkSurfaceElevated,
        selectedColor: const Color(0xFF8E8AFF),
        labelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide.none,
      ),
      
      // ListTile
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 12,
        iconColor: Colors.white70,
      ),
      
      // Divider
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade800,
        thickness: 0.5,
        space: 0,
      ),
      
      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _iosGreen;
          return Colors.grey.shade700;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      
      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _iosBlue;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: Colors.grey.shade600, width: 1.5),
      ),
      
      // Bottom sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _darkSurfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
        dragHandleColor: Color(0xFF3A3A3C),
      ),
      
      // Snackbar - simple style
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkSurfaceHighest,
        contentTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.fixed,
      ),
      
      // Icon theme
      iconTheme: const IconThemeData(
        color: Colors.white70,
      ),
    );
  }
}
