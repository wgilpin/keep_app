// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keep_app/src/controllers/auth_controller.dart';
import 'package:keep_app/src/controllers/notes_controller.dart';
import 'package:keep_app/src/notes.dart';
import 'package:keep_app/src/views/bottom_nav.dart';
import 'package:keep_app/src/views/left_navigation.dart';
import 'package:keep_app/src/views/login/login_page.dart';
import 'package:to_csv/to_csv.dart' as export_csv;

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    MediaQueryData media = MediaQuery.of(context);
    final isWide = media.size.width > 800;

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
      body: Row(
        children: [
          if (isWide) const LeftNavigation(1),
          Expanded(
            child: Center(
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
                      style: ElevatedButton.styleFrom(
                          fixedSize: const Size(180, 30), backgroundColor: Theme.of(context).primaryColorLight),
                      child: const Text('Change Password')),
                  const SizedBox(height: 30),
                  ElevatedButton(
                      onPressed: doLogout,
                      style: ElevatedButton.styleFrom(
                          fixedSize: const Size(180, 30), backgroundColor: Theme.of(context).primaryColorLight),
                      child: const Text('Logout')),
                  const SizedBox(height: 30),
                  ElevatedButton(
                      onPressed: doDownload,
                      style: ElevatedButton.styleFrom(
                          fixedSize: const Size(180, 30), backgroundColor: Theme.of(context).primaryColorLight),
                      child: const Text('Download my data')),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: !isWide ? BottomNav(1) : null,
    );
  }

  Future<void> doLogout() async {
    await Get.find<AuthCtl>().auth.signOut();
    Get.to(() => LoginPage());
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
                      onPressed: () => sendPasswordChangeLink(emailCtl.text),
                      label: Text("Send me a link"),
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColorLight),
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

  void sendPasswordChangeLink(email) {
    final bool emailValid = GetUtils.isEmail(email);
    if (!emailValid) {
      Get.snackbar("Invalid Email", "You must be supply a valid email address",
          snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 5));
      return;
    }
    Get.find<AuthCtl>().auth.sendPasswordResetEmail(email: email);
    Get.back();
    Get.snackbar("Check your inbox", "If that email matches your login email, you will receive a password reset link.",
        snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 5));
  }

  Future<void> doDownload() async {
    // TODO: test on mobile
    try {
      List<Note> notes = Get.find<NotesController>().notes.value;
      List<List<String>> res;
      res = notes
          .map((n) => [
                n.id ?? "",
                n.title ?? "",
                n.comment ?? "",
                n.snippet ?? "",
                n.url ?? "",
                n.created.toString(),
              ])
          .toList();
      export_csv.myCSV(["ID", "Title", "Comment", "Snippet", "URL", "Created"], res);
      Get.snackbar("Downloading", "Check your downloads folder");
    } on Exception catch (e) {
      Get.snackbar("Error preparing data", e.toString(),
          duration: const Duration(seconds: 5), snackPosition: SnackPosition.BOTTOM);
    }
  }
}
