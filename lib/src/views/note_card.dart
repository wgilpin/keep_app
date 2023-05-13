import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/notes.dart';
import 'package:keep_app/src/views/display_note.dart';

class NoteCard extends StatelessWidget {
  final Note _note;

  const NoteCard(this._note, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
        color: Colors.yellow[200],
        child: InkWell(
          onTap: () {
            Get.to(DisplayNote(_note));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Visibility(
                visible: _note.title != null,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _note.title ?? "Untitled",
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              Visibility(
                visible: _note.comment != null,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _note.comment ?? "",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              Visibility(
                visible: _note.snippet != null,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _note.snippet ?? "",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ));
  }
}
