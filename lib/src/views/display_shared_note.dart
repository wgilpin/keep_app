import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keep_app/src/notes.dart';
import 'package:keep_app/src/views/login/login_page.dart';
import 'package:keep_app/src/views/login/register_page.dart';
import 'package:keep_app/src/views/note_card.dart';

class DisplaySharedNoted extends StatefulWidget {
  final Note note;

  const DisplaySharedNoted(this.note, {super.key});

  @override
  State<DisplaySharedNoted> createState() => _DisplaySharedNotedState();
}

class _DisplaySharedNotedState extends State<DisplaySharedNoted> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Doofer',
          style: GoogleFonts.philosopher(
            fontSize: 30,
            color: Colors.brown[900],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(Colors.brown[700]!),
                  foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                ),
                onPressed: () => Get.to(() => LoginPage()),
                child: const Text("Login", style: TextStyle(fontWeight: FontWeight.bold))),
          )
        ],
      ),
      body: SafeArea(
          child: Align(
        alignment: Alignment.topCenter,
        child: Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    "A note has been shared with you by a Doofer",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                      onPressed: () => RegisterPage(),
                      child: const Text(
                        "Sign up to Doofer",
                        style: TextStyle(decoration: TextDecoration.underline),
                      )),
                  const SizedBox(height: 20),
                  NoteCard(widget.note, interactable: false),
                ],
              ),
            )),
      )),
    );
  }
}
