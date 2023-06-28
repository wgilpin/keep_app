import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keep_app/src/controllers/database.dart';
import 'package:keep_app/src/controllers/notes_controller.dart';
import 'package:keep_app/src/notes.dart';
import 'package:keep_app/src/views/bottom_nav.dart';
import 'package:keep_app/src/views/card_grid.dart';
import 'package:keep_app/src/views/edit_page.dart';
import 'package:keep_app/src/views/left_navigation.dart';
import 'package:keep_app/src/views/recommend.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  bool _loading = false;
  final List<String> _searchResults = [];

  @override
  void initState() {
    super.initState();
    debugPrint("Homepage.initState");
  }

  void doChanged() {
    setState(() {});
  }

  onPinnedNote(String noteId, bool value) async {
    debugPrint("CardGrid.onPinned");
    // write note to firestore
    debugPrint('toggle pinned for $noteId}}');
    await Database().updateNotePinned(noteId, value);
    setState(() {});
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
                  Expanded(child: getStreamGrid()),
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
      setState(() {
        _searchResults.clear();
        _loading = false;
      });
    } else {
      setState(() {
        _loading = true;
      });
      Recommender.textSearch(_searchController.text, 10, context).then((results) {
        setState(() {
          _searchResults.addAll(results.keys.toList());
          _loading = false;
        });
      });
    }
  }

  getStreamGrid() {
    return GetX<NotesController>(
      init: Get.find<NotesController>(),
      builder: (NotesController noteController) {
        if (noteController.notes.value.isNotEmpty) {
          if (_searchResults.isNotEmpty) {
            return SafeArea(
              child: CardGrid(
                noteController.notes.value.where((note) => _searchResults.contains(note.id)).toList(),
                onPinnedNote,
              ),
            );
          }
          return SafeArea(child: CardGrid(noteController.notes.value, onPinnedNote));
        }
        return const Center(child: Text("No notes found"));
      },
    );
  }
}
