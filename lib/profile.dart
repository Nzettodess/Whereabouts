import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'login.dart';
import 'widgets/default_location_picker.dart';
import 'widgets/syncfusion_date_picker.dart';

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
                const SizedBox(height: 10),
                ClipOval(
                  child: Builder(
                    builder: (context) {
                      final name = data?['displayName'] ?? widget.user.email ?? 'User';
                      final imageUrl = (photoUrl != null && photoUrl.isNotEmpty) 
                        ? photoUrl 
                        : "https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&size=160";
                      
                      print('[Profile Avatar] Loading for: $name');
                      print('[Profile Avatar] URL: $imageUrl');
                      
                      return CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        httpHeaders: const {
                          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                          'Referer': 'https://google.com',
                        },
                        placeholder: (context, url) {
                          print('[Profile Avatar] Loading placeholder');
                          return Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[200],
                            child: const CircularProgressIndicator(),
                          );
                        },
                        errorWidget: (context, url, error) {
                          print('[Profile Avatar] Error: $error');
                          print('[Profile Avatar] Failed URL: $url');
                          // Fallback to ui-avatars.com
                          return Image.network(
                            "https://ui-avatars.com/api/?name=${Uri.encodeComponent(data?['displayName'] ?? widget.user.email ?? 'User')}&size=160",
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // Final fallback to icon
                              return Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[300],
                                child: Icon(Icons.person, size: 40, color: Colors.grey[600]),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Display Name",
                    border: OutlineInputBorder(),
                    helperText: "This will override your Google name",
                  ),
                ),
                const SizedBox(height: 5),
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
                const SizedBox(height: 8),
                TextField(
                  controller: TextEditingController(text: widget.user.email),
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                ),
                const Divider(),
                const SizedBox(height: 5),
                const Text("Default Location", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 16, right: 0),
                  leading: const Icon(Icons.location_on),
                  title: Text(data?['defaultLocation'] ?? "Not set"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        iconSize: 24,
                        onPressed: () {
                          // Helper function to remove emoji flags
                          String stripEmojis(String text) {
                            return text.replaceAll(RegExp(r'[\u{1F1E6}-\u{1F1FF}]|\p{Emoji_Presentation}|\p{Emoji}\uFE0F', unicode: true), '').trim();
                          }
                          
                          final defaultLocation = data?['defaultLocation'];
                          String? defaultCountry;
                          String? defaultState;
                          
                          if (defaultLocation != null && defaultLocation.isNotEmpty) {
                            final parts = defaultLocation.split(',');
                            if (parts.length == 2) {
                              // Format: "🇲🇾 Country, State"
                              defaultCountry = stripEmojis(parts[0].trim());  // First part is COUNTRY
                              defaultState = stripEmojis(parts[1].trim());     // Second part is STATE
                            } else {
                              defaultCountry = stripEmojis(parts[0].trim());
                            }
                          }
                          
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) => DefaultLocationPicker(
                              defaultCountry: defaultCountry,
                              defaultState: defaultState,
                              onLocationSelected: (country, state) async {
                                // Save in "Country, State" format (not "State, Country")
                                final loc = state != null ? "$country, $state" : country;
                                await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({
                                  'defaultLocation': loc,
                                });
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Default location set to $loc")));
                              },
                            ),
                          );
                        },
                        tooltip: 'Edit Default Location',
                      ),
                      if (data?['defaultLocation'] != null && (data?['defaultLocation'] as String).isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.red),
                          iconSize: 24,
                          onPressed: () async {
                            await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({
                              'defaultLocation': FieldValue.delete(),
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Default location cleared"))
                              );
                            }
                          },
                          tooltip: 'Clear Default Location',
                        ),
                    ],
                  ),
                ),
                const Divider(),
                const SizedBox(height: 5),
                const Text("Birthday", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 16, right: 0),
                  leading: const Icon(Icons.cake),
                  title: Text(_formatBirthday(data?['birthday'])),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        iconSize: 24,
                        onPressed: () async {
                          final birthday = data?['birthday'];
                          DateTime? initialDate;
                          
                          if (birthday != null) {
                            initialDate = (birthday as Timestamp).toDate();
                          } else {
                            // Default to 25 years ago
                            final now = DateTime.now();
                            initialDate = DateTime(now.year - 25, now.month, now.day);
                          }

                          final selectedDate = await showSyncfusionDatePicker(
                            context: context,
                            initialDate: initialDate,
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                            helpText: 'Select Birthday',
                          );

                          if (selectedDate != null) {
                            // Show dialog to ask if this is a lunar birthday
                            bool? isLunar = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text("Birthday Type"),
                                content: const Text("Is this a Chinese lunar calendar birthday?"),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text("Solar (Normal)"),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text("Lunar (Chinese)"),
                                  ),
                                ],
                              ),
                            );

                            if (isLunar != null && mounted) {
                              await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({
                                'birthday': Timestamp.fromDate(selectedDate),
                                'isLunarBirthday': isLunar,
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Birthday updated (${isLunar ? 'Lunar' : 'Solar'})"))
                                );
                              }
                            }
                          }
                        },
                        tooltip: 'Edit Birthday',
                      ),
                      if (data?['birthday'] != null)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.red),
                          iconSize: 24,
                          onPressed: () async {
                            await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({
                              'birthday': FieldValue.delete(),
                              'isLunarBirthday': FieldValue.delete(),
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Birthday cleared"))
                              );
                            }
                          },
                          tooltip: 'Clear Birthday',
                        ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: () async {
                    // Show confirmation dialog
                    bool? confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Logout"),
                        content: const Text("Are you sure you want to logout?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Logout"),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirm == true) {
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        // Close profile dialog and return to login screen
                        // The auth state listener in home.dart will handle showing login
                        Navigator.of(context).pop();
                      }
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

  String _formatBirthday(dynamic birthday) {
    if (birthday == null) return "Not set";
    final date = (birthday as Timestamp).toDate();
    final now = DateTime.now();
    final age = now.year - date.year - (now.month < date.month || (now.month == date.month && now.day < date.day) ? 1 : 0);
    return "${date.day}/${date.month}/${date.year} (Age: $age)";
  }
}
