import 'package:flutter/material.dart';

import 'package:expense_tracker/widgets/expenses.dart';
import 'package:expense_tracker/theme/app_colors.dart';

final _darkColorScheme = ColorScheme.fromSeed(
  brightness: Brightness.dark,
  seedColor: appVioletColor,
  surface: appSurfaceColor,
);

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: _darkColorScheme,
        scaffoldBackgroundColor: appBackgroundColor,
        cardTheme: CardThemeData(
          color: appSurfaceColor,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: appBorderColor),
          ),
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: appTextColor,
          displayColor: appTextColor,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: appSurfaceRaisedColor,
          contentTextStyle: TextStyle(color: appTextColor),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: appSurfaceColor,
          modalBackgroundColor: appSurfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
      ),
      home: const Expenses(),
    ),
  );
}
