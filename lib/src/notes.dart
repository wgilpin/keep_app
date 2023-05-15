import 'dart:html';

import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  String? id;
  String? title;
  String? comment;
  String? snippet;
  String? url;
  DocumentReference? user;
  DateTime? created;

  Note();

  Note.fromSnapshot(snapshot) {
    id = snapshot.id;
    title = snapshot.data()['title'];
    comment = snapshot.data()['comment'];
    snippet = snapshot.data()['snippet'];
    url = snapshot.data()['url'];
    created = snapshot.data()['created'].toDate();
  }

  Note.fromMap(mappedNote) {
    id = mappedNote.id;
    title = mappedNote['title'];
    comment = mappedNote['comment'];
    snippet = mappedNote['snippet'];
    url = mappedNote['url'];
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
    };
  }
}

Future<Note> getNote(id) async {
  final doc = await FirebaseFirestore.instance.collection('notes').doc(id).get();
  return Note.fromSnapshot(doc);
}
