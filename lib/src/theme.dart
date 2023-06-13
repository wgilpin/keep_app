import 'package:flutter/material.dart';

ThemeData makeTheme() {
  return ThemeData(
    primarySwatch: Colors.yellow,
    // Define the default brightness and colors.
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.yellow[800],
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      foregroundColor: Colors.yellow[200],
      backgroundColor: Colors.brown[700],
      iconSize: 36,
    ),
    // Define the default font family.
    fontFamily: 'Roboto',

    // Define the default `TextTheme`. Use this to specify the default
    // text styling for headlines, titles, bodies of text, and more.
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 72.0, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(fontSize: 36.0, fontFamily: 'RobotoSlab'),
      bodyMedium: TextStyle(fontSize: 14.0, fontFamily: 'Hind'),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      labelStyle: TextStyle(color: Colors.brown[300], fontStyle: FontStyle.italic),
      fillColor: Colors.yellow[200],
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Colors.brown[800],
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
      foregroundColor: Colors.brown[700],
    )),
    textButtonTheme: TextButtonThemeData(
        style: ElevatedButton.styleFrom(
      foregroundColor: Colors.brown[800],
    )),
    iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
      foregroundColor: Colors.brown[700],
    )),
    iconTheme: IconThemeData(
      color: Colors.brown[700],
    ),
    checkboxTheme: CheckboxThemeData(
      checkColor: MaterialStateProperty.all(Colors.yellow[400]),
      fillColor: MaterialStateProperty.all(Colors.brown[700]),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.yellow[800],
      elevation: 5,
      selectedIconTheme: IconThemeData(color: Colors.brown[700]),
      selectedLabelTextStyle: TextStyle(color: Colors.brown[700]),
      unselectedIconTheme: IconThemeData(color: Colors.brown[500]),
      unselectedLabelTextStyle: TextStyle(color: Colors.brown[500]),
    ),
  );
}
