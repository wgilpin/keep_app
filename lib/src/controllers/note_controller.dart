import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/controllers/auth_controller.dart';
import 'package:keep_app/src/notes.dart';

class NoteController {
  static final authCtl = Get.find<AuthCtl>();

  static Stream<QuerySnapshot> getData() {
    try {
      final db = FirebaseFirestore.instance;
      String uid = authCtl.user!.uid;
      if (uid.isNotEmpty) {
        return db
            .collection('notes')
            .where("user", isEqualTo: db.doc("/users/$uid"))
            .orderBy("updatedAt", descending: true)
            .snapshots();
      } else {
        return const Stream.empty();
      }
    } catch (e) {
      Get.snackbar("Error Loading", e.toString());
      debugPrint(e.toString());
      return const Stream.empty();
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
