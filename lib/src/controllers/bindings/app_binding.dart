import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/controllers/auth_controller.dart';
import 'package:keep_app/src/controllers/notes_controller.dart';

class AppBindings extends Bindings {
  /// Bindings are used to inject dependencies into GetX.
  @override
  void dependencies() {
    // auth controller singleton
    Get.put(AuthCtl(FirebaseAuth.instance), permanent: true);

    // note controller singleton
    Get.put<NotesController>(NotesController(), permanent: true);
    debugPrint('Bindings set');
  }
}
