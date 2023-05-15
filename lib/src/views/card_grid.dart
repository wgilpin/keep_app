import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/notes.dart';
import 'package:keep_app/src/views/display_note.dart';
import 'package:keep_app/src/views/note_card.dart';

class CardGrid extends StatelessWidget {
  CardGrid(List<Note> notes, this.onUpdate, {super.key}) : _notes = notes;

  Function()? onUpdate;
  final List<Note> _notes;

  onNoteTapped(note) {
    print("CardGrid.onNoteTapped");
    Get.to(DisplayNote(note, onUpdate));
  }

  @override
  Widget build(BuildContext context) {
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
              20,
              onTapped: () => onNoteTapped(_notes[index]),
              showHtml: true,
            ),
          );
        },
      ),
    );
  }
}
