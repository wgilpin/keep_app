import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/views/home_page.dart';
import 'package:keep_app/src/views/login/profile.dart';

class BottomNav extends StatelessWidget {
  final int index;

  const BottomNav(
    this.index, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Colors.yellow[700],
      selectedItemColor: Colors.brown[900],
      unselectedItemColor: Colors.brown[900],
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          activeIcon: Icon(Icons.home),
          icon: Icon(Icons.home_outlined),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      currentIndex: index,
      onTap: (index) {
        switch (index) {
          case 1:
            Get.to(() => const ProfilePage());
            break;
          default:
            Get.to(() => const HomePage());
        }
      },
    );
  }
}
