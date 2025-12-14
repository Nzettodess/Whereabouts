import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeDrawer extends StatelessWidget {
  final User? user;
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
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.deepPurple),
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
                        user?.photoURL ?? photoUrl ?? "https://ui-avatars.com/api/?name=${Uri.encodeComponent(user?.displayName ?? 'User')}",
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.network(
                            "https://ui-avatars.com/api/?name=${Uri.encodeComponent(user?.displayName ?? 'User')}",
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
                  user?.displayName ?? user?.email ?? "User",
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text("Groups"),
            onTap: () {
              Navigator.pop(context);
              onManageGroupsTap();
            },
          ),
          ListTile(
            leading: const Icon(Icons.event_note),
            title: const Text("Upcoming"),
            onTap: () {
              Navigator.pop(context);
              onUpcomingTap();
            },
          ),
          ListTile(
            leading: const Icon(Icons.cake, color: Colors.pink),
            title: const Text("Birthday Baby"),
            onTap: () {
              Navigator.pop(context);
              onBirthdayBabyTap();
            },
          ),
          ListTile(
            leading: const Icon(Icons.event_available),
            title: const Text("RSVP"),
            onTap: () {
              Navigator.pop(context);
              onRSVPManagementTap();
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Settings"),
            onTap: () {
              Navigator.pop(context);
              onSettingsTap();
            },
          ),
        ],
      ),
    );
  }

}
