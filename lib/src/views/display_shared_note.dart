import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keep_app/src/notes.dart';
import 'package:keep_app/src/utils/layout.dart';
import 'package:keep_app/src/views/login/login_page.dart';
import 'package:keep_app/src/views/login/register_page.dart';
import 'package:keep_app/src/views/note_card.dart';

class DisplaySharedNoted extends StatefulWidget {
  final String noteId;

  const DisplaySharedNoted(this.noteId, {super.key});

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
                onPressed: () => Get.to(LoginPage()),
                child: const Text("Login", style: TextStyle(fontWeight: FontWeight.bold))),
          )
        ],
      ),
      body: FutureBuilder<Object>(
        future: getNote(widget.noteId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint('Snapshot error: ${snapshot.error}');
            return Center(child: Text("Error loading note ${snapshot.error}"));
          }
          if (snapshot.hasData) {
            return SafeArea(
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
                        addVerticalSpace(20),
                        TextButton(
                            onPressed: () => RegisterPage(),
                            child: const Text(
                              "Sign up to Doofer",
                              style: TextStyle(decoration: TextDecoration.underline),
                            )),
                        addVerticalSpace(20),
                        NoteCard(snapshot.data as Note, interactable: false),
                      ],
                    ),
                  )),
            ));
          }
          return const Center(child: Text("Note not found"));
        },
      ),
    );
  }
}
