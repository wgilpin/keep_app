import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/controllers/auth_controller.dart';
import 'package:keep_app/src/controllers/database.dart';
import 'package:keep_app/src/notes.dart';

class NotesController extends GetxController {
  static final authCtl = Get.find<AuthCtl>();
  Rx<List<Note>> notes = Rx<List<Note>>([]);
  List<Note> get notesList => notes.value;
  late final CollectionReference notesCollection;

  @override
  void onInit() {
    super.onInit();
    doFetch();
    notesCollection = FirebaseFirestore.instance.collection('notes');
  }

  /// Fetch the notes from the database
  doFetch() {
    notes.bindStream(Database().noteStream(authCtl.user?.uid ?? ""));
  }

  Note findNoteById(String id) {
    return notesList.firstWhere((note) => note.id == id);
  }

  /// Update the note with the given id with the given title and content
  Future<void> updateChecklist(String id, List<CheckItem> checklist) async {
    await notesCollection.doc(id).update({"checklist": checklist.map((e) => e.toJson()).toList()});
    refresh();
  }

  /// Update the note with the given id with the given map content
  Future<void> updateNoteFromMap(String id, Map<String, Object?> map) async {
    await notesCollection.doc(id).update(map);
    refresh();
  }

  /// Factory method to create a new note from a map
  Future<void> createNoteFromMap(Map<String, Object?> note) async {
    await notesCollection.add(note);
    refresh();
  }
}
