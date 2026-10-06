import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFF0A0B10);
  static const card = Color(0xFF14161F);
  static const card2 = Color(0xFF1C1F2D);
  static const stroke = Color(0x14FFFFFF);
  static const text = Color(0xFFF2F4FA);
  static const sub = Color(0xFF8A90A6);
  static const violet = Color(0xFF7C6CFF);
  static const cyan = Color(0xFF22D3EE);
  static const amber = Color(0xFFFFB84D);
  static const red = Color(0xFFFF5C7A);
  static const green = Color(0xFF34D399);
  static const grad = LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [violet, cyan]);
}

TextStyle t(double size,
        {FontWeight w = FontWeight.w500, Color color = C.text, double ls = 0, double? h}) =>
    TextStyle(fontSize: size, fontWeight: w, color: color, letterSpacing: ls, height: h);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(seedColor: C.violet, brightness: Brightness.dark, surface: C.card),
    scaffoldBackgroundColor: C.bg,
  );
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: w));
  return base.copyWith(
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.card2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: b(Colors.transparent),
      enabledBorder: b(Colors.transparent),
      focusedBorder: b(C.violet, 1.6),
      labelStyle: const TextStyle(color: C.sub),
      hintStyle: const TextStyle(color: C.sub),
      prefixIconColor: C.sub,
      suffixIconColor: C.sub,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.card2,
      contentTextStyle: const TextStyle(color: C.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
