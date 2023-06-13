import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keep_app/src/controllers/note_controller.dart';
import 'package:keep_app/src/notes.dart';
import 'package:keep_app/src/views/bottom_nav.dart';
import 'package:keep_app/src/views/card_grid.dart';
import 'package:keep_app/src/views/edit.dart';
import 'package:keep_app/src/views/left_navigation.dart';
import 'package:keep_app/src/views/recommend.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  Stream<QuerySnapshot> _notesStream = NoteController.getData();
  Future<List<Note>> _notesList = Future.value([]);
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _notesStream = NoteController.getData();
    _notesList = Future.value([]);
    debugPrint("Homepage.initState");
  }

  void doChanged() {
    _notesStream = NoteController.getData();
    setState(() {});
  }

  onPinnedNote(String noteId, bool value) async {
    debugPrint("CardGrid.onPinned");
    // write note to firestore
    debugPrint('toggle pinned for $noteId}}');
    await FirebaseFirestore.instance.collection("notes").doc(noteId).update({"isPinned": value});
    setState(() {
      _notesStream = NoteController.getData();
    });
  }

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
        actions: <Widget>[
          Container(
            // Add padding around the search bar
            padding: const EdgeInsets.only(top: 6.0, right: 6.0, bottom: 6.0, left: 6.0),
            constraints: const BoxConstraints(maxWidth: 240),
            // Use a Material design search bar
            child: TextField(
              textAlignVertical: TextAlignVertical.bottom,
              onSubmitted: (_) {
                doSearch(context);
              },
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                // Add a clear button to the search bar
                suffixIconColor: Colors.brown,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    doSearch(context);
                  },
                ),
                // Add a search icon or button to the search bar
                prefixIconColor: Colors.brown,
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Row(
                children: [
                  if (isWide) const LeftNavigation(0),
                  Expanded(child: (_searchController.text.isEmpty ? getStreamGrid() : getFutureGrid())),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Note newNote = Note();
          Get.to(() => EditNoteForm(newNote));
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: !isWide ? const BottomNav(0) : null,
    );
  }

  Future<void> doSearch(BuildContext context) async {
    if (_searchController.text.isEmpty) {
      _notesStream = NoteController.getData();
      setState(() {});
    } else {
      setState(() {
        _loading = true;
      });
      Recommender.textSearch(_searchController.text, 10, context).then((results) {
        _notesList = NoteController.setData(results.keys.toList());
        setState(() {
          _loading = false;
        });
      });
    }
  }

  getStreamGrid() {
    return StreamBuilder<QuerySnapshot>(
        stream: _notesStream,
        builder: (context, snapshot) {
          debugPrint('Homepage streambuilder rebuild');

          debugPrint("Homepage.build ${snapshot.connectionState}");
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint('Snapshot error: ${snapshot.error}');
            return const Center(child: Text("Error loading notes"));
          }
          if (snapshot.connectionState == ConnectionState.active) {
            List<Note> notes = snapshot.data!.docs.map((n) => Note.fromSnapshot(n)).toList();
            return SafeArea(child: CardGrid(notes, doChanged, onPinnedNote));
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
            debugPrint('Snapshot error: ${snapshot.error}');
            return const Center(child: Text("Error loading notes"));
          }
          if (snapshot.hasData) {
            return SafeArea(child: CardGrid(snapshot.data!, doChanged, onPinnedNote));
          }
          return const Center(child: Text("No notes found"));
        });
  }
}
