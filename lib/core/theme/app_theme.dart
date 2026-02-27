import 'package:flutter/material.dart';

class AppTheme {
  // Couleurs principales Lucky Day
  static const Color primaryColor   = Color(0xFF1E3A8A); // Bleu foncé
  static const Color secondaryColor = Color(0xFFD4AF37); // Or
  //static const Color accentColor    = Color(0xFFFFD700); // Or brillant
  static const Color accentColor    = Color(0xCCFFAB40); // Or brillant avec transparence
  static const Color blueLight      = Color(0xFF3B82F6);
  static const Color goldLight      = Color(0xFFFFC107);
  static const Color goldDark       = Color(0xFFB8860B);

  // Probabilités
  //static const Color highProbabilityColor   = Color(0xFFFFD700);
  static const Color highProbabilityColor   = Color(0xCCFFAB40);
  static const Color mediumProbabilityColor = Color(0xFF3B82F6);
  static const Color lowProbabilityColor    = Color(0xFF64748B);

  // Neutres
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color cardColor       = Colors.white;
  static const Color textPrimary     = Color(0xFF1E293B);
  static const Color textSecondary   = Color(0xFF64748B);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, blueLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldLight, goldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient blueGoldGradient = LinearGradient(
    colors: [primaryColor, secondaryColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color getProbabilityColor(String type) {
    switch (type.toLowerCase()) {
      case 'high':   return highProbabilityColor;
      case 'medium': return mediumProbabilityColor;
      case 'low':    return lowProbabilityColor;
      default:       return mediumProbabilityColor;
    }
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: textSecondary),
      ),
    );
  }

  // Styles de texte directs (compatibilité)
  static const TextStyle heading1 = TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary);
  static const TextStyle heading2 = TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary);
  static const TextStyle bodyText = TextStyle(fontSize: 14, color: textSecondary);
  static const TextStyle caption  = TextStyle(fontSize: 12, color: textSecondary);
}