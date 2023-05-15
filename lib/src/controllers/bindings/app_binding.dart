import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/controllers/note_controller.dart';

import '../auth_controller.dart';

class AppBindings extends Bindings {
  /// Bindings are used to inject dependencies into GetX.
  @override
  void dependencies() {
    Get.put(AuthCtl(FirebaseAuth.instance));
    Get.put<NoteController>(NoteController());
    debugPrint('Bindings set');
  }
}
