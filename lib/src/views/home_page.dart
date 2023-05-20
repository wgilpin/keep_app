import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/controllers/note_controller.dart';
import 'package:keep_app/src/notes.dart';
import 'package:keep_app/src/views/card_grid.dart';
import 'package:keep_app/src/views/edit.dart';
import 'package:keep_app/src/views/recommend.dart';

import 'profile.dart';

class HomePage extends StatefulWidget {
  HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  Stream<QuerySnapshot> _notesStream = NoteController.getData();
  Future<List<Note>> _notesList = Future.value([]);

  @override
  void initState() {
    super.initState();
    _notesStream = NoteController.getData();
    _notesList = Future.value([]);
    debugPrint("Homepage.initState");
  }

  void changed() {
    print("Homepage.changed");
    _notesStream = NoteController.getData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('rKyv'),
        actions: <Widget>[
          Container(
            // Add padding around the search bar
            padding: const EdgeInsets.all(6.0),
            constraints: const BoxConstraints(maxWidth: 270),
            // Use a Material design search bar
            child: TextField(
              onSubmitted: (_) {
                doSearch(context);
              },
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                // Add a clear button to the search bar
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    doSearch(context);
                  },
                ),
                // Add a search icon or button to the search bar
                prefixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    doSearch(context);
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
      body: SafeArea(
        child: _searchController.text.isEmpty ? getStreamGrid() : getFutureGrid(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Note newNote = Note();
          Get.to(EditNoteForm(newNote));
        },
        child: const Icon(Icons.add),
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
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            Get.to(const Profile());
          }
        },
      ),
    );
  }

  Future<void> doSearch(BuildContext context) async {
    if (_searchController.text.isEmpty) {
      _notesStream = NoteController.getData();
      setState(() {});
    } else {
      final results = await Recommender.textSearch(_searchController.text, 10, context);
      _notesList = NoteController.setData(results);
      setState(() {});
    }
  }

  getStreamGrid() {
    return StreamBuilder<QuerySnapshot>(
        stream: _notesStream,
        builder: (context, snapshot) {
          debugPrint("Homepage.build ${snapshot.connectionState}");
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading notes"));
          }
          if (snapshot.connectionState == ConnectionState.active) {
            List<Note> notes = snapshot.data!.docs.map((n) => Note.fromSnapshot(n)).toList();
            return SafeArea(child: CardGrid(notes, changed));
          }
          return const Center(child: Text("No notes found"));
        });
  }

  getFutureGrid() {
    return FutureBuilder<List<Note>>(
        future: _notesList,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading notes"));
          }
          if (snapshot.hasData) {
            return SafeArea(child: CardGrid(snapshot.data!, changed));
          }
          return const Center(child: Text("No notes found"));
        });
  }
}
