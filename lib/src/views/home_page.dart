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

  // This controller will store the value of the search bar
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: _notesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Scaffold(body: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Text("Loading"));
          }

          return Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                title: const Text('rKyv'),
                actions: <Widget>[
                  Container(
                    // Add padding around the search bar
                    padding: const EdgeInsets.all(4.0),
                    constraints: const BoxConstraints(maxWidth: 270),
                    // Use a Material design search bar
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        // Add a clear button to the search bar
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        ),
                        // Add a search icon or button to the search bar
                        prefixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            // Perform the search here
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15.0),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              body: SafeArea(child: CardGrid(snapshotToNotes(snapshot.data!))),
              bottomNavigationBar: BottomNavigationBar(
                backgroundColor: Colors.yellow[700],
                selectedItemColor: Colors.amber[900],
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
                currentIndex: 0,
                onTap: (index) {
                  if (index == 1) {
                    Get.to(const Profile());
                  }
                },
              ),
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
