// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keep_app/src/controllers/auth_controller.dart';
import 'package:keep_app/src/views/home_page.dart';

class Profile extends StatelessWidget {
  const Profile({super.key});

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
            const SizedBox(height: 40),
            const Padding(
              padding: EdgeInsets.only(top: 20.0),
              child: Text(
                'Profile',
                style: TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
                onPressed: () => doPassword(context),
                style: ElevatedButton.styleFrom(fixedSize: const Size(180, 30)),
                child: const Text('Change Password')),
            const SizedBox(height: 30),
            ElevatedButton(
                onPressed: doLogout,
                style: ElevatedButton.styleFrom(fixedSize: const Size(180, 30)),
                child: const Text('Logout')),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.yellow[700],
        selectedItemColor: Colors.brown[900],
        unselectedItemColor: Colors.grey[500],
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Get.to(const HomePage());
          }
        },
      ),
    );
  }

  void doLogout() {
    Get.find<AuthCtl>().auth.signOut();
  }

  void doPassword(context) {
    TextEditingController emailCtl = TextEditingController();

    SimpleDialog dialog = SimpleDialog(
      elevation: 10,
      shadowColor: Colors.black,
      title: const Text("Reset password", style: TextStyle(fontSize: 18)),
      backgroundColor: Colors.yellow[100],
      children: [
        Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  decoration: InputDecoration(hintText: 'E-mail address'),
                  controller: emailCtl,
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(Icons.send),
                      onPressed: () => sendPasswordCode(emailCtl.text),
                      label: Text("Send me a code"),
                    ),
                  ],
                )
              ],
            )),
      ],
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return dialog;
      },
    );
  }

  void sendPasswordCode(email) {
    final bool emailValid = GetUtils.isEmail(email);
    if (!emailValid) {
      Get.snackbar("Invalid Email", "You must be supply a valid email address",
          snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 5));
      return;
    }
    Get.find<AuthCtl>().auth.sendPasswordResetEmail(email: email);
    Get.back();
    Get.snackbar("Check your inbox", "If that email matches your login email, you will receive a password reset code.",
        snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 5));
  }
}
