import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/controllers/firestore_db.dart';
import 'package:keep_app/src/notes.dart';
import 'package:keep_app/src/views/edit.dart';

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
                      setState(() async {
                        widget._note = note;
                      });
                    }
                  },
                );
              },
              icon: const Icon(Icons.edit))
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Visibility(
              visible: widget._note.title != null,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SelectableText(
                  widget._note.title ?? "Untitled",
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            Visibility(
              visible: widget._note.comment != null,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SelectableText(
                  widget._note.comment ?? "",
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            Visibility(
              visible: widget._note.snippet != null,
              child: Container(
                color: Colors.yellow[600],
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                child: SelectableText(
                  widget._note.snippet ?? "",
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            Visibility(
              visible: widget._note.url != null,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SelectableText(
                  widget._note.url ?? "",
                  style: TextStyle(fontSize: 16, color: Colors.blue[800], decoration: TextDecoration.underline),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
