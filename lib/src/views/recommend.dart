import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

/// Class to call the recommender cloud functions
class Recommender {
  /// Call the cloud function to get recommendations based on a text string
  testSearch(String text, int count, context) async {
    final functions = FirebaseFunctions.instance;
    final callable = functions.httpsCallable('textSearch');
    final data = {"searchText": text, "maxResults": count};
    try {
      final results = await callable.call(data);
      debugPrint(results.data);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Failed to call function: ${e.message}');
    }
  }
}
