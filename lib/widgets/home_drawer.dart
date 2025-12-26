import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'credits_feedback_dialog.dart';

class HomeDrawer extends StatelessWidget {
  final User? user;
  final String? displayName;
  final String? photoUrl;
  final VoidCallback onProfileTap;
  final VoidCallback onManageGroupsTap;
  final VoidCallback onUpcomingTap;
  final VoidCallback onBirthdayBabyTap;
  final VoidCallback onRSVPManagementTap;
  final VoidCallback onSettingsTap;

  const HomeDrawer({
    super.key,
    required this.user,
    this.displayName,
    required this.photoUrl,
    required this.onProfileTap,
    required this.onManageGroupsTap,
    required this.onUpcomingTap,
    required this.onBirthdayBabyTap,
    required this.onRSVPManagementTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(
                    color: Color(0xFF673AB7), // Deep Purple
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context); // Close drawer
                          onProfileTap();
                        },
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          child: ClipOval(
                            child: Image.network(
                              photoUrl ?? user?.photoURL ?? "https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayName ?? user?.displayName ?? 'User')}",
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.network(
                                  "https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayName ?? user?.displayName ?? 'User')}",
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        displayName ?? user?.displayName ?? user?.email ?? "User",
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.group, color: Colors.deepPurpleAccent),
                  title: const Text("Groups"),
                  onTap: () {
                    Navigator.pop(context);
                    onManageGroupsTap();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.event_note, color: Colors.orangeAccent),
                  title: const Text("Upcoming"),
                  onTap: () {
                    Navigator.pop(context);
                    onUpcomingTap();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cake, color: Colors.pinkAccent),
                  title: const Text("Birthday Baby"),
                  onTap: () {
                    Navigator.pop(context);
                    onBirthdayBabyTap();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.event_available, color: Colors.tealAccent),
                  title: const Text("RSVP"),
                  onTap: () {
                    Navigator.pop(context);
                    onRSVPManagementTap();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.blueGrey),
                  title: const Text("Settings"),
                  onTap: () {
                    Navigator.pop(context);
                    onSettingsTap();
                  },
                ),
              ],
            ),
          ),
          // Bottom section with divider and feedback button
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.feedback_outlined, color: Colors.deepPurple),
            title: const Text("About & Feedback"),
            onTap: () {
              Navigator.pop(context); // Close drawer
              showDialog(
                context: context,
                builder: (context) => const CreditsAndFeedbackDialog(),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
