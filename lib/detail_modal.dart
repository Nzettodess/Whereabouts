import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'firestore_service.dart';
import 'religious_calendar_helper.dart';
import 'location_picker.dart';
import 'add_event_modal.dart';
import 'widgets/user_avatar.dart';

class DetailModal extends StatefulWidget {
  final DateTime date;
  final List<UserLocation> locations;
  final List<GroupEvent> events;
  final List<Holiday> holidays;
  final String currentUserId;

  const DetailModal({
    super.key,
    required this.date,
    required this.locations,
    required this.events,
    required this.holidays,
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

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
    _loadPinnedMembers();
    _loadGroupNames();
  }

  Future<void> _loadGroupNames() async {
    // Load group names for all groups in locations
    final groupIds = widget.locations.map((l) => l.groupId).toSet();
    for (final groupId in groupIds) {
      final doc = await FirebaseFirestore.instance.collection('groups').doc(groupId).get();
      if (doc.exists) {
        setState(() {
          _groupNames[groupId] = doc.data()?['name'] ?? 'Unknown Group';
        });
      }
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
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          setState(() {
            _userDetails[uid] = doc.data() as Map<String, dynamic>;
          });
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

          // Events
          if (widget.events.isNotEmpty) ...[
             const Text("Events", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
             ...widget.events.map((e) {
               final isOwner = e.creatorId == widget.currentUserId;
               return ListTile(
                 leading: const Icon(Icons.event, color: Colors.green),
                 title: Text("${e.title} (${e.hasTime ? DateFormat('yyyy-MM-dd HH:mm').format(e.date) : DateFormat('yyyy-MM-dd').format(e.date)})"),
                 subtitle: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     if (e.description.isNotEmpty)
                       Text(
                         e.description,
                         softWrap: true,
                         maxLines: 3,
                         overflow: TextOverflow.ellipsis,
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
                     if (isOwner) ...[
                       IconButton(
                         icon: const Icon(Icons.edit, color: Colors.blue),
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
                       IconButton(
                         icon: const Icon(Icons.delete, color: Colors.red),
                         onPressed: () async {
                           await _firestoreService.deleteEvent(e.id);
                           if (mounted) Navigator.pop(context);
                         },
                       ),
                     ],
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

          // Locations (Grouped)
          Expanded(
            child: widget.locations.isEmpty 
              ? const Center(child: Text("No member locations set."))
              : GroupedListView<UserLocation, String>(
                  elements: widget.locations,
                  groupBy: (element) {
                    // Current user always at top
                    if (element.userId == widget.currentUserId) {
                      return "___CURRENT_USER"; // Special key to sort first
                    }
                    // Pinned members second
                    if (_pinnedMembers.contains(element.userId)) {
                      return "___FAVORITES";
                    }
                    // Then by group
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
                          : _groupNames[value] ?? "Group",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                  itemBuilder: (context, element) {
                    final user = _userDetails[element.userId];
                    final name = user?['displayName'] ?? user?['email'] ?? "Unknown User";
                    final photoUrl = user?['photoURL'];
                    final isPinned = _pinnedMembers.contains(element.userId);
                    final isCurrentUser = element.userId == widget.currentUserId;

                    return ListTile(
                      leading: UserAvatar(
                        photoUrl: photoUrl,
                        name: name,
                        radius: 20,
                      ),
                      title: Text(name),
                      subtitle: Text("${element.nation}, ${element.state ?? ''}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Edit/Delete for own location
                          if (isCurrentUser) ...[
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () async {
                                // Show location picker to edit
                                final result = await showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    child: LocationPicker(
                                      onLocationSelected: (country, state) async {
                                        // Save the updated location
                                        await _firestoreService.setLocation(
                                          widget.currentUserId,
                                          element.groupId,
                                          widget.date,
                                          country,
                                          state,
                                        );
                                        Navigator.pop(context, true); // Return true to indicate success
                                      },
                                    ),
                                  ),
                                );
                                if (result == true && mounted) {
                                  Navigator.pop(context); // Refresh detail modal
                                }
                              },
                              tooltip: 'Edit Location',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                              onPressed: () async {
                                // Delete location - reverts to default
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Delete Location?'),
                                    content: const Text('This will revert to your default location for this date.'),
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
                                  // Delete from Firestore
                                  final dateStr = "${widget.date.year}${widget.date.month.toString().padLeft(2, '0')}${widget.date.day.toString().padLeft(2, '0')}";
                                  final docId = "${element.userId}_${element.groupId}_$dateStr";
                                  await FirebaseFirestore.instance.collection('user_locations').doc(docId).delete();
                                  if (mounted) Navigator.pop(context); // Refresh
                                }
                              },
                              tooltip: 'Delete (Revert to Default)',
                            ),
                          ],
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
                ),
          ),
        ],
      ),
    );
  }

  void _showRSVPDialog(GroupEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("RSVP for ${event.title}"),
        content: const Text("Are you going?"),
        actions: [
          TextButton(
            onPressed: () {
              _firestoreService.rsvpEvent(event.id, widget.currentUserId, 'No');
              Navigator.pop(context);
            },
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () {
              _firestoreService.rsvpEvent(event.id, widget.currentUserId, 'Maybe');
              Navigator.pop(context);
            },
            child: const Text("Maybe"),
          ),
          ElevatedButton(
            onPressed: () {
              _firestoreService.rsvpEvent(event.id, widget.currentUserId, 'Yes');
              Navigator.pop(context);
            },
            child: const Text("Yes"),
          ),
        ],
      ),
    );
  }
}
