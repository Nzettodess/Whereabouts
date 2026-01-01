import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'login.dart';
import 'widgets/default_location_picker.dart';
import 'widgets/syncfusion_date_picker.dart';
import 'widgets/lunar_date_picker.dart';
import 'widgets/skeleton_loading.dart';
import 'firestore_service.dart';
import 'theme.dart';

class ProfileDialog extends StatefulWidget {
  final User user;

  const ProfileDialog({super.key, required this.user});

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _nameController = TextEditingController();
  String? _photoUrl;
  StreamSubscription? _profileSubscription;

  @override
  void initState() {
    super.initState();
    final cached = _firestoreService.getLastSeenProfile(widget.user.uid);
    if (cached != null) {
      _nameController.text = cached['displayName'] ?? '';
      _photoUrl = cached['photoURL'];
    }

    _profileSubscription = _firestoreService.getUserProfileStream(widget.user.uid).listen((data) {
      if (!mounted) return;
      // Update controller only if it was empty (initial load from stream)
      // First check Firestore, then fall back to Google Auth
      if (_nameController.text.isEmpty) {
        final name = data['displayName'] ?? widget.user.displayName ?? '';
        if (name.isNotEmpty) {
          _nameController.text = name;
        }
      }
      setState(() {
         _photoUrl = data['photoURL'] ?? widget.user.photoURL;
      });
    });
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 400,
          // Use a bounded height to prevent squashing during keyboard events
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            minHeight: 200,
          ),
          padding: const EdgeInsets.all(20.0),
        child: StreamBuilder<Map<String, dynamic>>(
          stream: _firestoreService.getUserProfileStream(widget.user.uid),
          initialData: _firestoreService.getLastSeenProfile(widget.user.uid),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SkeletonProfile();
            }

            final data = snapshot.data ?? {};
            // Prioritize Firestore, fall back to Auth
            final photoUrl = data['photoURL'] ?? widget.user.photoURL;
            final displayName = data['displayName']?.isNotEmpty == true ? data['displayName'] : widget.user.displayName;

            // Update controller if not yet populated
            if (_nameController.text.isEmpty && displayName != null && displayName.isNotEmpty) {
               WidgetsBinding.instance.addPostFrameCallback((_) {
                 if (mounted && _nameController.text.isEmpty) {
                   _nameController.text = displayName;
                 }
               });
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Profile", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const Divider(height: 16),
                const SizedBox(height: 10),
                ClipOval(
                  child: Builder(
                    builder: (context) {
                      // Use displayName we already computed with fallbacks
                      final name = displayName ?? widget.user.email ?? 'User';
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
                          return const SkeletonCircle(size: 80);
                        },
                        errorWidget: (context, url, error) {
                          print('[Profile Avatar] Error: $error');
                          print('[Profile Avatar] Failed URL: $url');
                          // Fallback to ui-avatars.com
                          return Image.network(
                            "https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayName ?? widget.user.email ?? 'User')}&size=160",
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
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Display Name",
                    border: OutlineInputBorder(),
                    helperText: "Use Reset to restore Google name",
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final isNarrow = MediaQuery.of(context).size.width < 400;
                          final isExtraNarrow = MediaQuery.of(context).size.width < 320;
                          return ElevatedButton(
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.getButtonBackground(context),
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              padding: isNarrow ? const EdgeInsets.symmetric(horizontal: 4) : null,
                            ),
                            child: Text(
                              "Update Name",
                              style: TextStyle(
                                // Tighten spacing on very narrow screens to prevent overflow
                                letterSpacing: isExtraNarrow ? -0.8 : null,
                                wordSpacing: isExtraNarrow ? -2.0 : null,
                              ),
                            ),
                          );
                        },
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
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.onSurface,
                          side: BorderSide(color: Theme.of(context).colorScheme.outline),
                        ),
                        child: const Text("Reset"),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 12),
                const Text("Default Location", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.only(left: 8, right: 0),
                  leading: const Icon(Icons.location_on, size: 20),
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
                const Divider(height: 12),
                const Text("Birthday", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.only(left: 8, right: 0),
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

                          if (selectedDate != null && mounted) {
                            // Save as solar birthday (lunar birthday has its own separate section)
                            await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({
                              'birthday': Timestamp.fromDate(selectedDate),
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Birthday updated"))
                              );
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
                const Divider(height: 12),
                const Text("Lunar Birthday (农历生日)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                CheckboxListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Enable Lunar Birthday"),
                  subtitle: const Text("Show a separate lunar calendar birthday", style: TextStyle(fontSize: 12)),
                  value: data?['hasLunarBirthday'] ?? false,
                  onChanged: (value) async {
                    await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({
                      'hasLunarBirthday': value,
                    });
                  },
                ),
                if (data?['hasLunarBirthday'] == true)
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: const EdgeInsets.only(left: 8, right: 0),
                    leading: const Icon(Icons.nights_stay, size: 20, color: Colors.orange),
                    title: Text(_formatLunarBirthday(data?['lunarBirthdayMonth'], data?['lunarBirthdayDay'])),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          iconSize: 24,
                          onPressed: () async {
                            final result = await showLunarDatePicker(
                              context: context,
                              initialMonth: data?['lunarBirthdayMonth'],
                              initialDay: data?['lunarBirthdayDay'],
                            );
                            if (result != null && mounted) {
                              await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({
                                'lunarBirthdayMonth': result.$1,
                                'lunarBirthdayDay': result.$2,
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Lunar birthday set to ${LunarDatePickerDialog.formatLunarDate(result.$1, result.$2)}")),
                                );
                              }
                            }
                          },
                          tooltip: 'Edit Lunar Birthday',
                        ),
                        if (data?['lunarBirthdayMonth'] != null)
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.red),
                            iconSize: 24,
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({
                                'lunarBirthdayMonth': FieldValue.delete(),
                                'lunarBirthdayDay': FieldValue.delete(),
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Lunar birthday cleared")),
                                );
                              }
                            },
                            tooltip: 'Clear Lunar Birthday',
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
                      // Note: clearPersistence removed - it requires app restart and causes grey screen
                      // The FirestoreService singleton caches are cleared by the auth state listener
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
              ),
            );
          },
        ),
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

  String _formatLunarBirthday(int? month, int? day) {
    if (month == null || day == null) return "Not set";
    return LunarDatePickerDialog.formatLunarDate(month, day);
  }
}
