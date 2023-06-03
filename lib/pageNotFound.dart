// ignore_for_file: unnecessary_const

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keep_app/src/utils/utils.dart';
import 'package:keep_app/src/views/login/login_page.dart';

class PageNotFound extends StatelessWidget {
  const PageNotFound({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Doofer',
          style: GoogleFonts.philosopher(
            fontSize: 30,
          ),
        ),
      ),
      body: Center(
        child: Column(
          children: [
            addVerticalSpace(60),
            const Text(
              "That link didn't work",
              style: TextStyle(fontSize: 24),
            ),
            addVerticalSpace(20),
            const Text(
              "It might have expired.",
              style: TextStyle(fontSize: 20),
            ),
            addVerticalSpace(40),
            const Text(
              "To login or register, click here",
              style: TextStyle(fontSize: 20),
            ),
            addVerticalSpace(20),
            ElevatedButton(
              onPressed: () => Get.to(LoginPage()),
              child: const Text("Login"),
            )
          ],
        ),
      ),
    );
  }
}
