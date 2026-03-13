import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Padam Heart Care Centre')),
      body: const Center(
        child: Text('Login successful. You are now signed in.'),
      ),
    );
  }
}
