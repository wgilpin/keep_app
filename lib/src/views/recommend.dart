import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/controllers/auth_controller.dart';
import 'package:keep_app/src/notes.dart';

/// Class to call the recommender cloud functions
class Recommender {
  /// Call the cloud function to get recommendations based on a text string
  static Future<Map<String, String>> textSearch(String text, int count, context) async {
    final functions = FirebaseFunctions.instance;
    final callable = functions.httpsCallable('textSearch');
    final data = {"searchText": text, "maxResults": count};

    try {
      final results = await callable.call(data);
      if (results.data == null) {
        return {};
      }
      Map<String, String> res = {};
      for (const entry in results.data) {
        res[entry["id"]] = entry["title"];
      }
      return res;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('noteSearch Failed to call textSearch: ${e.message}');
      return {};
    }
  }

  static Future<List<Map<String, String>>> noteSearch(Note note, int count, context) async {
    try {
      final uid = Get.find<AuthCtl>().user!.uid;
      final userSnap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final lastUpdated = Timestamp.fromMillisecondsSinceEpoch(userSnap.data()!['lastUpdated'] ?? 0);
      final relatedUpdated =
          note.relatedUpdated == null ? Timestamp.fromMicrosecondsSinceEpoch(0) : note.relatedUpdated as Timestamp;
      if (note.related != null && note.related!.isNotEmpty) {
        if (lastUpdated.compareTo(relatedUpdated) <= 0.0) {
          debugPrint('noteSearch cached: U: ${lastUpdated.toDate()} N:${relatedUpdated.toDate()}');
          return note.related!;
        }
      }
      debugPrint('noteSearch cloud function : U: ${lastUpdated.toDate()} N:${relatedUpdated.toDate()}');

      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('noteSearch');
      final data = {"noteId": note.id, "maxResults": count};
      final results = await callable.call(data);
      if (results.data == null) {
        return [];
      }
      final List<Map<String, String>> res = [];
      for (var e in results.data) {
        if (e["id"] != note.id) {
          res.add({
            "id": e["id"],
            "title": e["title"],
          });
        }
      }
      return res;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('noteSearch Failed to call function: ${e.message}');
      return [];
    }
  }
}
