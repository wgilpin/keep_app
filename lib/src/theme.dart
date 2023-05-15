import 'package:flutter/material.dart';

ThemeData makeTheme() {
  return ThemeData(
    primarySwatch: Colors.yellow,
    // Define the default brightness and colors.
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.yellow[800],
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      foregroundColor: Colors.yellow[200],
      backgroundColor: Colors.brown[900],
    ),
    // Define the default font family.
    fontFamily: 'Georgia',

    // Define the default `TextTheme`. Use this to specify the default
    // text styling for headlines, titles, bodies of text, and more.
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 72.0, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(fontSize: 36.0, fontFamily: 'Roboto'),
      bodyMedium: TextStyle(fontSize: 14.0, fontFamily: 'Hind'),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.yellow[200],
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Colors.brown[900],
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
      foregroundColor: Colors.brown[700],
    )),
    textButtonTheme: TextButtonThemeData(
        style: ElevatedButton.styleFrom(
      foregroundColor: Colors.brown[900],
    )),
  );
}
