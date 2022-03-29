import 'package:flutter/material.dart';

class HomeTheme {
  HomeTheme._();

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    backgroundColor: Colors.white,
    primaryColor: Color(0xffCC3333),
    scaffoldBackgroundColor: Color(0xffF7F7F7),
    appBarTheme: AppBarTheme(
      color: Colors.grey.shade400,
      iconTheme: IconThemeData(
        color: Colors.white,
      ),
    ),
    toggleableActiveColor: Color(0xffCC3333),
    colorScheme: ColorScheme.light(
      brightness: Brightness.light,
      primary: Colors.white,
      onPrimary: Colors.black54,
      primaryContainer: Color(0xffF7F7F7),
      secondary: Color(0xff670101),
      onSecondary: Colors.white,
      onBackground: Colors.black,
    ),
    cardTheme: CardTheme(
      color: Colors.grey.shade300,
    ),
    iconTheme: IconThemeData(
      color: Colors.black87,
    ),
    textTheme: TextTheme(
      headline1: TextStyle(
        color: Colors.black87,
      ),
      headline2: TextStyle(
        color: Colors.black87,
      ),
      headline3: TextStyle(
        color: Colors.black87,
      ),
      headline4: TextStyle(
        color: Colors.black87,
      ),
      headline5: TextStyle(
        color: Colors.black87,
        fontFamily: 'NovecentoSans',
        fontSize: 22,
      ),
      headline6: TextStyle(
        color: Color(0xffCC3333),
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
      bodyText1: TextStyle(
        color: Colors.black87,
        fontSize: 16,
      ),
      bodyText2: TextStyle(
        color: Colors.black87,
        fontSize: 12,
      ),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    backgroundColor: Color(0xff222222),
    primaryColor: Color(0xffCC3333),
    scaffoldBackgroundColor: Color(0xff1A1A1A),
    appBarTheme: AppBarTheme(
      color: Colors.white,
      iconTheme: IconThemeData(
        color: Colors.white,
      ),
    ),
    toggleableActiveColor: Color(0xffCC3333),
    colorScheme: ColorScheme.dark(
      brightness: Brightness.dark,
      primary: Color(0xff1A1A1A),
      onPrimary: Color.fromRGBO(255, 255, 255, 0.75),
      primaryContainer: Color(0xff1D1D1D),
      secondary: Color(0xffCC3333),
      onSecondary: Colors.white,
      onBackground: Colors.white,
    ),
    cardTheme: CardTheme(
      color: Color(0xff333333),
    ),
    iconTheme: IconThemeData(
      color: Color.fromRGBO(255, 255, 255, 0.8),
    ),
    textTheme: TextTheme(
      headline1: TextStyle(
        color: Colors.white,
      ),
      headline2: TextStyle(
        color: Colors.white,
      ),
      headline3: TextStyle(
        color: Color.fromRGBO(255, 255, 255, 0.8),
      ),
      headline4: TextStyle(
        color: Color.fromRGBO(255, 255, 255, 0.8),
      ),
      headline5: TextStyle(
        color: Color.fromRGBO(255, 255, 255, 0.8),
        fontFamily: 'NovecentoSans',
        fontSize: 22,
      ),
      headline6: TextStyle(
        color: Color(0xffCC3333),
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
      bodyText1: TextStyle(
        color: Colors.white,
        fontSize: 16,
      ),
      bodyText2: TextStyle(
        color: Color.fromRGBO(255, 255, 255, 0.8),
        fontSize: 12,
      ),
    ),
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
