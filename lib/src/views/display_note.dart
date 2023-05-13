import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/controllers/firestore_db.dart';
import 'package:keep_app/src/notes.dart';
import 'package:keep_app/src/views/edit.dart';
import 'package:keep_app/src/views/note_card.dart';

class DisplayNote extends StatefulWidget {
  DisplayNote(Note note, {super.key}) : _note = note;

  Note _note;

  @override
  State<DisplayNote> createState() => _DisplayNoteState();
}

class _DisplayNoteState extends State<DisplayNote> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget._note.title ?? "Note"),
        actions: <Widget>[
          IconButton(
              onPressed: () {
                Get.to(EditNoteForm(widget._note))?.then(
                  (updatedNoteID) async {
                    if (updatedNoteID != null) {
                      // note has been updates, reload it
                      final note = await getNote(updatedNoteID);
                      setState(
                        () async {
                          widget._note = note;
                        },
                      );
                    }
                  },
                );
              },
              icon: const Icon(Icons.edit))
        ],
      ),
      body: Wrap(
        children: [
          SizedBox(
            width: double.infinity,
            child: NoteCard(
              widget._note,
              null,
              showTitle: false,
            ),
          ),
        ],
      ),
    );
  }
}
