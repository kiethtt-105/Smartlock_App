import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const bg = Color(0xFF1C1C1E);
  static const card = Color(0xFF2A2A2E);
  static const divider = Color(0xFF3A3A3E);
  static const blue = Color(0xFF2F6BFF);
  static const red = Color(0xFFFF2A00);
  static const green = Color(0xFF30D158);
  static const textSecondary = Color(0xFF8E8E93);
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.blue,
    onPrimary: Colors.white, // mặc định M3 là chữ tím sẫm, khó đọc trên nền xanh
    secondary: AppColors.green,
    onSecondary: Colors.black,
    error: AppColors.red,
    onError: Colors.white,
    surface: AppColors.card,
    onSurface: Colors.white,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.divider,
    outlineVariant: AppColors.divider,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: scheme,
    dividerColor: AppColors.divider,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
  );
}