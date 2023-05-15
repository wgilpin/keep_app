import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/controllers/auth_controller.dart';
import 'package:keep_app/src/notes.dart';

class NoteController extends GetxController {
  var isLoading = true.obs;
  var notes = <Note>[].obs;
  final authCtl = Get.find<AuthCtl>();

  NoteController() {
    getData();
  }

  Future<void> getData() async {
    try {
      final db = FirebaseFirestore.instance;
      String uid = authCtl.user!.uid;
      if (uid.isNotEmpty) {
        QuerySnapshot snap = await db.collection('notes').where("user", isEqualTo: db.doc("/users/$uid")).get();
        notes.clear();
        for (var note in snap.docs) {
          notes.add(Note.fromSnapshot(note));
        }
        isLoading.value = false;
        update();
      } else {
        Get.snackbar("Error Loading", "User not logged in");
      }
    } catch (e) {
      Get.snackbar("Error Loading", e.toString());
    }
  }
}
