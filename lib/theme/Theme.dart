import 'package:flutter/material.dart';

class HomeTheme {
  HomeTheme._();

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xffCC3333),
    scaffoldBackgroundColor: const Color(0xffF7F7F7),
    appBarTheme: AppBarTheme(
      color: Colors.grey.shade400,
      iconTheme: const IconThemeData(
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.grey.shade300,
    ),
    iconTheme: const IconThemeData(
      color: Colors.black87,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: Colors.black87,
      ),
      displayMedium: TextStyle(
        color: Colors.black87,
      ),
      displaySmall: TextStyle(
        color: Colors.black87,
      ),
      headlineMedium: TextStyle(
        color: Colors.black87,
      ),
      headlineSmall: TextStyle(
        color: Colors.black87,
        fontFamily: 'NovecentoSans',
        fontSize: 22,
      ),
      titleLarge: TextStyle(
        color: Color(0xffCC3333),
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(
        color: Colors.black87,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: Colors.black87,
        fontSize: 12,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return null;
        }
        if (states.contains(WidgetState.selected)) {
          return const Color(0xffCC3333);
        }
        return null;
      }),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return null;
        }
        if (states.contains(WidgetState.selected)) {
          return const Color(0xffCC3333);
        }
        return null;
      }),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return null;
        }
        if (states.contains(WidgetState.selected)) {
          return const Color(0xffCC3333);
        }
        return null;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return null;
        }
        if (states.contains(WidgetState.selected)) {
          return const Color(0xffCC3333);
        }
        return null;
      }),
    ),
    colorScheme: const ColorScheme.light(
      brightness: Brightness.light,
      primary: Colors.white,
      onPrimary: Colors.black54,
      primaryContainer: Color(0xffF7F7F7),
      secondary: Color(0xff670101),
      onSecondary: Colors.white,
      onSurface: Colors.black,
    ).copyWith(surface: Colors.white),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xffCC3333),
    scaffoldBackgroundColor: const Color(0xff1A1A1A),
    appBarTheme: const AppBarTheme(
      color: Colors.white,
      iconTheme: IconThemeData(
        color: Colors.white,
      ),
    ),
    cardTheme: const CardThemeData(
      color: Color(0xff333333),
    ),
    iconTheme: const IconThemeData(
      color: Color.fromRGBO(255, 255, 255, 0.8),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: Colors.white,
      ),
      displayMedium: TextStyle(
        color: Colors.white,
      ),
      displaySmall: TextStyle(
        color: Color.fromRGBO(255, 255, 255, 0.8),
      ),
      headlineMedium: TextStyle(
        color: Color.fromRGBO(255, 255, 255, 0.8),
      ),
      headlineSmall: TextStyle(
        color: Color.fromRGBO(255, 255, 255, 0.8),
        fontFamily: 'NovecentoSans',
        fontSize: 22,
      ),
      titleLarge: TextStyle(
        color: Color(0xffCC3333),
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(
        color: Colors.white,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: Color.fromRGBO(255, 255, 255, 0.8),
        fontSize: 12,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return null;
        }
        if (states.contains(WidgetState.selected)) {
          return const Color(0xffCC3333);
        }
        return null;
      }),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return null;
        }
        if (states.contains(WidgetState.selected)) {
          return const Color(0xffCC3333);
        }
        return null;
      }),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return null;
        }
        if (states.contains(WidgetState.selected)) {
          return const Color(0xffCC3333);
        }
        return null;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return null;
        }
        if (states.contains(WidgetState.selected)) {
          return const Color(0xffCC3333);
        }
        return null;
      }),
    ),
    colorScheme: const ColorScheme.dark(
      brightness: Brightness.dark,
      primary: Color(0xff1A1A1A),
      onPrimary: Color.fromRGBO(255, 255, 255, 0.75),
      primaryContainer: Color(0xff1D1D1D),
      secondary: Color(0xffCC3333),
      onSecondary: Colors.white,
      onSurface: Colors.white,
    ).copyWith(surface: const Color(0xff222222)),
  );
}

Color darken(Color color, [double amount = .1]) {
  assert(amount >= 0 && amount <= 1);

  final hsl = HSLColor.fromColor(color);
  final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));

  return hslDark.toColor();
}

Color lighten(Color color, [double amount = .1]) {
  assert(amount >= 0 && amount <= 1);

  final hsl = HSLColor.fromColor(color);
  final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));

  return hslLight.toColor();
}
