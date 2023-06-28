import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keep_app/src/controllers/auth_controller.dart';
import 'package:keep_app/src/controllers/note_controller.dart';
import 'package:keep_app/src/utils/utils.dart';
import 'package:keep_app/src/views/edit_page.dart';
import 'package:keep_app/src/views/home_page.dart';
import 'package:keep_app/src/views/note_card.dart';
import 'package:keep_app/src/views/recommend.dart';

class DisplayNote extends StatefulWidget {
  const DisplayNote(this.noteId, {this.onPinned, super.key});
  final String noteId;
  final Function(String, bool)? onPinned;

  @override
  State<DisplayNote> createState() => _DisplayNoteState();
}

class _DisplayNoteState extends State<DisplayNote> {
  late Future<List<Map<String, String>>> relatedNotes;
  final _checkController = TextEditingController();
  late final NoteController noteCtl;

  @override
  initState() {
    super.initState();
    noteCtl = Get.put<NoteController>(NoteController(widget.noteId, doGetRelated));
  }

  void doPinnedChange(String id, bool state) {
    debugPrint('DisplayNote.doPinnedChange');

    setState(() {
      noteCtl.note?.isPinned = state;
    });
    widget.onPinned?.call(id, state);
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
      body: noteCtl.note == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<Object>(
              future: getRelatedNotes(),
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
        child: GetX<NoteController>(
          init: NoteController(widget.noteId, doGetRelated),
          initState: (_) {},
          builder: (noteCtl) {
            return Column(
              children: [
                NoteCard(
                  noteCtl.note!,
                  onTapped: null,
                  onPinned: doPinnedChange,
                  interactable: true,
                  onChanged: doChanged,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (noteCtl.note!.checklist.isNotEmpty)
                      Tooltip(
                        message: 'Add a checklist item',
                        child: IconButton(
                          onPressed: doAddCheck,
                          icon: const Icon(Icons.add_box_outlined),
                        ),
                      ),
                    Tooltip(
                      message: noteCtl.note!.isShared ? 'Stop sharingthis note' : 'Share this note',
                      child: IconButton(
                        onPressed: doShare,
                        icon: Icon(Icons.share, color: noteCtl.note!.isShared ? Colors.red[900] : null),
                      ),
                    ),
                    Tooltip(
                      message: 'Edit this note',
                      child: IconButton(
                        onPressed: () => doEditCard(),
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
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> doEditCard() async {
    //  if the note is locked by another user, can't edit it
    final uid = Get.find<AuthCtl>().user!.uid;
    final DateTime now = DateTime.now().toUtc();
    if (noteCtl.note!.lockedBy != null) {
      // get current user
      // if locked by me, fine. If someone else, can't edit until saved or 1 hour has passed
      if (noteCtl.note!.lockedBy != uid) {
        // is lockedTime more than 1 hour ago?
        final diff = now.difference(noteCtl.note!.lockedTime!.toDate());
        if (diff.inHours < 1) {
          // less than 1 hour, can't edit
          Get.snackbar('Note locked', 'Locked by another for at most another ${diff.inMinutes} minutes ');
          return;
        }
      }
      //  we can edit. Lock it for current user
      debugPrint('DisplayNote.doEditCard Locked ${noteCtl.note!.id}');
    }
    await FirebaseFirestore.instance.collection('notes').doc(noteCtl.note!.id).update({
      'lockedBy': uid,
      'lockedTime': Timestamp.fromDate(now),
    });
    Get.to(() => EditNoteForm(
          noteCtl.note,
          onChanged: doChanged,
        ))?.then(
      (updatedNoteID) async {
        if (updatedNoteID != null) {
          Get.find<NoteController>().update();
          setState(() {});
          // if the parent widget supplied a callback, call it
          debugPrint("DisplayNote.onPressed");
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
                        child: Row(
                          children: [
                            Text('Loading related notes...'),
                            CircularProgressIndicator(),
                          ],
                        ),
                      ),
                    )
                  ]
                : getRelatedColumn(snapshot.data),
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
                      child: Column(
                        children: [
                          Text('Loading related notes...'),
                          CircularProgressIndicator(),
                        ],
                      ),
                    )),
                  )
                ]
              : getRelatedColumn(snapshot.data),
        ),
      ]),
    );
  }

  Future<List<Map<String, String>>> getRelatedNotes() async {
    // return [note, note, note, note, note, note];

    final List<Map<String, String>> related = await Recommender.noteSearch(widget.noteId, 9, context);
    return related;
  }

  onCardTapped(noteId) async {
    debugPrint("displayNote.onCardTapped");
    Get.off(DisplayNote(noteId));
  }

  getRelatedColumn(snap) {
    const noNotes = [
      Padding(
        padding: EdgeInsets.all(8.0),
        child: Center(
            child: Text(
          "No related notes",
          style: TextStyle(fontSize: 24),
        )),
      )
    ];
    if (snap == null || snap.isEmpty) {
      return noNotes;
    }
    List<Map<String, String>> related = snap as List<Map<String, String>>;
    return related
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
        .toList();
  }

  void doDelete() {
    debugPrint("DisplayNote.doDelete");
    Get.find<NoteController>().delete(noteCtl.note!.id!);
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
    setState(() {});
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
      noteCtl.addCheckItem(_checkController.text);
    }
    // addCheckItem();
    Get.back();
  }

  void doShare() {
    // set the shared flag on the note in firebase
    FirebaseFirestore.instance.collection("notes").doc(noteCtl.note!.id!).update({"shared": true}).then((value) {
      setState(() {
        noteCtl.note!.isShared = true;
      });
      doChanged();
    });
    String url = makeShareURL(noteCtl.note!.id!);
    debugPrint('DisplayNote.doShare: $url');
    Clipboard.setData(ClipboardData(text: url));
    Get.snackbar("Note can be shared", "The link has been copied to the clipboard",
        snackPosition: SnackPosition.BOTTOM);
  }

  Future<void> initNote() async {}

  doGetRelated() async {
    getRelatedNotes().then((_) {
      setState(() {});
      noteCtl.update();
    });
  }
}
