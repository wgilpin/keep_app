import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../auth_controller.dart';

class AppBindings extends Bindings {
  /// Bindings are used to inject dependencies into GetX.
  @override
  void dependencies() {
    Get.put(AuthCtl(FirebaseAuth.instance));

    debugPrint('Bindings set');
  }
}
