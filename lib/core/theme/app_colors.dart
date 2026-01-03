import 'package:flutter/material.dart';

/// Centralized color definitions for the app.
/// iOS-inspired color palette with proper contrast ratios (WCAG 4.5:1+).
/// Change colors here to update them throughout the app.
class AppColors {
  // ============ iOS SYSTEM COLORS ============
  /// iOS System Blue - primary interactive color
  static const Color iosBlue = Color(0xFF007AFF);
  static const Color iosBlueLight = Color(0xFF5AC8FA); // Lighter variant
  
  /// iOS System Green - success, active switches
  static const Color iosGreen = Color(0xFF34C759);
  
  /// iOS System Orange - warnings, accent
  static const Color iosOrange = Color(0xFFFF9500);
  
  /// iOS System Red - errors, destructive
  static const Color iosRed = Color(0xFFFF3B30);
  
  /// iOS System Pink - birthdays, special
  static const Color iosPink = Color(0xFFFF2D55);
  
  /// iOS System Purple - primary brand
  static const Color iosPurple = Color(0xFF5856D6);
  static const Color iosPurpleLight = Color(0xFF8E8AFF); // For dark mode
  
  /// iOS System Teal - secondary accent
  static const Color iosTeal = Color(0xFF5AC8FA);
  
  /// iOS System Gray - neutral elements
  static const Color iosGray = Color(0xFF8E8E93);
  static const Color iosGray2 = Color(0xFFAEAEB2);
  static const Color iosGray3 = Color(0xFFC7C7CC);
  static const Color iosGray4 = Color(0xFFD1D1D6);
  static const Color iosGray5 = Color(0xFFE5E5EA);
  static const Color iosGray6 = Color(0xFFF2F2F7);
  
  // ============ LIGHT MODE SURFACES ============
  static const Color lightBackground = Color(0xFFF2F2F7); // iOS system gray 6
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightGroupedBg = Color(0xFFFFFFFF);
  static const Color lightSecondaryBg = Color(0xFFE5E5EA);
  
  // ============ DARK MODE SURFACES ============
  static const Color darkBackground = Color(0xFF000000); // True OLED black
  static const Color darkSurface = Color(0xFF1C1C1E); // iOS dark elevated
  static const Color darkGroupedBg = Color(0xFF1C1C1E);
  static const Color darkElevated = Color(0xFF2C2C2E); // iOS dark elevated 2
  static const Color darkElevatedHighest = Color(0xFF3A3A3C); // iOS dark elevated 3
  
  // ============ TEXT COLORS ============
  // Light mode text (on white/light backgrounds)
  static const Color lightPrimary = Color(0xFF000000); // Primary text
  static const Color lightSecondary = Color(0xFF3C3C43); // Secondary text
  static const Color lightTertiary = Color(0xFF48484A); // Tertiary text
  static const Color lightPlaceholder = Color(0xFFC7C7CC); // Placeholder
  
  // Dark mode text (on black/dark backgrounds)
  static const Color darkPrimary = Color(0xFFFFFFFF); // Primary text
  static const Color darkSecondary = Color(0xFFEBEBF5); // Secondary text (60% opacity)
  static const Color darkTertiary = Color(0xFFD1D1D6); // Tertiary text
  static const Color darkPlaceholder = Color(0xFF636366); // Placeholder
  
  // ============ BRAND COLORS (backwards compatible) ============
  static const Color primaryPurple = iosPurple;
  static const Color buttonPurple = iosPurple;
  static Color buttonPurpleDark = iosPurpleLight;
  static const Color accentOrange = iosOrange;
  
  // ============ SEMANTIC COLORS ============
  static const Color success = iosGreen;
  static const Color error = iosRed;
  static const Color warning = iosOrange;
  static const Color info = iosBlue;
  
  // ============ REQUEST/PENDING SECTION COLORS ============
  /// Light mode: Pending request container background
  static Color pendingBgLight = const Color(0xFFFFF3E0); // Orange 50
  
  /// Light mode: Pending request border
  static Color pendingBorderLight = const Color(0xFFFFCC80); // Orange 200
  
  /// Light mode: Pending icon and text
  static Color pendingAccentLight = const Color(0xFFF57C00); // Orange 700
  
  /// Dark mode: Pending request container background
  static Color pendingBgDark = const Color(0xFF3D2E00); // Dark orange-brown
  
  /// Dark mode: Pending request border
  static Color pendingBorderDark = const Color(0xFF5D4500); // Darker orange-brown
  
  /// Dark mode: Pending icon and text
  static Color pendingAccentDark = const Color(0xFFFFB74D); // Orange 300
  
  // ============ HELPER METHODS ============
  
  /// Get button colors based on brightness
  static Color getButtonBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? iosPurpleLight : iosPurple;
  }
  
  /// Get primary text color based on brightness
  static Color getPrimaryText(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkPrimary : lightPrimary;
  }
  
  /// Get secondary text color based on brightness
  static Color getSecondaryText(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkSecondary.withOpacity(0.6) : lightSecondary;
  }
  
  /// Get surface color based on brightness
  static Color getSurface(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkSurface : lightSurface;
  }
  
  /// Get elevated surface color based on brightness
  static Color getElevatedSurface(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkElevated : lightSurface;
  }
  
  /// Get background color based on brightness
  static Color getBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkBackground : lightBackground;
  }
  
  /// Get grouped background (for iOS-style grouped lists)
  static Color getGroupedBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkGroupedBg : lightGroupedBg;
  }
  
  /// Get divider color based on brightness
  static Color getDivider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF38383A) : iosGray4;
  }
  
  /// Get pending section colors based on brightness
  static Color getPendingBg(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? pendingBgDark : pendingBgLight;
  }
  
  static Color getPendingBorder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? pendingBorderDark : pendingBorderLight;
  }
  
  static Color getPendingAccent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? pendingAccentDark : pendingAccentLight;
  }
}
