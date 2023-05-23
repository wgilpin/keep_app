import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/controllers/auth_controller.dart';
import 'package:keep_app/src/views/home_page.dart';

class Profile extends StatelessWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('rKyv'),
      ),
      body: Center(
        child: Column(
          children: [
            const Text(
              'Profile Page',
              style: TextStyle(fontSize: 24),
            ),
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
