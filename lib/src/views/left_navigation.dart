import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keep_app/src/views/home_page.dart';
import 'package:keep_app/src/views/login/profile.dart';

class LeftNavigation extends StatelessWidget {
  final int selectedIndex;

  const LeftNavigation(this.selectedIndex, {super.key});

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
        selectedIndex: selectedIndex,
        useIndicator: true,
        indicatorColor: Theme.of(context).primaryColorDark,
        onDestinationSelected: (value) {
          if (value == 1) {
            Get.to(() => const ProfilePage());
          } else {
            Get.to(() => const HomePage());
          }
        },
        destinations: const [
          NavigationRailDestination(
            icon: Icon(Icons.home),
            label: Text('Home'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.person),
            label: Text('Profile'),
          ),
        ]);
  }
}
