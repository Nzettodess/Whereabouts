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
import 'widgets/skeleton_loading.dart';
import 'rsvp_management.dart';
import 'edit_member_dialog.dart';
import 'widgets/user_profile_dialog.dart';
import 'widgets/rich_description_viewer.dart';
import 'widgets/event_detail_dialog.dart';

class DetailModal extends StatefulWidget {
  final DateTime date;
  final List<UserLocation> locations;
  final List<GroupEvent> events;
  final List<Holiday> holidays;
  final List<Birthday> birthdays;
  final String currentUserId;
  final bool canWrite; // Whether write operations are allowed (false if session terminated)
  final List<Map<String, dynamic>> allUsers; // Pre-loaded users from home to avoid re-fetching

  const DetailModal({
    super.key,
    required this.date,
    required this.locations,
    required this.events,
    required this.holidays,
    required this.birthdays,
    required this.currentUserId,
    this.canWrite = true, // Default to true for backwards compatibility
    this.allUsers = const [], // Default empty for backwards compatibility
  });

  @override
  State<DetailModal> createState() => _DetailModalState();
}

class _DetailModalState extends State<DetailModal> {
  final FirestoreService _firestoreService = FirestoreService();
  
  // Static cache for member names (persists across modal openings until app reload)
  static Map<String, Map<String, dynamic>> _userDetailsCache = {};
  
  Map<String, String> _groupNames = {}; // Map groupId -> groupName
  List<String> _pinnedMembers = [];
  Set<String> _manageableMembers = {}; // Members the current user can edit (as admin/owner)
  Set<String> _adminGroups = {}; // Groups where current user is owner or admin
  
  // Static method to clear cache (call on logout or explicit refresh)
  static void clearUserCache() {
    _userDetailsCache.clear();
  }

  // Session-based expansion state memory PER DATE (static to persist across modal reopens)
  // Key: "yyyy-MM-dd", Value: expansion state (default true if not set)
  static final Map<String, bool> _birthdaysExpandedByDate = {};
  static final Map<String, bool> _eventsExpandedByDate = {};

  // Helper to get date key for state maps
  String get _dateKey => '${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}';

  // Get/set expansion state for this specific date
  bool get _birthdaysExpanded => _birthdaysExpandedByDate[_dateKey] ?? true;
  set _birthdaysExpanded(bool value) => _birthdaysExpandedByDate[_dateKey] = value;
  
  bool get _eventsExpanded => _eventsExpandedByDate[_dateKey] ?? true;
  set _eventsExpanded(bool value) => _eventsExpandedByDate[_dateKey] = value;

  @override
  void initState() {
    super.initState();
    
    // Pre-populate cache from allUsers (already loaded in home page)
    _populateCacheFromAllUsers();
    
    _loadUserDetails(); // Load any missing users (e.g., placeholders)
    _loadPinnedMembers();

    _loadGroupNames();
    _loadManageableMembers();
  }
  
  /// Pre-populate cache from widget.allUsers to avoid re-fetching
  void _populateCacheFromAllUsers() {
    for (final user in widget.allUsers) {
      final uid = user['uid'] as String?;
      if (uid != null && !_userDetailsCache.containsKey(uid)) {
        _userDetailsCache[uid] = user;
      }
    }
  }
  
  /// Check if writes are allowed, show dialog if not
  bool _checkCanWrite() {
    if (!widget.canWrite) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(children: [
            Icon(Icons.block, color: Colors.red[700], size: 22),
            const SizedBox(width: 8),
            const Text('Read-Only Mode'),
          ]),
          content: const Text(
            'This session was terminated. You cannot make changes.\n\nClick "Resume" in the banner to start a new session.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
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
    // Load group names for all groups in locations and events
    final groupIds = {
      ...widget.locations.map((l) => l.groupId),
      ...widget.events.map((e) => e.groupId),
    };
    
    for (final groupId in groupIds) {
      if (_groupNames.containsKey(groupId)) continue;
      
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
    bool needsUpdate = false;
    
    for (final uid in userIds) {
      if (!_userDetailsCache.containsKey(uid)) {
        // Check if this is a placeholder member
        if (uid.startsWith('placeholder_')) {
          final doc = await FirebaseFirestore.instance.collection('placeholder_members').doc(uid).get();
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            _userDetailsCache[uid] = {
              'displayName': data['displayName'] ?? 'Placeholder',
              'photoURL': null,
              'isPlaceholder': true,
              'groupId': data['groupId'],
              'defaultLocation': data['defaultLocation'],
              'birthday': data['birthday'],
              'hasLunarBirthday': data['hasLunarBirthday'] ?? false,
              'lunarBirthdayMonth': data['lunarBirthdayMonth'],
              'lunarBirthdayDay': data['lunarBirthdayDay'],
            };
            needsUpdate = true;
          }
        } else {
          // Regular user
          final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          if (doc.exists) {
            _userDetailsCache[uid] = doc.data() as Map<String, dynamic>;
            needsUpdate = true;
          }
        }
      }
    }
    
    // Only rebuild if we actually loaded new data
    if (needsUpdate && mounted) {
      setState(() {});
    }
  }

  Future<void> _togglePin(String userId) async {
    if (!_checkCanWrite()) return;
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



  // Delete placeholder member location
  Future<void> _deletePlaceholderLocation(UserLocation element) async {
    if (!_checkCanWrite()) return;
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

  Future<void> _editPlaceholderLocation(UserLocation element) async {
    if (!_checkCanWrite()) return;
    final userData = _userDetailsCache[element.userId] ?? {};
    final placeholderName = userData['displayName'] ?? 'Placeholder';
    
    // Show location picker for date-specific editing - uses the standard "Set Location" UI
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Header with member name
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Set Location for $placeholderName",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      if (Navigator.of(sheetContext).canPop()) {
                        Navigator.of(sheetContext).pop();
                      }
                    },
                  ),
                ],
              ),
            ),
            // Standard LocationPicker UI
            LocationPicker(
              currentUserId: widget.currentUserId,
              defaultCountry: element.nation != "No location selected" ? element.nation : null,
              defaultState: element.state,
              initialStartDate: widget.date,
              initialEndDate: widget.date,
              placeholderMembers: [],
              groupMembers: [],
              isOwnerOrAdmin: false,
              onLocationSelected: (country, state, startDate, endDate, selectedMemberIds) async {
                final isoDate = "${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}";
                final dateStr = isoDate.replaceAll('-', '');
                final docId = "${element.userId}_$dateStr";
                
                await FirebaseFirestore.instance
                    .collection('placeholder_member_locations')
                    .doc(docId)
                    .set({
                      'placeholderMemberId': element.userId,
                      'groupId': element.groupId,
                      'date': isoDate,
                      'nation': country,
                      'state': state,
                    });
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("$placeholderName's location updated")),
                  );
                }
              },
            ),
          ],
        ),
       ),
      ),
    );
    if (result == true && mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      height: MediaQuery.of(context).size.height * 0.9,
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Sticky Header Section
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
          
          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [


          
          // Holidays
          if (widget.holidays.isNotEmpty) ...[
            const Text("Holidays", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            ...widget.holidays.map((h) => ListTile(
              contentPadding: const EdgeInsets.only(left: 16.0, right: 2.0),
              visualDensity: VisualDensity.compact,
              leading: const Icon(Icons.star, color: Colors.red),
              title: Text(h.localName),
              subtitle: Text(h.countryCode),
            )),
            ],

          // Birthdays
          if (widget.birthdays.isNotEmpty)
            ExpansionTile(
              title: const Text("Birthdays 🎂", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              initiallyExpanded: _birthdaysExpanded,
              onExpansionChanged: (expanded) => _birthdaysExpanded = expanded,
              shape: const Border(),
              collapsedShape: const Border(),
              tilePadding: EdgeInsets.zero,
              children: widget.birthdays.map((b) => ListTile(
                contentPadding: const EdgeInsets.only(left: 16.0, right: 2.0),
                visualDensity: VisualDensity.compact,
                leading: b.isLunar 
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: Center(child: Text('🏮', style: TextStyle(fontSize: 20))),
                      )
                    : const Icon(Icons.cake, color: Colors.green),
                title: Text(b.isLunar ? "${b.displayName} [lunar birthday]" : b.displayName),
                subtitle: b.isLunar ? null : Text("Turning ${b.age} years old"),
              )).toList(),
            ),

          


          // Events
          if (widget.events.isNotEmpty)
             ExpansionTile(
               title: const Text("Events", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
               initiallyExpanded: _eventsExpanded,
               onExpansionChanged: (expanded) => _eventsExpanded = expanded,
               shape: const Border(),
               collapsedShape: const Border(),
               tilePadding: EdgeInsets.zero,
               children: widget.events.map((e) {
               final isOwner = e.creatorId == widget.currentUserId;
               return ListTile(
                 contentPadding: const EdgeInsets.only(left: 16.0, right: 2.0),
                 visualDensity: VisualDensity.compact,
                 onTap: () {
                   showEventDetailDialog(
                      context, 
                      e, 
                      groupName: _groupNames[e.groupId],
                    );
                 },
                 leading: const Icon(Icons.event, color: Colors.blue),
                 title: Text(
                   e.title,
                   maxLines: 1,
                   overflow: TextOverflow.ellipsis,
                   style: const TextStyle(fontWeight: FontWeight.bold),
                 ),
                 subtitle: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     // Show Group Name at the top for context
                     Text("Group: ${_groupNames[e.groupId] ?? 'Loading...'}", 
                       style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor, fontWeight: FontWeight.bold)),
                     const SizedBox(height: 2),
                     // Time display - show if event has time
                     if (e.hasTime)
                       Row(
                         children: [
                           const Icon(Icons.access_time, size: 14, color: Colors.deepPurple),
                           const SizedBox(width: 4),
                           Text(
                             DateFormat('h:mm a').format(e.date),
                             style: const TextStyle(fontSize: 12, color: Colors.deepPurple, fontWeight: FontWeight.w500),
                           ),
                         ],
                       ),
                     if (e.description.isNotEmpty)
                       RichDescriptionPreview(
                         description: e.description,
                         maxLength: 80,
                         style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor),
                       ),
                     if (e.venue != null && e.venue!.isNotEmpty)
                       VenueLinkText(
                         venue: e.venue!,
                         style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Theme.of(context).hintColor),
                       ),
                     FutureBuilder<DocumentSnapshot>(
                       future: FirebaseFirestore.instance.collection('users').doc(e.creatorId).get(),
                       builder: (context, snapshot) {
                         if (snapshot.hasData) {
                           final data = snapshot.data!.data() as Map<String, dynamic>?;
                           return Text("Owner: ${data?['displayName'] ?? 'Unknown'}", style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Theme.of(context).hintColor));
                         }
                         return const SizedBox.shrink();
                     },
                   ),
                 ],  // Close Column children
               ),  // Close Column (subtitle)

                  trailing: Builder(builder: (context) {
                    final isNarrow = MediaQuery.of(context).size.width < 450;
                    final iconSize = isNarrow ? 24.0 : 28.0;
                    final btnSize = isNarrow ? 36.0 : 40.0;
                    
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Edit button
                        SizedBox(
                          width: btnSize,
                          height: btnSize,
                          child: IconButton(
                            icon: Icon(Icons.edit, color: Colors.blue, size: iconSize),
                            tooltip: 'Edit',
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              if (!_checkCanWrite()) return;
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
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
                        ),
                        // History button
                        if (e.editHistory != null && e.editHistory!.isNotEmpty)
                          SizedBox(
                            width: btnSize,
                            height: btnSize,
                            child: IconButton(
                              icon: Icon(Icons.history, color: Colors.orange, size: iconSize),
                              tooltip: 'History',
                              padding: EdgeInsets.zero,
                              onPressed: () => _showVersionHistoryDialog(e),
                            ),
                          ),
                        // Delete button
                        if (isOwner || _adminGroups.contains(e.groupId))
                          SizedBox(
                            width: btnSize,
                            height: btnSize,
                            child: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red, size: iconSize),
                              tooltip: 'Delete',
                              padding: EdgeInsets.zero,
                              onPressed: () async {
                                if (!_checkCanWrite()) return;
                                await _firestoreService.deleteEvent(e.id, widget.currentUserId);
                                if (mounted) {
                                  if (Navigator.of(context).canPop()) {
                                    Navigator.of(context).pop();
                                  }
                                }
                              },
                            ),
                          ),
                        // RSVP Stats button
                        SizedBox(
                          width: btnSize,
                          height: btnSize,
                          child: IconButton(
                            icon: Icon(Icons.bar_chart, color: Colors.deepPurple, size: iconSize),
                            tooltip: 'RSVP Stats',
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              if (!_checkCanWrite()) return;
                              showDialog(
                                context: context,
                                builder: (context) => RSVPManagementDialog(
                                  currentUserId: widget.currentUserId,
                                ),
                              );
                            },
                          ),
                        ),
                        // RSVP Button
                        SizedBox(
                          width: btnSize,
                          height: btnSize,
                          child: IconButton(
                            icon: Icon(Icons.how_to_reg, color: Colors.green, size: iconSize),
                            tooltip: 'RSVP',
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              if (!_checkCanWrite()) return;
                              _showRSVPDialog(e);
                            },
                          ),
                        ),
                      ],
                    );
                  }),
               );
             }).toList(),
             ),
          


          // Locations (Grouped) - Deduplicated
          Builder(
            builder: (context) {
              final deduplicatedLocations = _getDeduplicatedLocations();
              
              if (deduplicatedLocations.isEmpty) {
                return const Center(child: Text("No member locations set."));
              }
              
              return GroupedListView<UserLocation, String>(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
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
                    final user = _userDetailsCache[element.userId];
                    final name = user?['displayName'] ?? user?['email'] ?? "Unknown User";
                    final photoUrl = user?['photoURL'];
                    final isPinned = _pinnedMembers.contains(element.userId);
                    final isCurrentUser = element.userId == widget.currentUserId;
                    final isPlaceholder = element.userId.startsWith('placeholder_');

                    return FutureBuilder<bool>(
                      future: isPlaceholder ? _isOwnerOrAdminOfGroup(element.groupId) : Future.value(false),
                      builder: (context, canEditSnapshot) {
                        final canEditPlaceholder = canEditSnapshot.data ?? false;

                        return GestureDetector(
                          onTap: () => _showUserProfileDialog(element, user),
                          child: ListTile(
                            contentPadding: const EdgeInsets.only(left: 16.0, right: 2.0),
                            visualDensity: VisualDensity.compact,
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
                          trailing: Builder(builder: (context) {
                            final isNarrow = MediaQuery.of(context).size.width < 450;
                            final iconSize = isNarrow ? 22.0 : 26.0;
                            final btnSize = isNarrow ? 34.0 : 38.0;
                            final iconPadding = isNarrow ? 1.0 : 2.0;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                              // Edit for placeholder members (owner/admin only)
                              if (isPlaceholder && canEditPlaceholder) ...[
                                SizedBox(
                                  width: btnSize,
                                  height: btnSize,
                                  child: IconButton(
                                    icon: Icon(Icons.edit, size: iconSize, color: Colors.blue),
                                    padding: EdgeInsets.zero,
                                    onPressed: () => _editPlaceholderLocation(element),
                                    tooltip: 'Edit',
                                  ),
                                ),
                                // Delete for placeholder members (only when location is set)
                                if (element.nation != "No location selected")
                                  IconButton(
                                    icon: Icon(Icons.delete, size: iconSize, color: Colors.red),
                                    padding: EdgeInsets.all(iconPadding),
                                    constraints: BoxConstraints(minWidth: iconSize + 8, minHeight: iconSize + 8),
                                    onPressed: () => _deletePlaceholderLocation(element),
                                    tooltip: 'Delete Placeholder Location',
                                  ),
                              ],
                              // Edit for own location OR manageable members (always available)
                              if (isCurrentUser || _manageableMembers.contains(element.userId))
                                IconButton(
                                  icon: Icon(Icons.edit, size: iconSize),
                                  padding: EdgeInsets.all(iconPadding),
                                  constraints: BoxConstraints(minWidth: iconSize + 8, minHeight: iconSize + 8),
                                  onPressed: () async {
                                    if (!_checkCanWrite()) return;
                                    // Target user for editing
                                    final targetUserId = element.userId;
                                    final targetName = isCurrentUser ? "Myself" : name;
                                    
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
                                    
                                    // Show location picker with header showing member name
                                    final result = await showModalBottomSheet<bool>(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (sheetContext) => Padding(
                                        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
                                        child: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                            // Header with member name
                                            Container(
                                              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.person, color: Colors.blue),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      "Set Location for $targetName",
                                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.close),
                                                    onPressed: () {
                                                      if (Navigator.of(sheetContext).canPop()) {
                                                        Navigator.of(sheetContext).pop();
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Standard LocationPicker UI
                                            LocationPicker(
                                              currentUserId: widget.currentUserId,
                                              defaultCountry: defaultCountry ?? (element.nation != "No location selected" ? element.nation : null),
                                              defaultState: defaultState ?? element.state,
                                              initialStartDate: widget.date,
                                              initialEndDate: widget.date,
                                              onLocationSelected: (country, state, startDate, endDate, selectedMemberIds) async {
                                                await _firestoreService.setLocationRange(
                                                  targetUserId,
                                                  element.groupId,
                                                  startDate,
                                                  endDate,
                                                  country,
                                                  state,
                                                  );
                                              },
                                            ),
                                          ],
                                        ),
                                       ),
                                      ),
                                    );
                                    if (result == true && mounted) {
                                      if (Navigator.of(context).canPop()) {
                                        Navigator.of(context).pop(true); // Refresh detail modal
                                      }
                                    }

                                  },
                                  tooltip: isCurrentUser ? 'Edit Location' : 'Edit Member Location',
                                ),
                              // Delete only shows when there's an actual location (not "No location selected")
                              if ((isCurrentUser || _manageableMembers.contains(element.userId)) && 
                                  element.nation != "No location selected")
                                IconButton(
                                  icon: Icon(Icons.delete, size: iconSize, color: Colors.red),
                                  padding: EdgeInsets.all(iconPadding),
                                  constraints: BoxConstraints(minWidth: iconSize + 8, minHeight: iconSize + 8),
                                  onPressed: () async {
                                    if (!_checkCanWrite()) return;
                                    final targetUserId = element.userId;
                                    final targetName = _userDetailsCache[targetUserId]?['displayName'] ?? 'this member';
                                    
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
                                      await _firestoreService.deleteLocation(targetUserId, widget.date);
                                      if (mounted) {
                                        if (Navigator.of(context).canPop()) {
                                          Navigator.of(context).pop(true); // Refresh
                                        }
                                      }
                                    }
                                  },
                                  tooltip: isCurrentUser ? 'Delete (Revert to Default)' : 'Delete Member Location',
                                ),
                              // Pin button for all users
                              IconButton(
                                icon: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined, size: iconSize),
                                color: isPinned ? Colors.blue : Colors.grey,
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(minWidth: iconSize + 8, minHeight: iconSize + 8),
                                splashRadius: iconSize,
                                onPressed: () => _togglePin(element.userId),
                              ),

                            ],
                          );
                      }),
                    ),  // Close GestureDetector
                  );
                    },
                  );
                },
              );
            },
          ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


  void _showUserProfileDialog(UserLocation location, Map<String, dynamic>? userData) async {
    final isPlaceholder = location.userId.startsWith('placeholder_');
    final name = userData?['displayName'] ?? userData?['email'] ?? "Unknown User";
    final photoUrl = userData?['photoURL'];
    
    // Check editing permissions
    bool canEdit = false;
    if (isPlaceholder) {
      if (_adminGroups.contains(location.groupId)) {
        canEdit = true;
      } else {
        final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(location.groupId).get();
        if (groupDoc.exists) {
          final groupData = groupDoc.data()!;
          final ownerId = groupData['ownerId'];
          final admins = List<String>.from(groupData['admins'] ?? []);
          if (ownerId == widget.currentUserId || admins.contains(widget.currentUserId)) {
            canEdit = true;
          }
        }
      }
    } else {
      if (location.userId == widget.currentUserId) {
         canEdit = false; 
      } else if (_manageableMembers.contains(location.userId)) {
        canEdit = true;
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => UserProfileDialog(
        displayName: name,
        photoUrl: photoUrl,
        isPlaceholder: isPlaceholder,
        canEdit: canEdit,
        defaultLocation: userData?['defaultLocation'],
        birthday: userData?['birthday'] != null ? (userData!['birthday'] as Timestamp).toDate() : null,
        hasLunarBirthday: userData?['hasLunarBirthday'] ?? false,
        lunarBirthdayMonth: userData?['lunarBirthdayMonth'],
        lunarBirthdayDay: userData?['lunarBirthdayDay'],
        onEdit: () {
          if (!_checkCanWrite()) return;
          showDialog(
            context: context,
            builder: (_) => EditMemberDialog(
              memberId: location.userId,
              memberDetails: userData ?? {},
              groupId: location.groupId,
              isPlaceholder: isPlaceholder, // Pass isPlaceholder flag
              onSaved: () {
                _loadUserDetails(); // Refresh data
              },
            ),
          );
        },
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
                      _buildRSVPChip(event, widget.currentUserId, 'No', Colors.red, dialogContext, setDialogState, 'Myself'),
                      _buildRSVPChip(event, widget.currentUserId, 'Maybe', Colors.orange, dialogContext, setDialogState, 'Myself'),
                      _buildRSVPChip(event, widget.currentUserId, 'Yes', Colors.green, dialogContext, setDialogState, 'Myself'),
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
                            child: SkeletonListTile(),
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

  Widget _buildRSVPChip(GroupEvent event, String userId, String status, Color color, BuildContext dialogContext, StateSetter setDialogState, String responderName) {
    final currentStatus = event.rsvps[userId];
    final isSelected = currentStatus == status;
    return ChoiceChip(
      label: Text(status),
      selected: isSelected,
      selectedColor: color.withOpacity(0.3),
      onSelected: (_) {
      if (!_checkCanWrite()) return;
      _firestoreService.rsvpEvent(event.id, userId, status, responderName: responderName);
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
            child: Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                Color bgColor;
                Color textColor;
                
                if (currentRsvp == 'Yes') {
                  bgColor = isDark ? Colors.green.shade800 : Colors.green.shade100;
                  textColor = isDark ? Colors.green.shade100 : Colors.green.shade800;
                } else if (currentRsvp == 'No') {
                  bgColor = isDark ? Colors.red.shade800 : Colors.red.shade100;
                  textColor = isDark ? Colors.red.shade100 : Colors.red.shade800;
                } else if (currentRsvp == 'Maybe') {
                  bgColor = isDark ? Colors.orange.shade800 : Colors.orange.shade100;
                  textColor = isDark ? Colors.orange.shade100 : Colors.orange.shade800;
                } else {
                  bgColor = isDark ? Colors.grey.shade700 : Colors.grey.shade200;
                  textColor = isDark ? Colors.grey.shade200 : Colors.grey.shade700;
                }
                
                return Chip(
                  label: Text(currentRsvp, style: TextStyle(fontSize: 11, color: textColor)),
                  backgroundColor: bgColor,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
            onSelected: (status) {
            if (!_checkCanWrite()) return;
            _firestoreService.rsvpEvent(event.id, memberId, status, responderName: name);
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
                Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Card(
                      margin: EdgeInsets.zero,
                      color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark ? Colors.blue.shade700 : Colors.blue.shade300,
                          width: 1.5,
                        ),
                      ),
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
                                style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                            const SizedBox(height: 8),
                            // Show editor name
                            FutureBuilder<String>(
                              future: _getEditorName(event.lastEditedBy ?? event.creatorId),
                              builder: (ctx, snap) {
                                final editorName = snap.data ?? 'Unknown';
                                return Text(
                                  "Current • by $editorName • ${event.lastEditedAt != null ? _formatTimestamp(event.lastEditedAt!) : 'Just now'}",
                                  style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
                  return Builder(
                    builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Card(
                        color: isDark ? Colors.grey.shade900 : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: isDark ? BorderSide(color: Colors.grey.shade700) : BorderSide.none,
                        ),
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
                                        style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                                    const SizedBox(height: 8),
                                    FutureBuilder<String>(
                                      future: _getEditorName(editedBy),
                                      builder: (ctx, snap) {
                                        final editorName = snap.data ?? 'Unknown';
                                        return Text(
                                          "V${event.editHistory!.length - idx} • by $editorName • $editedAtStr",
                                          style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                               onPressed: () {
                                 if (!_checkCanWrite()) return;
                                 _revertToVersion(event, version, dialogContext);
                               },
                                child: const Text("Revert"),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
