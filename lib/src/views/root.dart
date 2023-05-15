import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import 'home_page.dart';
import 'login/login_page.dart';

class Root extends GetWidget<AuthCtl> {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.user == null) {
        return LoginPage();
      } else {
        return Builder(builder: (context) {
          return HomePage();
        });
      }
    });
  }
}
