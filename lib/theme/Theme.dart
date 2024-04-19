import 'package:flutter/material.dart';

class HomeTheme {
  HomeTheme._();

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: Color(0xffCC3333),
    scaffoldBackgroundColor: Color(0xffF7F7F7),
    appBarTheme: AppBarTheme(
      color: Colors.grey.shade400,
      iconTheme: IconThemeData(
        color: Colors.white,
      ),
    ),
    cardTheme: CardTheme(
      color: Colors.grey.shade300,
    ),
    iconTheme: IconThemeData(
      color: Colors.black87,
    ),
    textTheme: TextTheme(
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
    ), checkboxTheme: CheckboxThemeData(
 fillColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
 if (states.contains(MaterialState.disabled)) { return null; }
 if (states.contains(MaterialState.selected)) { return Color(0xffCC3333); }
 return null;
 }),
 ), radioTheme: RadioThemeData(
 fillColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
 if (states.contains(MaterialState.disabled)) { return null; }
 if (states.contains(MaterialState.selected)) { return Color(0xffCC3333); }
 return null;
 }),
 ), switchTheme: SwitchThemeData(
 thumbColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
 if (states.contains(MaterialState.disabled)) { return null; }
 if (states.contains(MaterialState.selected)) { return Color(0xffCC3333); }
 return null;
 }),
 trackColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
 if (states.contains(MaterialState.disabled)) { return null; }
 if (states.contains(MaterialState.selected)) { return Color(0xffCC3333); }
 return null;
 }),
 ), colorScheme: ColorScheme.light(
      brightness: Brightness.light,
      primary: Colors.white,
      onPrimary: Colors.black54,
      primaryContainer: Color(0xffF7F7F7),
      secondary: Color(0xff670101),
      onSecondary: Colors.white,
      onBackground: Colors.black,
    ).copyWith(background: Colors.white),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: Color(0xffCC3333),
    scaffoldBackgroundColor: Color(0xff1A1A1A),
    appBarTheme: AppBarTheme(
      color: Colors.white,
      iconTheme: IconThemeData(
        color: Colors.white,
      ),
    ),
    cardTheme: CardTheme(
      color: Color(0xff333333),
    ),
    iconTheme: IconThemeData(
      color: Color.fromRGBO(255, 255, 255, 0.8),
    ),
    textTheme: TextTheme(
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
    ), checkboxTheme: CheckboxThemeData(
 fillColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
 if (states.contains(MaterialState.disabled)) { return null; }
 if (states.contains(MaterialState.selected)) { return Color(0xffCC3333); }
 return null;
 }),
 ), radioTheme: RadioThemeData(
 fillColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
 if (states.contains(MaterialState.disabled)) { return null; }
 if (states.contains(MaterialState.selected)) { return Color(0xffCC3333); }
 return null;
 }),
 ), switchTheme: SwitchThemeData(
 thumbColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
 if (states.contains(MaterialState.disabled)) { return null; }
 if (states.contains(MaterialState.selected)) { return Color(0xffCC3333); }
 return null;
 }),
 trackColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
 if (states.contains(MaterialState.disabled)) { return null; }
 if (states.contains(MaterialState.selected)) { return Color(0xffCC3333); }
 return null;
 }),
 ), colorScheme: ColorScheme.dark(
      brightness: Brightness.dark,
      primary: Color(0xff1A1A1A),
      onPrimary: Color.fromRGBO(255, 255, 255, 0.75),
      primaryContainer: Color(0xff1D1D1D),
      secondary: Color(0xffCC3333),
      onSecondary: Colors.white,
      onBackground: Colors.white,
    ).copyWith(background: Color(0xff222222)),
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
