import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Note {
  String? id;
  String? title;
  String? comment;
  String? snippet;
  String? url;
  bool isPinned = false;
  DocumentReference? user;
  DateTime? created;
  List<Map<String, String>>? related;
  Timestamp? relatedUpdated;

  Note();

  Note.fromSnapshot(snapshot) {
    try {
      id = snapshot.id;
      title = snapshot.data()['title'];
      comment = snapshot.data()['comment'];
      snippet = snapshot.data()['snippet'];
      url = snapshot.data()['url'];
      isPinned = snapshot.data()['isPinned'] ?? false;
      created = snapshot.data()['created']?.toDate();
      if (snapshot.data()['related'] != null) {
        related = [];
        for (var item in snapshot.data()['related']) {
          related!.add({"id": item["id"], "title": item['title']});
        }
      }
      relatedUpdated = snapshot.data()['relatedUpdated'];
    } on Exception catch (e) {
      debugPrint('Failed to create note from snapshot: $e');
    }
  }

  Note.fromMap(mappedNote) {
    id = mappedNote.id;
    title = mappedNote['title'];
    comment = mappedNote['comment'];
    snippet = mappedNote['snippet'];
    url = mappedNote['url'];
    isPinned = mappedNote['isPinned'];
    created = mappedNote['created']?.toDate();
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (title != null) "name": title,
      if (comment != null) "comment": comment,
      if (snippet != null) "snippet": snippet,
      if (url != null) "url": url,
      if (user != null) "user": user,
      if (created != null) "created": created,
      "isPinned": isPinned,
    };
  }
}

Future<Note> getNote(id) async {
  final doc = await FirebaseFirestore.instance.collection('notes').doc(id).get();
  return Note.fromSnapshot(doc);
}
