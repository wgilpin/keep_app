import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/controllers/auth_controller.dart';

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
      debugPrint('noteSearch: $text');

      for (var entry in results.data) {
        res[entry["id"]] = entry["title"];
        debugPrint('noteSearch: ${entry["id"]} ${entry["title"]}');
      }
      return res;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('noteSearch Failed to call textSearch: ${e.message}');
      return {};
    }
  }

  static Future<List<Map<String, String>>> noteSearch(String noteId, int count, context) async {
    try {
      final uid = Get.find<AuthCtl>().user!.uid;
      final userSnap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      // late Timestamp lastUpdated;
      // final data = userSnap.data();
      // if (data != null && data.containsKey('lastUpdated')) {
      //   lastUpdated = data['lastUpdated'];
      // } else {
      //   // set to epoch 0
      //   lastUpdated = Timestamp.fromMicrosecondsSinceEpoch(0);
      // }
      // final relatedUpdated =
      //     note.relatedUpdated == null ? Timestamp.fromMicrosecondsSinceEpoch(0) : note.relatedUpdated as Timestamp;
      // if (note.related != null && note.related!.isNotEmpty) {
      //   if (lastUpdated.compareTo(relatedUpdated) <= 0.0) {
      //     debugPrint('noteSearch cached: U: ${lastUpdated.toDate()} N:${relatedUpdated.toDate()}');
      //     return note.related!;
      //   }
      // }
      // debugPrint('noteSearch cloud function : U: ${lastUpdated.toDate()} N:${relatedUpdated.toDate()}');

      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('noteSearch');
      final results = await callable.call({"noteId": noteId, "maxResults": count});
      if (results.data == null) {
        return [];
      }
      final List<Map<String, String>> res = [];
      for (var e in results.data) {
        if (e["id"] != noteId) {
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
