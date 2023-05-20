import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/controllers/auth_controller.dart';
import 'package:keep_app/src/notes.dart';

class NoteController {
  static final authCtl = Get.find<AuthCtl>();

  static Future<List<Note>> getData() async {
    try {
      final List<Note> notes = [];
      final db = FirebaseFirestore.instance;
      String uid = authCtl.user!.uid;
      if (uid.isNotEmpty) {
        QuerySnapshot snap = await db.collection('notes').where("user", isEqualTo: db.doc("/users/$uid")).get();
        for (var note in snap.docs) {
          notes.add(Note.fromSnapshot(note));
        }
        return notes;
      } else {
        Get.snackbar("Error Loading", "User not logged in");
        return [];
      }
    } catch (e) {
      Get.snackbar("Error Loading", e.toString());
      return [];
    }
  }

  static Future<List<Note>> setData(List<String> noteIds) async {
    final List<Note> notes = [];
    for (var id in noteIds) {
      final note = await getNote(id);
      notes.add(note);
    }
    return notes;
  }
}
