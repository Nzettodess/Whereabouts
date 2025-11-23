import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'location_picker.dart';
import 'firestore_service.dart';
import 'login.dart';

class ProfileDialog extends StatefulWidget {
  final User user;

  const ProfileDialog({super.key, required this.user});

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  final TextEditingController _nameController = TextEditingController();
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).get();
    if (doc.exists) {
      final data = doc.data();
      setState(() {
        _nameController.text = data?['displayName'] ?? '';
        _photoUrl = data?['photoURL'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(20.0),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.user.uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>?;
            final photoUrl = data?['photoURL'];

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Profile", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[200],
                  child: ClipOval(
                    child: Image.network(
                      photoUrl != null && photoUrl.isNotEmpty 
                        ? photoUrl 
                        : "https://ui-avatars.com/api/?name=${Uri.encodeComponent(data?['displayName'] ?? widget.user.email ?? 'User')}",
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.network(
                          "https://ui-avatars.com/api/?name=${Uri.encodeComponent(data?['displayName'] ?? widget.user.email ?? 'User')}",
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Display Name",
                    border: OutlineInputBorder(),
                    helperText: "This will override your Google name",
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({
                            'displayName': _nameController.text,
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Display name updated"))
                            );
                          }
                        },
                        child: const Text("Update Name"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final googleName = widget.user.displayName;
                          if (googleName != null) {
                            setState(() {
                              _nameController.text = googleName;
                            });
                            await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({
                              'displayName': googleName,
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Reset to Google name"))
                              );
                            }
                          }
                        },
                        child: const Text("Reset"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: TextEditingController(text: widget.user.email),
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                ),
                const Divider(),
                const SizedBox(height: 10),
                const Text("Default Location", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(data?['defaultLocation'] ?? "Not set"),
                  trailing: const Icon(Icons.edit),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => LocationPicker(
                        onLocationSelected: (country, state) async {
                          final loc = state != null ? "$state, $country" : country;
                          await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({
                            'defaultLocation': loc,
                          });
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Default location set to $loc")));
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (mounted) {
                      // Just pop - the auth state listener will handle showing login
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text("Logout"),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
