import 'package:flutter/material.dart';

class AppTheme {
  static const Color orange     = Color(0xFFE88B3A);
  static const Color orangeLight= Color(0xFFFFF7F0);
  static const Color orangeBorder= Color(0xFFFDDDB8);
  static const Color gray100    = Color(0xFFF3F4F6);
  static const Color gray200    = Color(0xFFE5E7EB);
  static const Color gray400    = Color(0xFF9CA3AF);
  static const Color gray600    = Color(0xFF6B7280);
  static const Color dark       = Color(0xFF1F2937);
  static const Color green      = Color(0xFF3B6D11);
  static const Color greenLight = Color(0xFFEAF3DE);
  static const Color blue       = Color(0xFF185FA5);
  static const Color blueLight  = Color(0xFFE6F1FB);
  static const Color red        = Color(0xFFA32D2D);
  static const Color redLight   = Color(0xFFFCEBEB);
  static const Color amber      = Color(0xFF854F0B);
  static const Color amberLight = Color(0xFFFAEEDA);

  static ThemeData get theme => ThemeData(
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(seedColor: orange),
    scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: dark,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: dark,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: orange, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFA32D2D), width: 1.5),
      ),
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: orange),
    ),
  );
}