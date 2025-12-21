import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginOverlay extends StatelessWidget {
  final VoidCallback onSignedIn;

  const LoginOverlay({super.key, required this.onSignedIn});

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // ✅ Web login
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        userCredential = await FirebaseAuth.instance.signInWithPopup(
          googleProvider,
        );
      } else {
        // ✅ Mobile login
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return;

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
      }

      final user = userCredential.user;
      if (user != null) {
        // ✅ Save or update profile info in Firestore
        await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
          "displayName": user.displayName,
          "email": user.email,
          "photoURL": user.photoURL, // currently direct Google URL
          "lastLogin": DateTime.now(),
        }, SetOptions(merge: true));
      }

      onSignedIn(); // Notify home that login succeeded
    } catch (e) {
      debugPrint("Google sign-in failed: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Login failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.3), // Semi-transparent overlay
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Login Required",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "You need to login to use the calendar.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: Image.asset("assets/google_logo.png", height: 20),
                      label: const Text("Sign in with Google"),
                      onPressed: () => _signInWithGoogle(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFDDDDDD)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
