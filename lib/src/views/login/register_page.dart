// ignore_for_file: prefer_const_constructors
// from : https://blog.logrocket.com/implementing-firebase-authentication-in-a-flutter-app/

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keep_app/src/controllers/auth_controller.dart';

class RegisterPage extends GetWidget<AuthCtl> {
  final TextEditingController emailCtl = TextEditingController();
  final TextEditingController passwordCtl = TextEditingController();
  final TextEditingController passwordCtl2 = TextEditingController();

  RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            'Doofer',
            style: GoogleFonts.philosopher(
              fontSize: 30,
            ),
          ),
        ),
        body: Center(
          child: SizedBox(
            width: 400,
            child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      "Create a Doofer account",
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 40),
                    TextFormField(
                      decoration: InputDecoration(hintText: 'Email'),
                      controller: emailCtl,
                    ),
                    const SizedBox(height: 40),
                    TextFormField(
                      decoration: InputDecoration(hintText: 'Password'),
                      controller: passwordCtl,
                      obscureText: true,
                    ),
                    const SizedBox(height: 40),
                    TextFormField(
                      decoration: InputDecoration(hintText: 'Confirm password'),
                      controller: passwordCtl2,
                      obscureText: true,
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: validate,
                      child: Text(
                        'Sign Up',
                      ),
                    ),
                  ],
                )),
          ),
        ));
  }

  void showSnack(text) => Get.snackbar('Error', text,
      icon: Icon(
        Icons.warning,
        color: Colors.red,
      ),
      snackPosition: SnackPosition.BOTTOM);

  void validate() {
    if (passwordCtl.text != passwordCtl2.text) {
      showSnack('Passwords do not match or are shorter than 7 characters');
      return;
    }
    if (passwordCtl.text.length < 7) {
      showSnack('Password needs to be longer than 7 characters');
      return;
    }
    if (!GetUtils.isEmail(emailCtl.text)) {
      showSnack('Not a valid email address');
      return;
    }
    controller.createUser(emailCtl.text, passwordCtl.text);
    Get.back();
  }
}
