import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/notes.dart';
import 'package:keep_app/src/views/display_note.dart';
import 'package:keep_app/src/views/note_card.dart';

class CardGrid extends StatelessWidget {
  CardGrid(List<Note> notes, this.onUpdate, this.onPinned, {super.key}) : _notes = notes;

  late final Function()? onUpdate;
  late final Function(String, bool)? onPinned;
  final List<Note> _notes;

  // open the note in a new page when tapped
  onNoteTapped(note) {
    debugPrint("CardGrid.onNoteTapped");
    Get.to(() => DisplayNote(
          note,
          onChanged: doUpdate,
          onPinned: onPinned,
        ));
  }

  @override
  Widget build(BuildContext context) {
    sortNotesByPinned();
    MediaQueryData media = MediaQuery.of(context);
    int numColumns = max(1, media.size.width / 300 ~/ 1);
    debugPrint("numColumns: $numColumns");
    return Scaffold(
      body: MasonryGridView.count(
        crossAxisCount: numColumns,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        itemCount: _notes.length,
        clipBehavior: Clip.hardEdge,
        itemBuilder: (context, index) {
          return Container(
            // constraints: const BoxConstraints(maxHeight: 300,),
            padding: const EdgeInsets.all(8.0),
            child: NoteCard(
              _notes[index],
              onTapped: () => onNoteTapped(_notes[index]),
              onPinned: onPinned,
              interactable: false,
              onChanged: doChange,
            ),
          );
        },
      ),
    );
  }

  void doChange() {
    debugPrint('CardGrid.doChange');
    onUpdate?.call();
  }

  // sort order is pinned notes by update order, then unpinned notes by update order
  void sortNotesByPinned() {
    // 2 lists, pinned and unpinned
    List<Note> pinned = [];
    List<Note> unPinned = [];
    // for each note, add it to the appropriate list
    for (var note in _notes) {
      if (note.isPinned) {
        pinned.add(note);
      } else {
        unPinned.add(note);
      }
    }
    // add
    _notes.clear();
    _notes.addAll(pinned);
    _notes.addAll(unPinned);
  }

  doUpdate() {
    debugPrint('CardGrid.doUpdate');
    onUpdate?.call();
  }
}
