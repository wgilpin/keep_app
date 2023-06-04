import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keep_app/src/notes.dart';
import 'package:keep_app/src/views/edit.dart';
import 'package:keep_app/src/views/note_card.dart';
import 'package:keep_app/src/views/recommend.dart';

import '../utils/utils.dart';

class DisplayNote extends StatefulWidget {
  DisplayNote(Note note, {this.onChanged, this.onPinned, super.key}) : _note = note;

  late final Note _note;
  final Function()? onChanged;
  final Function(String, bool)? onPinned;

  @override
  State<DisplayNote> createState() => _DisplayNoteState();
}

class _DisplayNoteState extends State<DisplayNote> {
  late Future<List<Map<String, String>>> relatedNotes;
  final _checkController = TextEditingController();
  late bool hasChecklist;

  @override
  initState() {
    super.initState();
    relatedNotes = getRelatedNotes();
    hasChecklist = widget._note.checklist.isNotEmpty;
  }

  void doPinnedChange(String id, bool state) {
    debugPrint('DisplayNote.doPinnedChange');

    setState(() {
      widget._note.isPinned = state;
    });
    widget.onPinned?.call(widget._note.id!, state);
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData media = MediaQuery.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Doofer',
          style: GoogleFonts.philosopher(
            fontSize: 30,
          ),
        ),
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
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 1000,
      ),
      width: 1200,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            NoteCard(
              widget._note,
              onTapped: null,
              onPinned: doPinnedChange,
              interactable: true,
              onChanged: doChanged,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Tooltip(
                  message: 'Add a checklist item',
                  child: IconButton(
                    onPressed: doAddCheck,
                    icon: const Icon(Icons.add_box_outlined),
                  ),
                ),
                Tooltip(
                  message: widget._note.isShared ? 'Stop sharingthis note' : 'Share this note',
                  child: IconButton(
                    onPressed: doShare,
                    icon: Icon(Icons.share, color: widget._note.isShared ? Colors.red[900] : null),
                  ),
                ),
                Tooltip(
                  message: 'Edit this note',
                  child: IconButton(
                    onPressed: doEditCard,
                    icon: const Icon(Icons.edit),
                  ),
                ),
                Tooltip(
                  message: 'Delete note',
                  decoration: BoxDecoration(
                    color: Colors.red[900],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: IconButton(
                      onPressed: () {
                        deleteAfterConfirm(context);
                      },
                      icon: const Icon(Icons.delete)),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  void doEditCard() {
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
  }

  Widget columnView(AsyncSnapshot<Object> snapshot) {
    return SingleChildScrollView(
      child: Column(
        children: [
          mainCard(),
          Wrap(
            children: snapshot.connectionState != ConnectionState.done
                ? [
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 20.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  ]
                : getRelatedColumn(snapshot.data as List<Map<String, String>>),
          ),
        ],
      ),
    );
  }

  Widget fullWidth(AsyncSnapshot<Object> snapshot) {
    return SingleChildScrollView(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Container(alignment: Alignment.topCenter, child: mainCard())),
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
              : getRelatedColumn(snapshot.data as List<Map<String, String>>),
        ),
      ]),
    );
  }

  Future<List<Map<String, String>>> getRelatedNotes() async {
    // return [note, note, note, note, note, note];
    final List<Map<String, String>> related = await Recommender.noteSearch(widget._note, 9, context);
    return related;
  }

  onCardTapped(noteId) async {
    debugPrint("displayNote.onCardTapped");
    widget._note = await getNote(noteId);
    setState(() {
      relatedNotes = getRelatedNotes();
    });
  }

  getRelatedColumn(List<Map<String, String>> related) {
    return related.isNotEmpty
        ? related
            .map(
              (r) => Padding(
                padding: const EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 300,
                  child: SmallNoteCard(
                    r["title"] ?? "Empty Note",
                    onTapped: () => onCardTapped(r["id"]),
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

  void doDelete() {
    debugPrint("DisplayNote.doDelete");
    FirebaseFirestore.instance.collection('notes').doc(widget._note.id!).delete();
    Get.back();
  }

  void deleteAfterConfirm(BuildContext context) {
    // set up the buttons
    Widget cancelButton = TextButton(
      child: const Text("Cancel", style: TextStyle(color: Colors.white)),
      onPressed: () => Get.back(),
    );
    Widget continueButton = TextButton(
      onPressed: doDelete,
      child: const Text("Delete", style: TextStyle(color: Colors.white)),
    );
    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      backgroundColor: Colors.red[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      title: const Text("Are you sure?", style: TextStyle(color: Colors.white)),
      content: const Text("Deleting notes can't be undone?", style: TextStyle(color: Colors.white)),
      actions: [
        cancelButton,
        continueButton,
      ],
    );
    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  void doChanged() {
    debugPrint('DisplayNote.doChanged');

    widget.onChanged?.call();
  }

  void doAddCheck() {
    SimpleDialog dialog = SimpleDialog(
      elevation: 10,
      shadowColor: Colors.black,
      title: const Text("Add checklist item", style: TextStyle(fontSize: 18)),
      backgroundColor: Colors.yellow[100],
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  autofocus: true,
                  onSubmitted: (value) => saveNewItem(),
                  controller: _checkController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'List item',
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: saveNewItem,
              )
            ],
          ),
        ),
      ],
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return dialog;
      },
    );
  }

  void saveNewItem() {
    if (_checkController.text.isNotEmpty) {
      FirebaseFirestore.instance.collection("notes").doc(widget._note.id!).update({
        "checklist": FieldValue.arrayUnion([
          {"title": _checkController.text, "checked": false}
        ])
      }).then((value) {
        setState(() {
          CheckItem newItem = CheckItem.fromTitle(_checkController.text);
          widget._note.checklist.add(newItem);
          _checkController.clear();
        });
        doChanged();
      });
    }
    // addCheckItem();
    Get.back();
  }

  void doShare() {
    // set the shared flag on the note in firebase
    FirebaseFirestore.instance.collection("notes").doc(widget._note.id!).update({"shared": true}).then((value) {
      setState(() {
        widget._note.isShared = true;
      });
      doChanged();
    });
    String url = makeShareURL(widget._note.id!);
    debugPrint('DisplayNote.doShare: $url');
    Clipboard.setData(ClipboardData(text: url));
    Get.snackbar("Note can be shared", "The link has been copied to the clipboard",
        snackPosition: SnackPosition.BOTTOM);
  }
}
