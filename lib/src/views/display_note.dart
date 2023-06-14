import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keep_app/src/controllers/auth_controller.dart';
import 'package:keep_app/src/notes.dart';
import 'package:keep_app/src/views/edit_page.dart';
import 'package:keep_app/src/views/home_page.dart';
import 'package:keep_app/src/views/note_card.dart';
import 'package:keep_app/src/views/recommend.dart';

import '../utils/utils.dart';

class DisplayNote extends StatefulWidget {
  const DisplayNote(Note note, {this.onChanged, this.onPinned, super.key}) : _initialNote = note;

  final Note _initialNote;
  final Function()? onChanged;
  final Function(String, bool)? onPinned;

  @override
  State<DisplayNote> createState() => _DisplayNoteState();
}

class _DisplayNoteState extends State<DisplayNote> {
  late Future<List<Map<String, String>>> relatedNotes;
  final _checkController = TextEditingController();
  late bool hasChecklist;
  late Note _note;

  @override
  initState() {
    super.initState();
    _note = widget._initialNote;
    relatedNotes = getRelatedNotes();
    hasChecklist = _note.checklist.isNotEmpty;
  }

  void doPinnedChange(String id, bool state) {
    debugPrint('DisplayNote.doPinnedChange');

    setState(() {
      _note.isPinned = state;
    });
    widget.onPinned?.call(_note.id!, state);
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData media = MediaQuery.of(context);
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () {
            Get.to(() => const HomePage());
          },
          child: Text(
            'Doofer',
            style: GoogleFonts.philosopher(
              fontSize: 30,
            ),
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
              _note,
              onTapped: null,
              onPinned: doPinnedChange,
              interactable: true,
              onChanged: doChanged,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!hasChecklist)
                  Tooltip(
                    message: 'Add a checklist item',
                    child: IconButton(
                      onPressed: doAddCheck,
                      icon: const Icon(Icons.add_box_outlined),
                    ),
                  ),
                Tooltip(
                  message: _note.isShared ? 'Stop sharingthis note' : 'Share this note',
                  child: IconButton(
                    onPressed: doShare,
                    icon: Icon(Icons.share, color: _note.isShared ? Colors.red[900] : null),
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

  Future<void> doEditCard() async {
    //  if the note is locked by another user, can't edit it
    final uid = Get.find<AuthCtl>().user!.uid;
    final DateTime now = DateTime.now().toUtc();
    if (_note.lockedBy != null) {
      // get current user
      // if locked by me, fine. If someone else, can't edit until saved or 1 hour has passed
      if (_note.lockedBy != uid) {
        // is lockedTime more than 1 hour ago?
        final diff = now.difference(_note.lockedTime!.toDate());
        if (diff.inHours < 1) {
          // less than 1 hour, can't edit
          Get.snackbar('Note locked', 'Locked by another for at most another ${diff.inMinutes} minutes ');
          return;
        }
      }
      //  we can edit. Lock it for current user
      debugPrint('DisplayNote.doEditCard Locked ${_note.id}');
    }
    await FirebaseFirestore.instance.collection('notes').doc(_note.id).update({
      'lockedBy': uid,
      'lockedTime': Timestamp.fromDate(now),
    });
    Get.to(() => EditNoteForm(
          _note,
          onChanged: doChanged,
        ))?.then(
      (updatedNoteID) async {
        if (updatedNoteID != null) {
          // note has been updated, reload it
          final note = await getNote(updatedNoteID);
          setState(
            () {
              _note = note;
            },
          );
          // if the parent widget supplied a callback, call it
          debugPrint("DisplayNote.onPressed");
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
    final List<Map<String, String>> related = await Recommender.noteSearch(_note, 9, context);
    return related;
  }

  onCardTapped(noteId) async {
    debugPrint("displayNote.onCardTapped");
    _note = await getNote(noteId);
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
    FirebaseFirestore.instance.collection('notes').doc(_note.id!).delete();
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
    setState(() {
      hasChecklist = _note.checklist.isNotEmpty;
    });
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
      FirebaseFirestore.instance.collection("notes").doc(_note.id!).update({
        "checklist": FieldValue.arrayUnion([
          {"title": _checkController.text, "checked": false}
        ])
      }).then((value) {
        setState(() {
          CheckItem newItem = CheckItem.fromTitle(_checkController.text);
          _note.checklist.add(newItem);
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
    FirebaseFirestore.instance.collection("notes").doc(_note.id!).update({"shared": true}).then((value) {
      setState(() {
        _note.isShared = true;
      });
      doChanged();
    });
    String url = makeShareURL(_note.id!);
    debugPrint('DisplayNote.doShare: $url');
    Clipboard.setData(ClipboardData(text: url));
    Get.snackbar("Note can be shared", "The link has been copied to the clipboard",
        snackPosition: SnackPosition.BOTTOM);
  }
}
