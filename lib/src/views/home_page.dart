import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/controllers/note_controller.dart';
import 'package:keep_app/src/notes.dart';
import 'package:keep_app/src/views/card_grid.dart';
import 'package:keep_app/src/views/edit.dart';
import 'package:keep_app/src/views/recommend.dart';

import 'profile.dart';

class HomePage extends StatelessWidget {
  HomePage({Key? key}) : super(key: key);
  final nc = Get.put(NoteController());

  final TextEditingController _searchController = TextEditingController();

  void changed() {
    print("Homepage.changed");
    nc.getData();
  }

  @override
  Widget build(BuildContext context) {
    nc.getData();
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
        child: Obx(() => nc.isLoading.value
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(child: CardGrid(nc.notes, changed))),
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
      nc.getData();
    } else {
      final results = await Recommender.textSearch(_searchController.text, 10, context);
      nc.setData(results);
    }
  }
}
