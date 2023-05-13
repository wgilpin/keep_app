import 'package:flutter/material.dart';
import 'package:keep_app/src/notes.dart';
import 'package:keep_app/src/views/note_card.dart';

class CardGrid extends StatelessWidget {
  const CardGrid(List<Note> notes, {super.key}) : _notes = notes;

  final List<Note> _notes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GridView.builder(
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 300,
          childAspectRatio: (1 / .7),
        ),
        itemCount: _notes.length,
        itemBuilder: (BuildContext ctx, index) {
          return Container(
            padding: const EdgeInsets.all(8.0),
            child: NoteCard(_notes[index]),
          );
        },
      ),
    );
  }
}
