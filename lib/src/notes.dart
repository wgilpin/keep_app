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
  List<CheckItem> checklist = [];
  bool isShared = false;
  Timestamp? relatedUpdated;
  Timestamp? lockedTime;
  String? lockedBy; // user id of user who locked the note

  Note();

  Note.fromSnapshot(snapshot, {bool includeRelated = false}) {
    try {
      try {
        id = snapshot.id;
      } on NoSuchMethodError catch (_) {
        id = null;
      }
      title = snapshot.data()['title'];
      comment = snapshot.data()['comment'];
      snippet = snapshot.data()['snippet'];
      url = snapshot.data()['url'];
      isPinned = snapshot.data()['isPinned'] ?? false;
      isShared = snapshot.data()['shared'] ?? false;
      created = snapshot.data()['created']?.toDate();
      if (snapshot.data()['related'] != null) {
        related = [];
        for (var item in snapshot.data()['related']) {
          related!.add({"id": item["id"], "title": item['title']});
        }
      }
      if (snapshot.data()['checklist'] != null) {
        checklist = [];
        for (var item in snapshot.data()['checklist']) {
          checklist
              .add(CheckItem(index: item["index"], title: item['title'], checked: item['checked'], key: item["key"]));
        }
      }
      if (includeRelated) {
        relatedUpdated = snapshot.data()['relatedUpdated'];
      }
      lockedTime = snapshot.data()['lockedTime'];
      lockedBy = snapshot.data()['lockedBy'];
    } on Exception catch (e) {
      debugPrint('Failed to create note from snapshot: $e');
    }
  }

  // get all checked items in checklist
  List<CheckItem> get checked {
    return checklist.where((item) => item.checked).toList();
  }

  // get all UNchecked items in checklist
  List<CheckItem> get unchecked {
    return checklist.where((item) => !item.checked).toList();
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (title != null) "name": title,
      if (comment != null) "comment": comment,
      if (snippet != null) "snippet": snippet,
      if (url != null) "url": url,
      if (user != null) "user": user,
      if (created != null) "created": created,
      if (lockedBy != null) "lockedBy": lockedBy, // user id of user who locked the note
      'shared': isShared,
      "isPinned": isPinned,
    };
  }

  // change note from checked to unchecked or v.v.
  void toggleCheckItem(CheckItem item) {
    int index = checklist.indexWhere((element) => element.key == item.key);
    checklist[index].checked = !checklist[index].checked;
  }
}

class CheckItem {
  int? index;
  Key? key;
  String? title;
  bool checked;

  CheckItem({this.index, this.title, this.checked = false, String? key}) {
    if (key != null && key.isNotEmpty) {
      this.key = Key(key);
    } else {
      this.key = UniqueKey();
    }
  }

  CheckItem.fromTitle(this.title) : checked = false {
    key = UniqueKey();
  }

  toJson() {
    return {
      "index": index,
      "title": title,
      "checked": checked,
      "key": key.toString(),
    };
  }
}
