import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF00BFA5);
  static const Color secondary = Color(0xFF263238);
  static const Color background = Color(0xFFF2F5F9);
  static const Color white = Colors.white;
  static const Color orange = Color(0xFFFF9F43);
  static const Color red = Color(0xFFFF6B6B);
  static const Color blue = Color(0xFF54A0FF);
  static const Color textDark = Color(0xFF2D3436);
}

class AppStyles {
  static TextStyle header = GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textDark);
  static TextStyle title = GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark);
  static TextStyle body = GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600);

  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(color: const Color(0xFFE0E5EC).withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10)),
    ],
  );
}