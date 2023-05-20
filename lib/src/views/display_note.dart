import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/notes.dart';
import 'package:keep_app/src/views/edit.dart';
import 'package:keep_app/src/views/note_card.dart';
import 'package:keep_app/src/views/recommend.dart';

class DisplayNote extends StatefulWidget {
  DisplayNote(Note note, this.onChanged, {super.key}) : _note = note;

  Note _note;
  Function? onChanged;
  Function? onSmallCardTap;

  @override
  State<DisplayNote> createState() => _DisplayNoteState();
}

class _DisplayNoteState extends State<DisplayNote> {
  late Future<List<Note>> relatedNotes;

  @override
  initState() {
    super.initState();
    relatedNotes = getRelatedNotes();
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData media = MediaQuery.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "rKyv",
          style: TextStyle(fontSize: 24),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              Get.to(EditNoteForm(widget._note))?.then(
                (updatedNoteID) async {
                  if (updatedNoteID != null) {
                    // note has been updated, reload it
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
      body: FutureBuilder<Object>(
          future: relatedNotes,
          builder: (context, snapshot) {
            return SizedBox(
                width: min(1200, media.size.width),
                child: media.size.width < 1200 ? columnView(snapshot) : fullWidth(snapshot));
          }),
    );
  }

  Widget mainCard() {
    return Wrap(
      children: [
        Container(
          constraints: const BoxConstraints(
            maxWidth: 1000,
          ),
          width: 1200,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: NoteCard(
              widget._note,
              null,
              showTitle: true,
              showHtml: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget columnView(AsyncSnapshot<Object> snapshot) {
    return Column(
      children: [
        mainCard(),
        Expanded(
          child: Wrap(
            children: snapshot.connectionState != ConnectionState.done
                ? [
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 20.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  ]
                : getRelatedColumn(snapshot.data as List<Note>),
          ),
        ),
      ],
    );
  }

  Widget fullWidth(AsyncSnapshot<Object> snapshot) {
    return Flex(direction: Axis.horizontal, children: [
      Expanded(child: Align(alignment: Alignment.topCenter, child: mainCard())),
      Column(
        children: snapshot.connectionState != ConnectionState.done
            ? [
                const SizedBox(
                  width: 324,
                  child: Center(
                      child: Padding(
                    padding: EdgeInsets.only(top: 20.0),
                    child: CircularProgressIndicator(),
                  )),
                )
              ]
            : getRelatedColumn(snapshot.data as List<Note>),
      ),
    ]);
  }

  Future<List<Note>> getRelatedNotes() async {
    // return [note, note, note, note, note, note];
    final List<String> ids = await Recommender.noteSearch(widget._note, 9, context);
    debugPrint("related notes : $ids");
    final promises = [
      for (var i in ids)
        if (i != widget._note.id) getNote(i)
    ];
    // final promises = ids.map((id) => getNote(id));
    return Future.wait(promises);
  }

  onCardTapped(note) {
    print("displayNote.onCardTapped");
    setState(() {
      widget._note = note;
      relatedNotes = getRelatedNotes();
    });
  }

  getRelatedColumn(List<Note> related) {
    return related.isNotEmpty
        ? related
            .map(
              (n) => Padding(
                padding: const EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 300,
                  child: NoteCard(
                    n,
                    null,
                    onTapped: () => onCardTapped(n),
                    isSmall: true,
                  ),
                ),
              ),
            )
            .toList()
        : [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(
                  child: Text(
                "No related notes",
                style: TextStyle(fontSize: 24),
              )),
            )
          ];
  }
}
