import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/notes.dart';

class Database {
  static final db = FirebaseFirestore.instance;

  Stream<List<Note>> noteStream(String uid) {
    try {
      debugPrint('noteStream.getData');

      if (uid.isNotEmpty) {
        debugPrint('noteStream.getData: have values');

        return db
            .collection('notes')
            .where("user", isEqualTo: db.doc("/users/$uid"))
            .orderBy("updatedAt", descending: true)
            .snapshots()
            .map((querySnap) {
          debugPrint('noteStream.getData: querySnap.docs.map');
          return querySnap.docs.map((noteSnap) => Note.fromSnapshot(noteSnap)).toList();
        });
      } else {
        debugPrint('noteStream.getData: uid is empty');

        return const Stream.empty();
      }
    } catch (e) {
      Get.snackbar("Error Loading", e.toString());
      debugPrint(e.toString());
      return const Stream.empty();
    }
  }

  Future<void> updateNotePinned(String noteId, bool value) {
    return FirebaseFirestore.instance.collection("notes").doc(noteId).update({"isPinned": value});
  }
}
