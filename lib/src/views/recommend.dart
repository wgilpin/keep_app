import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class Recommender {
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
