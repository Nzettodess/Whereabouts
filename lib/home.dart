import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart'; // We’ll show LoginOverlay from here

class HomeWithLogin extends StatefulWidget {
  const HomeWithLogin({super.key});

  @override
  State<HomeWithLogin> createState() => _HomeWithLoginState();
}

class _HomeWithLoginState extends State<HomeWithLogin> {
  User? _user = FirebaseAuth.instance.currentUser;

  void _handleLoginSuccess() {
    setState(() {
      _user = FirebaseAuth.instance.currentUser;
    });
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    setState(() {
      _user = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text("Team Calendar"),
            actions: [
              if (_user != null)
                IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
            ],
          ),
          body: Center(
            child: _user == null
                ? const Text("Please sign in")
                : Text("Welcome, ${_user?.displayName ?? 'User'}"),
          ),
        ),

        // Overlay login if user is not signed in
        if (_user == null) LoginOverlay(onSignedIn: _handleLoginSuccess),
      ],
    );
  }
}
