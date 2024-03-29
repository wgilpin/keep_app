// ignore_for_file: prefer_const_constructors
// from : https://www.youtube.com/watch?v=-H-T_BSgfOE&t=646s

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keep_app/src/controllers/auth_controller.dart';
import 'package:keep_app/src/views/edit_page.dart';
import 'package:keep_app/src/views/home_page.dart';

import 'register_page.dart';

class LoginPage extends GetWidget<AuthCtl> {
  final TextEditingController emailCtl = TextEditingController();
  final TextEditingController passwordCtl = TextEditingController();

  final Map<String, String>? editArgs;

  LoginPage({this.editArgs, super.key});

  void showSnack(text) => Get.snackbar('Error', text,
      icon: Icon(
        Icons.warning,
        color: Colors.red,
      ),
      snackPosition: SnackPosition.BOTTOM);

  Future<void> doLogin() async {
    // load creds from env file for testing
    late String email;
    late String pwd;
    await dotenv.load(fileName: "testing.env").then((value) {
      email = dotenv.env['TEST_EMAIL']!;
      pwd = dotenv.env['TEST_PWD']!;
    }).onError((error, stackTrace) {
      debugPrint('dotenv load error: $error');
    });

    emailCtl.text = emailCtl.text.isEmpty ? email : emailCtl.text;
    passwordCtl.text = passwordCtl.text.isEmpty ? pwd : passwordCtl.text;

    if (!GetUtils.isEmail(emailCtl.text)) {
      showSnack('Not a valid email address');
      return;
    }
    await controller.login(emailCtl.text, passwordCtl.text);
    if (controller.user != null) {
      if (editArgs == null) {
        // logged in and no edit args
        Get.offAll(HomePage());
      } else {
        // logged in and edit args present so go to edit page
        Get.offAll(EditNoteForm(
          null,
          title: editArgs?["title"],
          snippet: editArgs?["snippet"],
          comment: editArgs?["comment"],
          url: editArgs?["url"],
          iFrame: true,
        ));
      }
    } else {
      // not logg
      Get.offAll(LoginPage());
    }
  }

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
          backgroundColor: Theme.of(context).primaryColorDark,
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
                      "Login in to Doofer",
                      style: const TextStyle(fontSize: 24),
                    ),
                    SizedBox(height: 40),
                    TextFormField(
                      decoration: InputDecoration(hintText: 'Email'),
                      controller: emailCtl,
                      onFieldSubmitted: (_) => doLogin(),
                    ),
                    SizedBox(height: 40),
                    TextFormField(
                      decoration: InputDecoration(hintText: 'Password'),
                      controller: passwordCtl,
                      obscureText: true,
                      onFieldSubmitted: (_) => doLogin(),
                    ),
                    SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: doLogin,
                      style: ElevatedButton.styleFrom(
                          fixedSize: const Size(180, 30), backgroundColor: Theme.of(context).primaryColorLight),
                      child: Text(
                        'Log in',
                      ),
                    ),
                    SizedBox(height: 30),
                    Text(
                      "or",
                      style: const TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 30),
                    TextButton(
                      onPressed: () {
                        Get.to(() => RegisterPage());
                      },
                      child: Text('Register', style: TextStyle(decoration: TextDecoration.underline)),
                    ),
                  ],
                )),
          ),
        ));
  }
}
