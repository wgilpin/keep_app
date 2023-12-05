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
    notes.bindStream(Database().noteStream(authCtl.user?.uid ?? ""));
    notesCollection = FirebaseFirestore.instance.collection('notes');
  }

  Note findNoteById(String id) {
    return notesList.firstWhere((note) => note.id == id);
  }

  Future<void> updateChecklist(String id, List<CheckItem> checklist) async {
    await notesCollection.doc(id).update({"checklist": checklist.map((e) => e.toJson()).toList()});
    refresh();
  }

  Future<void> updateNoteFromMap(String id, Map<String, Object?> map) async {
    await notesCollection.doc(id).update(map);
    refresh();
  }

  Future<void> createNoteFromMap(Map<String, Object?> note) async {
    await notesCollection.add(note);
    refresh();
  }
}
