import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const Color neonGreen = Color(0xFFCCFF00);
  static const Color sportOrange = Color(0xFFFF5E00);
  static const Color limeYellow = sportOrange;
  static const Color courtNavy = Color(0xFF121212);
  static const Color raisedNavy = Color(0xFF1E1E1E);

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: neonGreen,
      secondary: sportOrange,
      surface: raisedNavy,
      error: sportOrange,
    ),
    textTheme: GoogleFonts.getTextTheme(
      'Rajdhani',
      ThemeData.dark().textTheme,
    ),
    scaffoldBackgroundColor: courtNavy,
    appBarTheme: const AppBarTheme(
      backgroundColor: courtNavy,
      foregroundColor: Colors.white,
      centerTitle: false,
      elevation: 0,
    ),
    cardColor: raisedNavy,
    dividerColor: Colors.white12,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: raisedNavy,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: neonGreen, width: 1.5),
      ),
      labelStyle: const TextStyle(color: Colors.white70),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: neonGreen,
        foregroundColor: courtNavy,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: limeYellow,
        side: const BorderSide(color: Colors.white24),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: limeYellow,
      foregroundColor: courtNavy,
    ),
  );
}
