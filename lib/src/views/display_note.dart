import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/notes.dart';
import 'package:keep_app/src/views/edit.dart';
import 'package:keep_app/src/views/note_card.dart';

class DisplayNote extends StatefulWidget {
  DisplayNote(Note note, this.onChanged, {super.key}) : _note = note;

  Note _note;
  Function? onChanged;

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
                      () {
                        widget._note = note;
                      },
                    );
                    // if the parent widget supplied a callback, call it
                    print("DisplayNote.onPressed");
                    widget.onChanged?.call();
                  }
                },
              );
            },
            icon: const Icon(Icons.edit),
            iconSize: 36,
          ),
        ],
      ),
      body: Wrap(
        children: [
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: NoteCard(
                widget._note,
                null,
                showTitle: false,
                showHtml: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
