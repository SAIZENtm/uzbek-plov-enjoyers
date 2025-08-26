import 'package:flutter/material.dart';

/// Premium minimalist theme system for Newport Resident App
/// Inspired by Apple's design philosophy: simplicity, elegance, and user-centricity
class AppTheme {
  AppTheme._();

  // PREMIUM NEWPORT BRAND COLORS
  static const Color newportPrimary = Color(0xFF0D47A1); // Deep sophisticated blue
  static const Color newportSecondary = Color(0xFF1976D2); // Refined blue accent
  static const Color newportGold = Color(0xFFD4AF37); // Luxury gold accent (optional)

  // PREMIUM NEUTRALS - Clean and sophisticated
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFFAFBFC); // Main background - soft and easy on eyes
  static const Color lightGray = Color(0xFFF5F6FA); // Card backgrounds
  static const Color neutralGray = Color(0xFFE5E7EB); // Borders and dividers
  static const Color mediumGray = Color(0xFF9CA3AF); // Secondary text
  static const Color darkGray = Color(0xFF374151); // Primary text
  static const Color charcoal = Color(0xFF1F2937); // Headers and emphasis

  // STATUS COLORS - Refined and professional
  static const Color successGreen = Color(0xFF10B981); // Emerald success
  static const Color warningAmber = Color(0xFFF59E0B); // Professional warning
  static const Color errorRed = Color(0xFFEF4444); // Clean error state
  static const Color infoBlue = Color(0xFF3B82F6); // Information highlights

  // SURFACE COLORS - Premium depth and hierarchy
  static const Color surfaceLight = pureWhite;
  static const Color surfaceVariant = lightGray;
  static const Color outline = neutralGray;
  static const Color shadow = Color(0x0A000000); // Subtle 4% shadow

  // DARK THEME COLORS (for future premium dark mode)
  static const Color darkBackground = Color(0xFF0F0F0F);
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color darkOnSurface = Color(0xFFE5E7EB);

  /// Easy access to primary and secondary colors
  static const Color primaryColor = newportPrimary;
  static const Color secondaryColor = newportSecondary;

  /// Easy access to colors for consistent usage
  static const AppColors colors = AppColors._();

  /// Easy access to typography for consistent usage
  static const AppTypography typography = AppTypography._();

  /// Easy access to shadows for consistent usage
  static const AppShadows shadows = AppShadows._();

  /// Main light theme - Premium minimalist design
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    
    // Color scheme based on Newport brand
    colorScheme: const ColorScheme.light(
      primary: newportPrimary,
      secondary: newportSecondary,
      surface: surfaceLight,
      onSurface: darkGray,
      surfaceContainerHighest: lightGray,
      outline: neutralGray,
      error: errorRed,
      onError: pureWhite,
    ),
    
    // Clean background
    scaffoldBackgroundColor: offWhite,
    
    // Premium typography - Clear hierarchy
    fontFamily: 'Aeroport',
    textTheme: const TextTheme(
      // Display styles - For hero content
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: charcoal,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: charcoal,
        letterSpacing: -0.25,
      ),
      
      // Headline styles - For section headers
      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: charcoal,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: charcoal,
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: charcoal,
      ),
      
      // Title styles - For card headers and important content
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: charcoal,
      ),
      titleMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: darkGray,
      ),
      titleSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: darkGray,
      ),
      
      // Body styles - For main content
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: darkGray,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: darkGray,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: mediumGray,
      ),
      
      // Label styles - For buttons and secondary info
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: darkGray,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: mediumGray,
      ),
      labelSmall: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: mediumGray,
      ),
    ),
    
    // Elevated buttons - Primary actions
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: newportPrimary,
        foregroundColor: pureWhite,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'Aeroport',
        ),
        // Smooth press animation
        splashFactory: InkRipple.splashFactory,
      ),
    ),
    
    // Text buttons - Secondary actions
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: newportPrimary,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: 'Aeroport',
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    
    // Input fields - Clean and accessible
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: pureWhite,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: neutralGray, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: neutralGray, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: newportPrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: errorRed, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: errorRed, width: 2),
      ),
      hintStyle: const TextStyle(
        color: mediumGray,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: const TextStyle(
        color: mediumGray,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        color: newportPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
    
    // Cards - Clean elevation and spacing
    cardTheme: CardThemeData(
      color: pureWhite,
      elevation: 0,
      shadowColor: shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: neutralGray, width: 0.5),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    
    // App bar - Clean and minimal
    appBarTheme: const AppBarTheme(
      backgroundColor: offWhite,
      foregroundColor: charcoal,
      elevation: 0,
      shadowColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: charcoal,
        fontFamily: 'Aeroport',
      ),
      iconTheme: IconThemeData(color: charcoal),
    ),
    
    // Bottom navigation - Premium look
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: pureWhite,
      selectedItemColor: newportPrimary,
      unselectedItemColor: mediumGray,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        fontFamily: 'Aeroport',
      ),
      unselectedLabelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        fontFamily: 'Aeroport',
      ),
    ),
    
         // Navigation bar (Material 3)
     navigationBarTheme: NavigationBarThemeData(
       backgroundColor: pureWhite,
       indicatorColor: newportPrimary.withValues(alpha: 0.1),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: newportPrimary, size: 24);
        }
        return const IconThemeData(color: mediumGray, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: newportPrimary,
            fontFamily: 'Aeroport',
          );
        }
        return const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: mediumGray,
          fontFamily: 'Aeroport',
        );
      }),
      elevation: 8,
      shadowColor: shadow,
    ),
    
    // Icons - Consistent sizing
    iconTheme: const IconThemeData(
      color: mediumGray,
      size: 24,
    ),
    
    // Dividers - Subtle separation
    dividerTheme: const DividerThemeData(
      color: neutralGray,
      thickness: 0.5,
      space: 1,
    ),
    
    // Snack bars - Clean feedback
    snackBarTheme: SnackBarThemeData(
      backgroundColor: charcoal,
      contentTextStyle: const TextStyle(
        color: pureWhite,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        fontFamily: 'Aeroport',
      ),
      actionTextColor: newportSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 8,
    ),
  );

  /// Premium dark theme (for future implementation)
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: newportSecondary,
      secondary: newportPrimary,
      surface: darkSurface,
      onSurface: darkOnSurface,
      error: errorRed,
    ),
    scaffoldBackgroundColor: darkBackground,
    fontFamily: 'Aeroport',
  );

  /// Status color helper for consistent UI states
  static Color getStatusColor(String status, {bool isDark = false}) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'paid':
      case 'completed':
      case 'approved':
        return successGreen;
      case 'warning':
      case 'pending':
      case 'due':
      case 'in_progress':
        return warningAmber;
      case 'error':
      case 'overdue':
      case 'failed':
      case 'rejected':
        return errorRed;
      case 'info':
      case 'new':
      case 'draft':
        return infoBlue;
      default:
        return isDark ? darkOnSurface : mediumGray;
    }
  }

  /// Get status color with semantic meaning
  static Color getStatusColorSemantic(String status) {
    return getStatusColor(status);
  }

  /// Premium shadow presets for consistent elevation
  static List<BoxShadow> get cardShadow => [
    const BoxShadow(
      color: shadow,
      blurRadius: 20,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: newportPrimary.withValues(alpha: 0.25),
      blurRadius: 12,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get floatingShadow => [
    const BoxShadow(
      color: shadow,
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  // Backward compatibility with existing code
  static const Color primarySeed = newportPrimary;
  static const Color secondarySeed = newportSecondary;
  static const Color successLight = successGreen;
  static const Color warningLight = warningAmber;
  static const Color errorLight = errorRed;
  static const Color backgroundLight = offWhite;
  static const Color textPrimaryLight = darkGray;
  static const Color textSecondaryLight = mediumGray;
  
  // Additional backward compatibility
  static const Color primaryLight = newportPrimary;
  static const Color shadowLight = shadow;
  static const Color onPrimaryLight = pureWhite;
  static const Color dividerLight = neutralGray;
  static const Color textDisabledLight = mediumGray;
  static const Color textMediumEmphasisLight = mediumGray;
}

/// Easy access to all colors
class AppColors {
  const AppColors._();

  // Background colors
  Color get background => AppTheme.offWhite;
  Color get surface => AppTheme.pureWhite;
  Color get pureWhite => AppTheme.pureWhite;
  Color get offWhite => AppTheme.offWhite;
  Color get lightGray => AppTheme.lightGray;
  Color get neutralGray => AppTheme.neutralGray;
  
  // Text colors
  Color get charcoal => AppTheme.charcoal;
  Color get darkGray => AppTheme.darkGray;
  Color get mediumGray => AppTheme.mediumGray;
  
  // Status colors
  Color get success => AppTheme.successGreen;
  Color get warning => AppTheme.warningAmber;
  Color get error => AppTheme.errorRed;
  Color get info => AppTheme.infoBlue;
}

/// Easy access to all typography styles
class AppTypography {
  const AppTypography._();

  // Display styles
  TextStyle get displayLarge => const TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppTheme.charcoal,
    letterSpacing: -0.5,
    fontFamily: 'Aeroport',
  );

  TextStyle get displayMedium => const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: AppTheme.charcoal,
    letterSpacing: -0.25,
    fontFamily: 'Aeroport',
  );

  // Headline styles
  TextStyle get headlineLarge => const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppTheme.charcoal,
    fontFamily: 'Aeroport',
  );

  TextStyle get headlineMedium => const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppTheme.charcoal,
    fontFamily: 'Aeroport',
  );

  TextStyle get headlineSmall => const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: AppTheme.charcoal,
    fontFamily: 'Aeroport',
  );

  // Title styles
  TextStyle get titleLarge => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppTheme.charcoal,
    fontFamily: 'Aeroport',
  );

  TextStyle get titleMedium => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppTheme.darkGray,
    fontFamily: 'Aeroport',
  );

  TextStyle get titleSmall => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppTheme.darkGray,
    fontFamily: 'Aeroport',
  );

  // Body styles
  TextStyle get bodyLarge => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppTheme.darkGray,
    fontFamily: 'Aeroport',
  );

  TextStyle get bodyMedium => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppTheme.darkGray,
    fontFamily: 'Aeroport',
  );

  TextStyle get bodySmall => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppTheme.mediumGray,
    fontFamily: 'Aeroport',
  );

  // Label styles
  TextStyle get labelLarge => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppTheme.darkGray,
    fontFamily: 'Aeroport',
  );

  TextStyle get labelMedium => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: AppTheme.mediumGray,
    fontFamily: 'Aeroport',
  );

  TextStyle get labelSmall => const TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: AppTheme.mediumGray,
    fontFamily: 'Aeroport',
  );
}

/// Easy access to all shadow styles
class AppShadows {
  const AppShadows._();

  List<BoxShadow> get small => [
    const BoxShadow(
      color: AppTheme.shadow,
      blurRadius: 8,
      offset: Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  List<BoxShadow> get medium => [
    const BoxShadow(
      color: AppTheme.shadow,
      blurRadius: 16,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  List<BoxShadow> get large => [
    const BoxShadow(
      color: AppTheme.shadow,
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  List<BoxShadow> get card => [
    const BoxShadow(
      color: AppTheme.shadow,
      blurRadius: 20,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  List<BoxShadow> get button => [
    BoxShadow(
      color: AppTheme.newportPrimary.withValues(alpha: 0.25),
      blurRadius: 12,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  List<BoxShadow> get floating => [
    const BoxShadow(
      color: AppTheme.shadow,
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: 0,
    ),
  ];
}

/// Extension for backward compatibility with color opacity
extension ColorCompatibility on Color {
  /// Helper method to maintain compatibility between old and new Flutter color APIs
  Color withOpacityCompat(double opacity) {
    return withValues(alpha: opacity);
  }
  
  /// Helper to get ARGB values safely
  int get redValue => (toARGB32() >> 16) & 0xFF;
  int get greenValue => (toARGB32() >> 8) & 0xFF;
  int get blueValue => toARGB32() & 0xFF;
}