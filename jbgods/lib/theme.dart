import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const brandRed = Color(0xFFE30613);

final lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: brandRed,
  scaffoldBackgroundColor: Colors.white,
  dividerColor: Colors.black12,
  textTheme: GoogleFonts.interTextTheme(
    const TextTheme(
      headlineMedium: TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
      bodyMedium: TextStyle(color: Colors.black),
    ),
  ),
  appBarTheme: const AppBarTheme(backgroundColor: Colors.white),
  colorScheme: ColorScheme.light(
    primary: brandRed, surface: Colors.white, onPrimary: Colors.white,
    secondary: Colors.black, onSecondary: Colors.white,
  ),
);

final darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: brandRed,
  scaffoldBackgroundColor: Colors.black,
  dividerColor: Colors.white24,
  textTheme: GoogleFonts.interTextTheme(
    const TextTheme(
      headlineMedium: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
    ),
  ),
  appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
  colorScheme: ColorScheme.dark(
    primary: brandRed, surface: Colors.black, onPrimary: Colors.white,
    secondary: Colors.white, onSecondary: Colors.black,
  ),
);