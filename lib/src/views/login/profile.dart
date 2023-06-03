import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keep_app/src/controllers/auth_controller.dart';
import 'package:keep_app/src/utils/utils.dart';
import 'package:keep_app/src/views/home_page.dart';

class Profile extends StatelessWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Doofer',
          style: GoogleFonts.philosopher(
            fontSize: 30,
          ),
        ),
      ),
      body: Center(
        child: Column(
          children: [
            addVerticalSpace(40),
            const Padding(
              padding: EdgeInsets.only(top: 20.0),
              child: Text(
                'Profile Page',
                style: TextStyle(fontSize: 24),
              ),
            ),
            addVerticalSpace(30),
            ElevatedButton(onPressed: doLogout, child: const Text('Logout')),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.yellow[700],
        selectedItemColor: Colors.brown[900],
        unselectedItemColor: Colors.grey[500],
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Get.to(HomePage());
          }
        },
      ),
    );
  }

  void doLogout() {
    Get.find<AuthCtl>().auth.signOut();
  }
}
