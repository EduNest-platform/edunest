import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary Color Palette - Academic Blue
  static const Color primaryBlue = Color(0xFF1E3A8A); // Deep academic blue
  static const Color primaryLight = Color(
    0xFF3B82F6,
  ); // Lighter blue for accents
  static const Color primaryDark = Color(
    0xFF1E40AF,
  ); // Darker blue for pressed states

  // Secondary Color Palette - Success Green
  static const Color secondaryGreen = Color(0xFF059669); // Success green
  static const Color secondaryLight = Color(0xFF10B981); // Light green
  static const Color secondaryDark = Color(0xFF047857); // Dark green

  // Accent Color - Warm Orange
  static const Color accentOrange = Color(
    0xFFF59E0B,
  ); // Warm orange for highlights
  static const Color accentLight = Color(0xFFFBBF24); // Light orange
  static const Color accentDark = Color(0xFFD97706); // Dark orange

  // Neutral Colors
  static const Color backgroundLight = Color(
    0xFFFAFAFA,
  ); // Off-white background
  static const Color surfaceLight = Color(0xFFFFFFFF); // White surface
  static const Color cardLight = Color(0xFFFFFFFF); // White cards
  static const Color dividerLight = Color(0xFFE5E7EB); // Light gray divider

  // Text Colors
  static const Color textPrimary = Color(
    0xFF111827,
  ); // Dark gray for primary text
  static const Color textSecondary = Color(
    0xFF6B7280,
  ); // Medium gray for secondary text
  static const Color textTertiary = Color(
    0xFF9CA3AF,
  ); // Light gray for tertiary text
  static const Color textInverse = Color(
    0xFFFFFFFF,
  ); // White text on dark backgrounds

  // Status Colors
  static const Color success = Color(0xFF10B981); // Green for success
  static const Color warning = Color(0xFFF59E0B); // Orange for warnings
  static const Color error = Color(0xFFEF4444); // Red for errors
  static const Color info = Color(0xFF3B82F6); // Blue for info

  // File Type Colors
  static const Color filePYQ = Color(0xFF8B5CF6); // Purple for PYQs
  static const Color fileNotes = Color(0xFF10B981); // Green for Notes
  static const Color fileSyllabus = Color(0xFFF59E0B); // Orange for Syllabus
  static const Color fileTimetable = Color(0xFF3B82F6); // Blue for Timetable

  // Resource Type Colors
  static const Color assignmentsIcon = Color(
    0xFF10B981,
  ); // Green for assignments icon
  static const Color assignmentsTagBg = Color(
    0xFFECFDF5,
  ); // Light green for assignments tag background
  static const Color assignmentsTagText = Color(
    0xFF059669,
  ); // Deep green for assignments tag text

  static const Color codeIcon = Color(0xFF26C6DA); // Cyan for code icon
  static const Color codeTagBg = Color(
    0xFFE1F5FE,
  ); // Light blue for code tag background
  static const Color codeTagText = Color(
    0xFF00838F,
  ); // Deep cyan for code tag text

  static const Color labManualsIcon = Color(
    0xFF66BB6A,
  ); // Green for lab manuals icon
  static const Color labManualsTagBg = Color(
    0xFFC8E6C9,
  ); // Light green for lab manuals tag background
  static const Color labManualsTagText = Color(
    0xFF388E3C,
  ); // Deep green for lab manuals tag text

  static const Color pyqIcon = Color(0xFFAB47BC); // Purple for PYQ icon
  static const Color pyqTagBg = Color(
    0xFFE1BEE7,
  ); // Light purple for PYQ tag background
  static const Color pyqTagText = Color(
    0xFF6A1B9A,
  ); // Deep purple for PYQ tag text

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryBlue, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentOrange, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [secondaryGreen, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Color Scheme
    colorScheme: const ColorScheme.light(
      primary: primaryBlue,
      primaryContainer: Color(0xFFDBEAFE),
      secondary: secondaryGreen,
      secondaryContainer: Color(0xFFD1FAE5),
      tertiary: accentOrange,
      tertiaryContainer: Color(0xFFFEF3C7),
      surface: backgroundLight,
      error: error,
      onPrimary: textInverse,
      onSecondary: textInverse,
      onTertiary: textPrimary,
      onSurface: textPrimary,
      onError: textInverse,
    ),

    // App Bar Theme
    appBarTheme: AppBarTheme(
      backgroundColor: primaryBlue,
      foregroundColor: textInverse,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textInverse,
      ),
      iconTheme: const IconThemeData(color: textInverse),
    ),

    // Card Theme
    cardTheme: CardTheme(
      color: cardLight,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // Elevated Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: textInverse,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Outlined Button Theme
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryBlue,
        side: const BorderSide(color: primaryBlue, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Text Button Theme
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryBlue,
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: dividerLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: dividerLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: GoogleFonts.poppins(color: textSecondary, fontSize: 14),
      hintStyle: GoogleFonts.poppins(color: textTertiary, fontSize: 14),
    ),

    // Text Theme
    textTheme: GoogleFonts.poppinsTextTheme().copyWith(
      displayLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      displayMedium: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      displaySmall: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      headlineLarge: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleSmall: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      bodyLarge: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: textPrimary,
      ),
      bodyMedium: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: textPrimary,
      ),
      bodySmall: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: textSecondary,
      ),
      labelLarge: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      labelMedium: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
      labelSmall: GoogleFonts.poppins(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: textTertiary,
      ),
    ),

    // Tab Bar Theme
    tabBarTheme: const TabBarTheme(
      labelColor: primaryBlue,
      unselectedLabelColor: textSecondary,
      indicatorColor: primaryBlue,
      indicatorSize: TabBarIndicatorSize.tab,
    ),

    // Bottom Navigation Bar Theme
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceLight,
      selectedItemColor: primaryBlue,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    // Floating Action Button Theme
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryBlue,
      foregroundColor: textInverse,
      elevation: 4,
    ),

    // Divider Theme
    dividerTheme: const DividerThemeData(
      color: dividerLight,
      thickness: 1,
      space: 1,
    ),

    // Icon Theme
    iconTheme: const IconThemeData(color: textSecondary, size: 24),
  );

  // Dark Theme (Optional for future)
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    colorScheme: const ColorScheme.dark(
      primary: primaryLight,
      primaryContainer: Color(0xFF1E3A8A),
      secondary: secondaryLight,
      secondaryContainer: Color(0xFF065F46),
      tertiary: accentLight,
      tertiaryContainer: Color(0xFF92400E),
      surface: Color(0xFF111827),
      error: Color(0xFFF87171),
      onPrimary: textInverse,
      onSecondary: textInverse,
      onTertiary: textPrimary,
      onSurface: textInverse,
      onError: textInverse,
    ),

    // Similar theme configurations for dark mode...
  );

  // Custom Color Extensions
  static Color getFileTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'pyq':
        return filePYQ;
      case 'notes':
        return fileNotes;
      case 'syllabus':
        return fileSyllabus;
      case 'timetable':
        return fileTimetable;
      default:
        return textSecondary;
    }
  }

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
      case 'success':
        return success;
      case 'pending':
      case 'warning':
        return warning;
      case 'error':
      case 'rejected':
        return error;
      case 'info':
        return info;
      default:
        return textSecondary;
    }
  }
}
