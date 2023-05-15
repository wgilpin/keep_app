import 'package:flutter/material.dart';
import 'package:keep_app/src/views/recommend.dart';

class Profile extends StatelessWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    final r = Recommender();
    r.testSearch('hello to the lords and ladoes of the revolution', 10, context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('rKyv'),
      ),
      body: const Center(
        child: Text(
          'Profile Page',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
