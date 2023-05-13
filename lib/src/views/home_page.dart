import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/controllers/auth_controller.dart';
import 'package:keep_app/src/notes.dart';
import 'package:keep_app/src/views/card_grid.dart';
import 'package:keep_app/src/views/edit.dart';

import 'profile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // final uid = Get.find<AuthCtl>().user!.uid;
  final Stream<QuerySnapshot> _notesStream =
      FirebaseFirestore.instance.collection('notes').orderBy('created').snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: _notesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Scaffold(body: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: const Text("Loading"));
          }

          return Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                title: const Text('rKyv'),
                actions: <Widget>[
                  IconButton(
                      onPressed: () {
                        Get.to(const Profile());
                      },
                      icon: const Icon(Icons.person))
                ],
              ),
              body: SafeArea(child: CardGrid(snapshotToNotes(snapshot.data!))),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  Note newNote = Note();
                  Get.to(EditNoteForm(newNote));
                },
                child: const Icon(Icons.add),
              ));
        });
  }

  getNotesStream() async {
    final uid = Get.find<AuthCtl>().user!.uid;
    return FirebaseFirestore.instance.collection('notes').orderBy('created').snapshots();
    // var data = await FirebaseFirestore.instance.collection('notes').orderBy('created').get();
    // setState(() {
    //   _notes = List.from(data.docs.map(Note.fromSnapshot));
    // });
  }

  List<Note> snapshotToNotes(QuerySnapshot<Object?> querySnapshot) {
    return List.from(querySnapshot.docs.map(Note.fromSnapshot));
  }
}
