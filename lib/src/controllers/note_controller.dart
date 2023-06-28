import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/notes.dart';

class NoteController extends GetxController {
  NoteController(this.id, this.onLoaded);

  Function() onLoaded;
  String id;

  final Rx<Note?> _note = Rx<Note?>(null);
  Note? get note => _note.value;
  DocumentReference get ref => FirebaseFirestore.instance.collection('notes').doc(id);

  @override
  Future<void> onInit() async {
    super.onInit();

    final snapshot = await ref.get();
    _note.value = Note.fromSnapshot(snapshot);

    ref.snapshots().listen((snapshot) {
      _note.value = Note.fromSnapshot(snapshot);
    });
    onLoaded();
  }

  Future<void> addCheckItem(String title) async {
    await ref.update({
      "checklist": FieldValue.arrayUnion([
        {"title": title, "checked": false}
      ])
    });
    refresh();
  }

  Future<void> delete(String noteId) async {
    ref.delete();
    refresh();
  }
}
