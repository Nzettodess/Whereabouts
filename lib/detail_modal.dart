import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'models/placeholder_member.dart';
import 'firestore_service.dart';
import 'religious_calendar_helper.dart';
import 'location_picker.dart';
import 'add_event_modal.dart';
import 'widgets/user_avatar.dart';
import 'rsvp_management.dart';

class DetailModal extends StatefulWidget {
  final DateTime date;
  final List<UserLocation> locations;
  final List<GroupEvent> events;
  final List<Holiday> holidays;
  final List<Birthday> birthdays;
  final String currentUserId;

  const DetailModal({
    super.key,
    required this.date,
    required this.locations,
    required this.events,
    required this.holidays,
    required this.birthdays,
    required this.currentUserId,
  });

  @override
  State<DetailModal> createState() => _DetailModalState();
}

class _DetailModalState extends State<DetailModal> {
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, Map<String, dynamic>> _userDetails = {};
  Map<String, String> _groupNames = {}; // Map groupId -> groupName
  List<String> _pinnedMembers = [];
  Set<String> _manageableMembers = {}; // Members the current user can edit (as admin/owner)
  Set<String> _adminGroups = {}; // Groups where current user is owner or admin

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
    _loadPinnedMembers();
    _loadGroupNames();
    _loadManageableMembers();
  }

  /// Deduplicates locations by userId - each user appears only once.
  /// Priority: explicit location > default location > "No location selected"
  /// Preserves original groupId for edit/delete operations.
  List<UserLocation> _getDeduplicatedLocations() {
    final Map<String, UserLocation> userLocationMap = {};
    
    for (final loc in widget.locations) {
      final userId = loc.userId;
      final existing = userLocationMap[userId];
      
      if (existing == null) {
        // First occurrence - keep with original groupId
        userLocationMap[userId] = loc;
      } else {
        // Already exists - prefer explicit location over "No location selected"
        final isNewExplicit = loc.nation != "No location selected";
        final isExistingNoLocation = existing.nation == "No location selected";
        
        if (isNewExplicit && isExistingNoLocation) {
          // Replace with the explicit location (keeps its original groupId)
          userLocationMap[userId] = loc;
        }
        // Otherwise keep existing (first explicit wins)
      }
    }
    
    return userLocationMap.values.toList();
  }

  Future<void> _loadGroupNames() async {
    // Load group names for all groups in locations
    final groupIds = widget.locations.map((l) => l.groupId).toSet();
    for (final groupId in groupIds) {
      // Handle special "global" groupId
      if (groupId == 'global') {
        setState(() {
          _groupNames['global'] = 'All Members';
        });
        continue;
      }
      
      final doc = await FirebaseFirestore.instance.collection('groups').doc(groupId).get();
      if (doc.exists) {
        setState(() {
          _groupNames[groupId] = doc.data()?['name'] ?? 'Unknown Group';
        });
      } else {
        // Group doesn't exist, use a readable fallback
        setState(() {
          _groupNames[groupId] = 'Group';
        });
      }
    }
  }

  /// Load all members that the current user can manage (as owner or admin)
  Future<void> _loadManageableMembers() async {
    try {
      // Get all groups where current user is owner or admin
      final groupsSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .where('members', arrayContains: widget.currentUserId)
          .get();
      
      final manageableMembers = <String>{};
      
      for (final doc in groupsSnapshot.docs) {
        final data = doc.data();
        final ownerId = data['ownerId'] as String?;
        final admins = List<String>.from(data['admins'] ?? []);
        
        // Check if current user is owner or admin of this group
        if (ownerId == widget.currentUserId || admins.contains(widget.currentUserId)) {
          // Add all members of this group to manageable set
          final members = List<String>.from(data['members'] ?? []);
          manageableMembers.addAll(members);
        }
      }
      
      // Remove current user from manageable set (can't manage yourself via this)
      manageableMembers.remove(widget.currentUserId);
      
      // Track which groups user is admin of
      final adminGroups = <String>{};
      for (final doc in groupsSnapshot.docs) {
        final data = doc.data();
        final ownerId = data['ownerId'] as String?;
        final admins = List<String>.from(data['admins'] ?? []);
        if (ownerId == widget.currentUserId || admins.contains(widget.currentUserId)) {
          adminGroups.add(doc.id);
        }
      }
      
      setState(() {
        _manageableMembers = manageableMembers;
        _adminGroups = adminGroups;
      });
    } catch (e) {
      print('Error loading manageable members: $e');
    }
  }

  Future<List<String>> _getReligiousDates() async {
    // Get user's enabled religious calendars from Firestore
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.currentUserId).get();
    if (doc.exists) {
      final data = doc.data();
      final religious = data?['religiousCalendars'];
      if (religious != null && religious is List) {
        final enabledCalendars = List<String>.from(religious);
        return ReligiousCalendarHelper.getReligiousDates(widget.date, enabledCalendars);
      }
    }
    return [];
  }

  Future<void> _loadPinnedMembers() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.currentUserId).get();
    if (doc.exists) {
      setState(() {
        _pinnedMembers = List<String>.from(doc.data()?['pinnedMembers'] ?? []);
      });
    }
  }

  Future<void> _loadUserDetails() async {
    final userIds = widget.locations.map((l) => l.userId).toSet();
    for (final uid in userIds) {
      if (!_userDetails.containsKey(uid)) {
        // Check if this is a placeholder member
        if (uid.startsWith('placeholder_')) {
          final doc = await FirebaseFirestore.instance.collection('placeholder_members').doc(uid).get();
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            setState(() {
              _userDetails[uid] = {
                'displayName': '👻 ${data['displayName'] ?? 'Placeholder'}',
                'photoURL': null,
                'isPlaceholder': true,
                'groupId': data['groupId'],
              };
            });
          }
        } else {
          // Regular user
          final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          if (doc.exists) {
            setState(() {
              _userDetails[uid] = doc.data() as Map<String, dynamic>;
            });
          }
        }
      }
    }
  }

  Future<void> _togglePin(String userId) async {
    List<String> newPinned = List.from(_pinnedMembers);
    if (newPinned.contains(userId)) {
      newPinned.remove(userId);
    } else {
      newPinned.add(userId);
    }

    await FirebaseFirestore.instance.collection('users').doc(widget.currentUserId).update({
      'pinnedMembers': newPinned,
    });

    setState(() {
      _pinnedMembers = newPinned;
    });
  }

  // Check if current user is owner or admin of the group
  Future<bool> _isOwnerOrAdminOfGroup(String groupId) async {
    if (groupId == 'global') return false;
    final doc = await FirebaseFirestore.instance.collection('groups').doc(groupId).get();
    if (!doc.exists) return false;
    final data = doc.data()!;
    final ownerId = data['ownerId'] as String?;
    final admins = List<String>.from(data['admins'] ?? []);
    return ownerId == widget.currentUserId || admins.contains(widget.currentUserId);
  }

  // Edit placeholder member location
  Future<void> _editPlaceholderLocation(UserLocation element) async {
    final result = await showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: LocationPicker(
            currentUserId: widget.currentUserId,
            defaultCountry: element.nation,
            defaultState: element.state,
            initialStartDate: widget.date,
            initialEndDate: widget.date,
            onLocationSelected: (country, state, startDate, endDate, selectedMemberIds) async {
              // Save the placeholder location
              await _firestoreService.setPlaceholderMemberLocationRange(
                element.userId,
                element.groupId,
                startDate,
                endDate,
                country,
                state,
              );
              Navigator.pop(context, true);
            },
          ),
        ),
      ),
    );
    if (result == true && mounted) {
      Navigator.pop(context); // Refresh detail modal
    }
  }

  // Delete placeholder member location
  Future<void> _deletePlaceholderLocation(UserLocation element) async {
    // Check if placeholder has a default location
    final placeholderDoc = await FirebaseFirestore.instance
        .collection('placeholder_members')
        .doc(element.userId)
        .get();
    final defaultLocation = placeholderDoc.data()?['defaultLocation'] as String?;
    final hasDefaultLocation = defaultLocation != null && defaultLocation.isNotEmpty;
    final placeholderName = placeholderDoc.data()?['displayName'] ?? 'this placeholder';
    
    if (!mounted) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Location?'),
        content: Text(hasDefaultLocation
          ? 'This will revert $placeholderName\'s location to their default ($defaultLocation) for this date.'
          : 'This will remove $placeholderName\'s location for this date (no default location set).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final dateStr = "${widget.date.year}${widget.date.month.toString().padLeft(2, '0')}${widget.date.day.toString().padLeft(2, '0')}";
      // Note: placeholder_member_locations docId does NOT include groupId (unlike user_locations)
      final docId = "${element.userId}_$dateStr";
      
      // Always delete the document - app will fall back to default from placeholder profile
      await FirebaseFirestore.instance.collection('placeholder_member_locations').doc(docId).delete();
      
      if (mounted) Navigator.pop(context); // Refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Details for ${widget.date.toLocal().toString().split(' ')[0]}",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          
          // Religious Calendar Dates
          FutureBuilder<List<String>>(
            future: _getReligiousDates(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 5),
                    ...snapshot.data!.map((date) => Text(
                      date,
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                    )),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          
          const SizedBox(height: 10),
          
          // Holidays
          if (widget.holidays.isNotEmpty) ...[
            const Text("Holidays", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            ...widget.holidays.map((h) => ListTile(
              leading: const Icon(Icons.star, color: Colors.red),
              title: Text(h.localName),
              subtitle: Text(h.countryCode),
            )),
            const Divider(),
          ],

          // Birthdays
          if (widget.birthdays.isNotEmpty) ...[
            const Text("Birthdays 🎂", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            ...widget.birthdays.map((b) => ListTile(
              leading: Icon(
                b.isLunar ? Icons.nights_stay : Icons.cake, 
                color: b.isLunar ? Colors.orange : Colors.green,
              ),
              title: Text(b.isLunar ? "${b.displayName} [lunar birthday]" : b.displayName),
              subtitle: b.isLunar ? null : Text("Turning ${b.age} years old"),
            )),
            const Divider(),
          ],

          // Events
          if (widget.events.isNotEmpty) ...[
             const Text("Events", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
             ...widget.events.map((e) {
               final isOwner = e.creatorId == widget.currentUserId;
               return ListTile(
                 leading: const Icon(Icons.event, color: Colors.blue),
                 title: Text(
                   "${e.title} (${e.hasTime ? DateFormat('yyyy-MM-dd HH:mm').format(e.date) : DateFormat('yyyy-MM-dd').format(e.date)})",
                   maxLines: 1,
                   overflow: TextOverflow.ellipsis,
                   style: const TextStyle(fontWeight: FontWeight.bold),
                 ),
                 subtitle: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     if (e.description.isNotEmpty)
                       Text(
                         e.description,
                         maxLines: 3,
                         overflow: TextOverflow.ellipsis,
                         style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                       ),
                     if (e.venue != null && e.venue!.isNotEmpty)
                       Row(
                         children: [
                           const Icon(Icons.location_on, size: 14, color: Colors.grey),
                           const SizedBox(width: 4),
                           Expanded(
                             child: Text(
                               e.venue!,
                               style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey),
                               maxLines: 1,
                               overflow: TextOverflow.ellipsis,
                             ),
                           ),
                         ],
                       ),
                     FutureBuilder<DocumentSnapshot>(
                       future: FirebaseFirestore.instance.collection('users').doc(e.creatorId).get(),
                       builder: (context, snapshot) {
                         if (snapshot.hasData) {
                           final data = snapshot.data!.data() as Map<String, dynamic>?;
                           return Text("Owner: ${data?['displayName'] ?? 'Unknown'}", style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12));
                         }
                         return const SizedBox.shrink();
                       },
                     ),
                   ],
                 ),
                 trailing: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     // Edit button - all members can edit
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        tooltip: 'Edit Event',
                        onPressed: () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) => AddEventModal(
                              currentUserId: widget.currentUserId,
                              initialDate: e.date,
                              eventToEdit: e,
                            ),
                          );
                        },
                      ),
                      // History button - shows if has edit history
                      if (e.editHistory != null && e.editHistory!.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.history, color: Colors.orange),
                          tooltip: 'View History (${e.editHistory!.length})',
                          onPressed: () => _showVersionHistoryDialog(e),
                        ),
                      // Delete button - only owner or admin
                      if (isOwner || _adminGroups.contains(e.groupId))
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete Event',
                          onPressed: () async {
                            await _firestoreService.deleteEvent(e.id);
                            if (mounted) Navigator.pop(context);
                          },
                        ),
                     IconButton(
                        icon: const Icon(Icons.bar_chart, color: Colors.deepPurple),
                        tooltip: 'RSVP Stats',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => RSVPManagementDialog(
                              currentUserId: widget.currentUserId,
                            ),
                          );
                        },
                      ),
                     const SizedBox(width: 8),
                     ElevatedButton(
                       onPressed: () => _showRSVPDialog(e),
                       child: const Text("RSVP"),
                     ),
                   ],
                 ),
               );
             }),
             const Divider(),
          ],

          // Locations (Grouped) - Deduplicated
          Expanded(
            child: Builder(
              builder: (context) {
                final deduplicatedLocations = _getDeduplicatedLocations();
                
                if (deduplicatedLocations.isEmpty) {
                  return const Center(child: Text("No member locations set."));
                }
                
                return GroupedListView<UserLocation, String>(
                  elements: deduplicatedLocations,
                  groupBy: (element) {
                    // Current user always at top
                    if (element.userId == widget.currentUserId) {
                      return "___CURRENT_USER"; // Special key to sort first
                    }
                    // Pinned members second
                    if (_pinnedMembers.contains(element.userId)) {
                      return "___FAVORITES";
                    }
                    // Group by actual group name
                    return element.groupId;
                  },
                  groupComparator: (value1, value2) {
                    if (value1 == "___CURRENT_USER") return -1;
                    if (value2 == "___CURRENT_USER") return 1;
                    if (value1 == "___FAVORITES") return -1;
                    if (value2 == "___FAVORITES") return 1;
                    return value1.compareTo(value2);
                  },
                  groupSeparatorBuilder: (String value) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      value == "___CURRENT_USER" 
                        ? "You" 
                        : value == "___FAVORITES" 
                          ? "Favorites" 
                          : (_groupNames[value] ?? value),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                  itemBuilder: (context, element) {
                    final user = _userDetails[element.userId];
                    final name = user?['displayName'] ?? user?['email'] ?? "Unknown User";
                    final photoUrl = user?['photoURL'];
                    final isPinned = _pinnedMembers.contains(element.userId);
                    final isCurrentUser = element.userId == widget.currentUserId;
                    final isPlaceholder = element.userId.startsWith('placeholder_');

                    return FutureBuilder<bool>(
                      future: isPlaceholder ? _isOwnerOrAdminOfGroup(element.groupId) : Future.value(false),
                      builder: (context, canEditSnapshot) {
                        final canEditPlaceholder = canEditSnapshot.data ?? false;

                        return ListTile(
                          leading: isPlaceholder
                            ? CircleAvatar(
                                backgroundColor: Colors.grey[300],
                                child: const Icon(Icons.person_outline, color: Colors.grey),
                              )
                            : UserAvatar(
                                photoUrl: photoUrl,
                                name: name,
                                radius: 20,
                              ),
                          title: Text(name),
                          subtitle: element.nation == "No location selected"
                            ? Text(
                                "No location selected",
                                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                              )
                            : Text("${element.nation}${element.state != null && element.state!.isNotEmpty ? ', ${element.state}' : ''}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Edit for placeholder members (owner/admin only)
                              if (isPlaceholder && canEditPlaceholder) ...[
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                  onPressed: () => _editPlaceholderLocation(element),
                                  tooltip: 'Edit Placeholder Location',
                                ),
                                // Delete for placeholder members (only when location is set)
                                if (element.nation != "No location selected")
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                    onPressed: () => _deletePlaceholderLocation(element),
                                    tooltip: 'Delete Placeholder Location',
                                  ),
                              ],
                              // Edit for own location OR manageable members (always available)
                              if (isCurrentUser || _manageableMembers.contains(element.userId))
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () async {
                                    // Target user for editing
                                    final targetUserId = element.userId;
                                    
                                    // Fetch target user's default location for pre-population
                                    final userDoc = await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(targetUserId)
                                        .get();
                                    final defaultLocation = userDoc.data()?['defaultLocation'] as String?;
                                    
                                    // Helper function to remove emoji flags
                                    String stripEmojis(String text) {
                                      return text.replaceAll(RegExp(r'[\u{1F1E6}-\u{1F1FF}]|\p{Emoji_Presentation}|\p{Emoji}\uFE0F', unicode: true), '').trim();
                                    }
                                    
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
                                    
                                    if (!mounted) return;
                                    
                                    // Show location picker to edit
                                    final result = await showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        child: Container(
                                          constraints: const BoxConstraints(maxWidth: 500),
                                          child: LocationPicker(
                                            currentUserId: widget.currentUserId,
                                            defaultCountry: defaultCountry ?? element.nation,
                                            defaultState: defaultState ?? element.state,
                                            initialStartDate: widget.date,
                                            initialEndDate: widget.date, // Default to single day
                                            onLocationSelected: (country, state, startDate, endDate, selectedMemberIds) async {
                                              // Save the updated location for the target user
                                              await _firestoreService.setLocationRange(
                                                targetUserId,
                                                element.groupId,
                                                startDate,
                                                endDate,
                                                country,
                                                state,
                                              );
                                              Navigator.pop(context, true); // Return true to indicate success
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                    if (result == true && mounted) {
                                      Navigator.pop(context); // Refresh detail modal
                                    }
                                  },
                                  tooltip: isCurrentUser ? 'Edit Location' : 'Edit Member Location',
                                ),
                              // Delete only shows when there's an actual location (not "No location selected")
                              if ((isCurrentUser || _manageableMembers.contains(element.userId)) && 
                                  element.nation != "No location selected")
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                  onPressed: () async {
                                    final targetUserId = element.userId;
                                    final targetName = _userDetails[targetUserId]?['displayName'] ?? 'this member';
                                    
                                    // Check if target user has a default location
                                    final userDoc = await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(targetUserId)
                                        .get();
                                    final defaultLocation = userDoc.data()?['defaultLocation'] as String?;
                                    final hasDefaultLocation = defaultLocation != null && defaultLocation.isNotEmpty;
                                    
                                    if (!mounted) return;
                                    
                                    // Delete location - reverts to default or removes entirely
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Delete Location?'),
                                        content: Text(hasDefaultLocation
                                          ? (isCurrentUser 
                                              ? 'This will revert to your default location ($defaultLocation) for this date.'
                                              : 'This will revert $targetName\'s location to their default ($defaultLocation) for this date.')
                                          : (isCurrentUser
                                              ? 'This will remove your location for this date (no default location set).'
                                              : 'This will remove $targetName\'s location for this date (no default location set).')),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                    
                                    if (confirm == true) {
                                      final dateStr = "${widget.date.year}${widget.date.month.toString().padLeft(2, '0')}${widget.date.day.toString().padLeft(2, '0')}";
                                      final docId = "${targetUserId}_${element.groupId}_$dateStr";
                                      
                                      // Always delete the document - app will fall back to default from user profile
                                      await FirebaseFirestore.instance.collection('user_locations').doc(docId).delete();
                                      
                                      if (mounted) Navigator.pop(context); // Refresh
                                    }
                                  },
                                  tooltip: isCurrentUser ? 'Delete (Revert to Default)' : 'Delete Member Location',
                                ),
                          // Pin button for all users
                          IconButton(
                            icon: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                            color: isPinned ? Colors.blue : Colors.grey,
                            onPressed: () => _togglePin(element.userId),
                          ),
                        ],
                      ),
                    );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showRSVPDialog(GroupEvent event) {
    final isAdmin = _adminGroups.contains(event.groupId);
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            event.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current user's RSVP
                  const Text("Your Response:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildRSVPChip(event, widget.currentUserId, 'No', Colors.red, dialogContext, setDialogState),
                      _buildRSVPChip(event, widget.currentUserId, 'Maybe', Colors.orange, dialogContext, setDialogState),
                      _buildRSVPChip(event, widget.currentUserId, 'Yes', Colors.green, dialogContext, setDialogState),
                    ],
                  ),
                  
                  // Admin section for setting others' RSVPs
                  if (isAdmin) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text("Set RSVP for Others:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    FutureBuilder<List<dynamic>>(
                      future: _loadMembersAndPlaceholders(event.groupId),
                      builder: (ctx, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ));
                        }
                        final members = snapshot.data![0] as List<Map<String, dynamic>>;
                        final placeholders = snapshot.data![1] as List<PlaceholderMember>;
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Regular members (excluding current user)
                            if (members.where((m) => m['uid'] != widget.currentUserId).isNotEmpty) ...[
                              Text("Members:", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              const SizedBox(height: 4),
                              ...members.where((m) => m['uid'] != widget.currentUserId).map((member) {
                                final userId = member['uid'] as String;
                                final name = member['displayName'] ?? member['email'] ?? 'Unknown';
                                return _buildMemberRSVPRow(
                                  event, userId, name, 
                                  event.rsvps[userId] ?? 'No Response',
                                  Icons.person, dialogContext, setDialogState,
                                );
                              }),
                            ],
                            // Placeholder members
                            if (placeholders.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text("Placeholder Members:", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              const SizedBox(height: 4),
                              ...placeholders.map((placeholder) {
                                return _buildMemberRSVPRow(
                                  event, placeholder.id, placeholder.displayName,
                                  event.rsvps[placeholder.id] ?? 'No Response',
                                  Icons.person_outline, dialogContext, setDialogState,
                                );
                              }),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Close"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRSVPChip(GroupEvent event, String userId, String status, Color color, BuildContext dialogContext, StateSetter setDialogState) {
    final currentStatus = event.rsvps[userId];
    final isSelected = currentStatus == status;
    return ChoiceChip(
      label: Text(status),
      selected: isSelected,
      selectedColor: color.withOpacity(0.3),
      onSelected: (_) {
        _firestoreService.rsvpEvent(event.id, userId, status);
        // Update local state so UI reflects change
        setDialogState(() {
          event.rsvps[userId] = status;
        });
        Navigator.pop(dialogContext);
      },
    );
  }

  Widget _buildMemberRSVPRow(
    GroupEvent event, String memberId, String name, String currentRsvp,
    IconData icon, BuildContext dialogContext, StateSetter setDialogState,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1),
          ),
          PopupMenuButton<String>(
            initialValue: currentRsvp == 'No Response' ? null : currentRsvp,
            child: Chip(
              label: Text(currentRsvp, style: const TextStyle(fontSize: 11)),
              backgroundColor: currentRsvp == 'Yes' ? Colors.green[100] 
                  : currentRsvp == 'No' ? Colors.red[100] 
                  : currentRsvp == 'Maybe' ? Colors.orange[100] 
                  : Colors.grey[200],
              visualDensity: VisualDensity.compact,
            ),
            onSelected: (status) {
              _firestoreService.rsvpEvent(event.id, memberId, status);
              // Update UI
              setDialogState(() {
                event.rsvps[memberId] = status;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Yes', child: Text('✓ Yes')),
              const PopupMenuItem(value: 'Maybe', child: Text('? Maybe')),
              const PopupMenuItem(value: 'No', child: Text('✗ No')),
            ],
          ),
        ],
      ),
    );
  }

  Future<List<dynamic>> _loadMembersAndPlaceholders(String groupId) async {
    // Load group members
    final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(groupId).get();
    final memberIds = List<String>.from(groupDoc.data()?['members'] ?? []);
    
    final members = <Map<String, dynamic>>[];
    for (final memberId in memberIds) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(memberId).get();
      if (userDoc.exists) {
        final data = Map<String, dynamic>.from(userDoc.data()!);
        data['uid'] = memberId;
        members.add(data);
      }
    }
    
    // Load placeholder members
    final placeholdersSnapshot = await FirebaseFirestore.instance
        .collection('placeholder_members')
        .where('groupId', isEqualTo: groupId)
        .get();
    final placeholders = placeholdersSnapshot.docs
        .map((doc) => PlaceholderMember.fromFirestore(doc))
        .toList();
    
    return [members, placeholders];
  }

  void _showVersionHistoryDialog(GroupEvent event) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.history, color: Colors.orange),
            const SizedBox(width: 8),
            const Text("Version History"),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current version
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.title, 
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(event.description, 
                          maxLines: 3, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13)),
                        if (event.venue != null && event.venue!.isNotEmpty)
                          Text("📍 ${event.venue!}", 
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        // Show editor name
                        FutureBuilder<String>(
                          future: _getEditorName(event.lastEditedBy ?? event.creatorId),
                          builder: (ctx, snap) {
                            final editorName = snap.data ?? 'Unknown';
                            return Text(
                              "Current • by $editorName • ${event.lastEditedAt != null ? _formatTimestamp(event.lastEditedAt!) : 'Just now'}",
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text("Previous Versions:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                // Previous versions
                ...event.editHistory!.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final version = entry.value;
                  final title = version['title'] ?? 'No title';
                  final desc = version['description'] ?? '';
                  final venue = version['venue'];
                  final editedBy = version['editedBy'];
                  final editedAt = version['editedAt'];
                  final editedAtStr = editedAt != null 
                      ? _formatTimestamp((editedAt as Timestamp).toDate())
                      : 'Unknown';
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, 
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(desc, maxLines: 3, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13)),
                                if (venue != null && venue.isNotEmpty)
                                  Text("📍 $venue", 
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 8),
                                FutureBuilder<String>(
                                  future: _getEditorName(editedBy),
                                  builder: (ctx, snap) {
                                    final editorName = snap.data ?? 'Unknown';
                                    return Text(
                                      "V${event.editHistory!.length - idx} • by $editorName • $editedAtStr",
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _revertToVersion(event, version, dialogContext),
                            child: const Text("Revert"),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

  Future<String> _getEditorName(String? userId) async {
    if (userId == null) return 'Unknown';
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['displayName'] ?? doc.data()?['email'] ?? 'Unknown';
      }
    } catch (_) {}
    return 'Unknown';
  }

  Future<void> _revertToVersion(GroupEvent event, Map<String, dynamic> version, BuildContext dialogContext) async {
    final confirm = await showDialog<bool>(
      context: dialogContext,
      builder: (_) => AlertDialog(
        title: const Text("Revert to this version?"),
        content: Text("This will restore the event to:\n\nTitle: ${version['title']}\nDescription: ${version['description']}"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Revert")),
        ],
      ),
    );
    
    if (confirm == true) {
      // Create reverted event
      final revertedEvent = GroupEvent(
        id: event.id,
        groupId: event.groupId,
        creatorId: event.creatorId,
        title: version['title'] ?? event.title,
        description: version['description'] ?? event.description,
        venue: version['venue'],
        date: version['date'] != null ? (version['date'] as Timestamp).toDate() : event.date,
        hasTime: event.hasTime,
        rsvps: event.rsvps,
      );
      await _firestoreService.updateEvent(revertedEvent, widget.currentUserId);
      if (mounted) {
        Navigator.pop(dialogContext);
        Navigator.pop(context); // Close detail modal to refresh
      }
    }
  }
}
