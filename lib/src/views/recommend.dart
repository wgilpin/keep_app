import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:keep_app/src/notes.dart';

/// Class to call the recommender cloud functions
class Recommender {
  /// Call the cloud function to get recommendations based on a text string
  static Future<List<String>> textSearch(String text, int count, context) async {
    final functions = FirebaseFunctions.instance;
    final callable = functions.httpsCallable('textSearch');
    final data = {"searchText": text, "maxResults": count};

    List<String> results = [];
    try {
      final fnResults = await callable.call(data);
      if (fnResults.data != null) {
        for (final id in fnResults.data) {
          if (id != null) results.add(id.toString());
        }
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Failed to call function: ${e.message}');
    }
    return results;
  }

  static Future<List<String>> noteSearch(Note note, int count, context) async {
    final functions = FirebaseFunctions.instance;
    final callable = functions.httpsCallable('noteSearch');
    final data = {"noteId": note.id, "maxResults": count};
    try {
      final results = await callable.call(data);
      if (results.data == null) {
        return [];
      }
      final List<String> res = [];
      for (var n in results.data) {
        res.add(n.toString());
      }
      return res;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('noteSearch Failed to call function: ${e.message}');
      return [];
    }
  }
}
