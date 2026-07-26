import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryLight = Color(0xFF8B80F0);
  static const Color primaryDark = Color(0xFF5043C4);
  static const Color primarySurface = Color(0xFFEEECFD);

  // Semantic Colors
  static const Color income = Color(0xFF00B894);
  static const Color incomeLight = Color(0xFFE6F9F5);
  static const Color expense = Color(0xFFE17055);
  static const Color expenseLight = Color(0xFFFDF0EC);
  static const Color budget = Color(0xFF0984E3);
  static const Color budgetLight = Color(0xFFE8F4FD);
  static const Color spending = Color(0xFFFDAA3D);
  static const Color spendingLight = Color(0xFFFFF4E3);

  // Light Neutrals
  static const Color background = Color(0xFFF5F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardShadow = Color(0x1A6C5CE7);

  // Light Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFFB0B7C3);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Dark Mode Neutrals ───────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0F0F1A);
  static const Color darkSurface = Color(0xFF1C1C2E);
  static const Color darkSurface2 = Color(0xFF252538);
  static const Color darkDivider = Color(0xFF2A2A3E);

  // Dark Text
  static const Color darkTextPrimary = Color(0xFFF0F0FF);
  static const Color darkTextSecondary = Color(0xFF9BA3B8);
  static const Color darkTextHint = Color(0xFF7A7A9A);

  // Dark primary surface (tinted)
  static const Color darkPrimarySurface = Color(0xFF1E1A3A);

  // Category Colors
  static const Color catFood = Color(0xFFE17055);
  static const Color catSalary = Color(0xFF00B894);
  static const Color catTransport = Color(0xFF0984E3);
  static const Color catBills = Color(0xFFFDAA3D);
  static const Color catFreelance = Color(0xFF6C5CE7);
  static const Color catShopping = Color(0xFFE84393);
  static const Color catHealth = Color(0xFFFF6B6B);
  static const Color catEducation = Color(0xFF74B9FF);
  static const Color catEntertainment = Color(0xFFA29BFE);
  static const Color catSavings = Color(0xFF55EFC4);
  static const Color catOther = Color(0xFF636E72);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C6FF7), Color(0xFF6C5CE7)],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF7C6FF7), Color(0xFF5C4ED4)],
  );

  static const LinearGradient darkPrimaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B80F0), Color(0xFF6C5CE7)],
  );
}
