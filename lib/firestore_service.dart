import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';
import 'models/placeholder_member.dart';
import 'models/join_request.dart';
import 'services/notification_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // --- Groups ---

  Future<void> createGroup(String name, String userId) async {
    print("Creating group: $name for user: $userId");
    try {
      final docRef = _db.collection('groups').doc();
      print("Generated Group ID: ${docRef.id}");
      final group = Group(
        id: docRef.id,
        name: name,
        ownerId: userId,
        admins: [userId],
        members: [userId],
      );
      print("Group Map: ${group.toMap()}");
      await docRef.set(group.toMap());
      
      // Update creator's joinedGroupIds
      await _db.collection('users').doc(userId).update({
        'joinedGroupIds': FieldValue.arrayUnion([docRef.id]),
      });
      
      print("Group created successfully");
    } catch (e) {
      print("Error creating group: $e");
      rethrow;
    }
  }

  /// Request to join a group (requires approval from owner/admin)
  Future<void> requestToJoinGroup(String groupId, String userId) async {
    final docRef = _db.collection('groups').doc(groupId);
    final doc = await docRef.get();
    
    if (!doc.exists) {
      throw Exception("Group not found. The group ID may be incorrect or the group may have been deleted.");
    }
    
    // Check if user is already a member
    final group = Group.fromFirestore(doc);
    if (group.members.contains(userId)) {
      throw Exception("You are already a member of this group.");
    }
    
    // Check if there's already a pending request
    final existingRequest = await _db
        .collection('join_requests')
        .where('groupId', isEqualTo: groupId)
        .where('requesterId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();
    
    if (existingRequest.docs.isNotEmpty) {
      throw Exception("You already have a pending request for this group.");
    }
    
    // Create join request
    final requestId = 'join_${_uuid.v4()}';
    
    // Get requester name for notification AND storage
    final userDoc = await _db.collection('users').doc(userId).get();
    final userName = userDoc.data()?['displayName'] ?? userDoc.data()?['email'] ?? 'Someone';
    
    await _db.collection('join_requests').doc(requestId).set({
      'groupId': groupId,
      'requesterId': userId,
      'requesterName': userName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Notify group owner
    await NotificationService().notifyJoinRequest(
      ownerId: group.ownerId,
      groupId: groupId,
      requesterId: userId,
      requesterName: userName,
      groupName: group.name,
    );
  }

  Future<void> leaveGroup(String groupId, String userId) async {
    final docRef = _db.collection('groups').doc(groupId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final group = Group.fromFirestore(doc);

    // Remove from members and admins
    List<String> updatedMembers = List.from(group.members)..remove(userId);
    List<String> updatedAdmins = List.from(group.admins)..remove(userId);

    if (updatedMembers.isEmpty) {
      // No members left - delete group and all related data
      print('Deleting group $groupId and all related data...');
      
      // Delete all events for this group
      final eventsSnapshot = await _db.collection('events')
          .where('groupId', isEqualTo: groupId)
          .get();
      
      for (var eventDoc in eventsSnapshot.docs) {
        await eventDoc.reference.delete();
        print('Deleted event: ${eventDoc.id}');
      }
      
      // Delete all locations for this group (if locations have groupId field)
      final locationsSnapshot = await _db.collection('user_locations')
          .where('groupId', isEqualTo: groupId)
          .get();
      
      for (var locationDoc in locationsSnapshot.docs) {
        await locationDoc.reference.delete();
        print('Deleted location: ${locationDoc.id}');
      }
      
      // Finally, delete the group itself
      await docRef.delete();
      print('Group $groupId deleted successfully');
      return;
    }

    String updatedOwnerId = group.ownerId;
    if (group.ownerId == userId) {
      // Transfer ownership
      if (updatedAdmins.isNotEmpty) {
        updatedOwnerId = updatedAdmins.first;
      } else {
        updatedOwnerId = updatedMembers.first;
        updatedAdmins.add(updatedOwnerId); // New owner becomes admin too
      }
    }

    // Clean up user's data from this group (RSVPs, locations)
    await cleanupUserFromGroup(userId, groupId);

    await docRef.update({
      'members': updatedMembers,
      'admins': updatedAdmins,
      'ownerId': updatedOwnerId,
    });
    
    // Update user's joinedGroupIds
    await _db.collection('users').doc(userId).update({
        'joinedGroupIds': FieldValue.arrayRemove([groupId]),
    });
  }

  /// Clean up all user data from a group when they leave/are removed
  Future<void> cleanupUserFromGroup(String userId, String groupId) async {
    // Get group details for ownership transfer
    final groupDoc = await _db.collection('groups').doc(groupId).get();
    final groupOwnerId = groupDoc.data()?['ownerId'] as String?;
    
    // 1. Handle events: remove RSVP and transfer ownership if needed
    final eventsSnapshot = await _db.collection('events')
        .where('groupId', isEqualTo: groupId)
        .get();
    
    for (final eventDoc in eventsSnapshot.docs) {
      final data = eventDoc.data();
      final creatorId = data['creatorId'] as String?;
      final rsvps = data['rsvps'] as Map<String, dynamic>?;
      
      final updates = <String, dynamic>{};
      
      // Remove user's RSVP
      if (rsvps != null && rsvps.containsKey(userId)) {
        updates['rsvps.$userId'] = FieldValue.delete();
      }
      
      // Transfer event ownership to group owner if user was event creator
      if (creatorId == userId && groupOwnerId != null) {
        updates['creatorId'] = groupOwnerId;
      }
      
      if (updates.isNotEmpty) {
        await eventDoc.reference.update(updates);
      }
    }
    
    // 2. Delete user's location records for this group
    final locationsSnapshot = await _db.collection('user_locations')
        .where('userId', isEqualTo: userId)
        .where('groupId', isEqualTo: groupId)
        .get();
    
    for (final locationDoc in locationsSnapshot.docs) {
      await locationDoc.reference.delete();
    }
  }

  Stream<List<Group>> getUserGroups(String userId) {
    return _db
        .collection('groups')
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Group.fromFirestore(doc)).toList());
  }

  // Helper method to get user groups as list (synchronous)
  Future<List<Group>> getUserGroupsSnapshot(String userId) async {
    final snapshot = await _db
        .collection('groups')
        .where('members', arrayContains: userId)
        .get();
    
    return snapshot.docs.map((doc) => Group.fromFirestore(doc)).toList();
  }

  /// Sync user's joinedGroupIds with actual group memberships
  /// This repairs any desync and handles new joins
  Future<void> syncUserGroups(String userId) async {
    try {
      final groups = await getUserGroupsSnapshot(userId);
      final groupIds = groups.map((g) => g.id).toList();
      
      await _db.collection('users').doc(userId).set({
        'joinedGroupIds': groupIds,
      }, SetOptions(merge: true));
      print('[FirestoreService] Synced ${groupIds.length} groups for user $userId');
    } catch (e) {
      print('[FirestoreService] Error syncing groups: $e');
    }
  }

  // --- Locations ---

  // Set Location - now updates for all groups user is in
  Future<void> setLocation(String userId, String groupId, DateTime date, String nation, String? state) async {
    // Get all groups the user is in
    final groups = await getUserGroupsSnapshot(userId);
    
    // Create location entry for each group
    final batch = _db.batch();
    
    for (final group in groups) {
      final dateStr = "${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}";
      final docId = "${userId}_${group.id}_$dateStr";
      
      final locationRef = _db.collection('user_locations').doc(docId);
      batch.set(locationRef, {
        'userId': userId,
        'groupId': group.id,
        'date': Timestamp.fromDate(date),
        'nation': nation,
        'state': state,
      }, SetOptions(merge: true));
    }
    
    await batch.commit();

    // Notify groups (Async)
    _notifyLocationChange(userId, groups, date, nation, state);
  }

  /// Helper to notify groups of location change
  Future<void> _notifyLocationChange(String userId, List<Group> groups, DateTime date, String nation, String? state) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      final userName = userDoc.data()?['displayName'] ?? userDoc.data()?['email'] ?? 'Someone';
      
      // Construct full location string
      final locationStr = (state != null && state.isNotEmpty) ? '$state, $nation' : nation;
      
      // 1. Collect all unique recipients across all groups
      final allMemberIds = <String>{};
      for (final group in groups) {
          allMemberIds.addAll(group.members);
      }
      // Remove self
      allMemberIds.remove(userId);
      
      if (allMemberIds.isEmpty) return;

      // 2. Send ONE notification broadcast to all unique recipients
      // We attribute it to the first group for context, but the push is deduped.
      await NotificationService().notifyLocationChanged(
        memberIds: allMemberIds.toList(),
        userId: userId,
        userName: userName,
        location: locationStr,
        date: date,
        groupId: groups.isNotEmpty ? groups.first.id : '',
      );
    } catch (e) {
      print('Error notifying location change: $e');
    }
  }

  // Set Location Range - updates location for multiple days
  Future<void> setLocationRange(
    String userId,
    String groupId,
    DateTime startDate,
    DateTime endDate,
    String nation,
    String? state,
  ) async {
    // Get all groups the user is in
    final groups = await getUserGroupsSnapshot(userId);
    
    // Calculate all dates in range
    final dates = <DateTime>[];
    var currentDate = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    
    while (!currentDate.isAfter(end)) {
      dates.add(currentDate);
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    // Firestore batch limit is 500 operations
    // Each date * each group = one operation
    const maxOpsPerBatch = 500;
    final allOperations = <Map<String, dynamic>>[];
    
    for (final date in dates) {
      for (final group in groups) {
        final dateStr = "${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}";
        final docId = "${userId}_${group.id}_$dateStr";
        
        allOperations.add({
          'docId': docId,
          'userId': userId,
          'groupId': group.id,
          'date': Timestamp.fromDate(date),
          'nation': nation,
          'state': state,
        });
      }
    }
    
    // Execute in batches
    for (var i = 0; i < allOperations.length; i += maxOpsPerBatch) {
      final batch = _db.batch();
      final end = (i + maxOpsPerBatch < allOperations.length) 
          ? i + maxOpsPerBatch 
          : allOperations.length;
      
      for (var j = i; j < end; j++) {
        final op = allOperations[j];
        final locationRef = _db.collection('user_locations').doc(op['docId']);
        batch.set(locationRef, {
          'userId': op['userId'],
          'groupId': op['groupId'],
          'date': op['date'],
          'nation': op['nation'],
          'state': op['state'],
        }, SetOptions(merge: true));
      }
      
      await batch.commit();
    }

    // Notify groups of range change
    _notifyLocationRangeChange(userId, groups, startDate, endDate, nation, state);
  }

  /// Helper to notify groups of location range change
  Future<void> _notifyLocationRangeChange(String userId, List<Group> groups, DateTime start, DateTime end, String nation, String? state) async {
     try {
      final userDoc = await _db.collection('users').doc(userId).get();
      final userName = userDoc.data()?['displayName'] ?? userDoc.data()?['email'] ?? 'Someone';
      
      // Construct full location string
      final locationStr = (state != null && state.isNotEmpty) ? '$state, $nation' : nation;
      
      // 1. Collect all unique recipients
      final allMemberIds = <String>{};
      for (final group in groups) {
          allMemberIds.addAll(group.members);
      }
      allMemberIds.remove(userId);
      
      if (allMemberIds.isEmpty) return;

      // 2. Send ONE notification broadcast
      await NotificationService().notifyLocationRangeChanged(
        memberIds: allMemberIds.toList(),
        userId: userId,
        userName: userName,
        location: locationStr,
        startDate: start,
        endDate: end,
        groupId: groups.isNotEmpty ? groups.first.id : '',
      );
    } catch (e) {
      print('Error notifying location range change: $e');
    }
  }


  Stream<List<UserLocation>> getGroupLocations(
      List<String> memberIds, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _db
        .collection('user_locations')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
      final locations = snapshot.docs
          .map((doc) => UserLocation.fromFirestore(doc.data()))
          .toList();
      return locations.where((loc) => memberIds.contains(loc.userId)).toList();
    });
  }

  // --- Notifications ---

  /// Send a notification to a user
  /// @param type - The notification type for proper categorization and icons
  /// @param dedupeKey - Optional key for deduplication (updates instead of creates if exists)
  /// @param groupId - Optional group context
  /// @param relatedId - Optional related entity ID for navigation
  Future<void> sendNotification(
    String userId, 
    String message, {
    NotificationType type = NotificationType.general,
    String? dedupeKey,
    String? groupId,
    String? relatedId,
  }) async {
    final notificationData = {
      'userId': userId,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'type': type.name,
      if (dedupeKey != null) 'dedupeKey': dedupeKey,
      if (groupId != null) 'groupId': groupId,
      if (relatedId != null) 'relatedId': relatedId,
    };

    // Handle deduplication if dedupeKey is provided
    // Note: This only works when sending to yourself (e.g., birthday reminders)
    // For notifications to others, we skip deduplication due to permission constraints
    if (dedupeKey != null) {
      try {
        final existing = await _db
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .where('dedupeKey', isEqualTo: dedupeKey)
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          // Update existing notification instead of creating new
          await existing.docs.first.reference.update({
            'message': message,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });
          return;
        }
      } catch (e) {
        // Permission denied when querying other user's notifications - this is expected
        // Just create a new notification instead
        print('Deduplication query failed (expected for other users): $e');
      }
    }

    await _db.collection('notifications').add(notificationData);
  }

  Stream<List<AppNotification>> getNotifications(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          final notifications = <AppNotification>[];
          for (final doc in snapshot.docs) {
            try {
              notifications.add(AppNotification.fromFirestore(doc));
            } catch (e) {
              print('Error parsing notification ${doc.id}: $e');
              // Skip malformed notifications instead of crashing
            }
          }
          return notifications;
        })
        .handleError((error) {
          print('Error fetching notifications: $error');
          return <AppNotification>[];
        });
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _db.collection('notifications').doc(notificationId).update({'read': true});
  }

  Future<void> markNotificationUnread(String notificationId) async {
    await _db.collection('notifications').doc(notificationId).update({'read': false});
  }

  Future<void> deleteNotification(String notificationId) async {
    await _db.collection('notifications').doc(notificationId).delete();
  }

  Future<void> deleteAllNotifications(String userId) async {
    final snapshot = await _db.collection('notifications').where('userId', isEqualTo: userId).get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> markAllAsUnread(String userId) async {
    final snapshot = await _db.collection('notifications').where('userId', isEqualTo: userId).get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'read': false});
    }
    await batch.commit();
  }

  // --- Events ---

  Future<void> createEvent(GroupEvent event) async {
    await _db.collection('events').doc(event.id).set(event.toMap());

    // Notify all members
    final groupDoc = await _db.collection('groups').doc(event.groupId).get();
    if (groupDoc.exists) {
      final group = Group.fromFirestore(groupDoc);
      await NotificationService().notifyEventCreated(
        memberIds: group.members,
        creatorId: event.creatorId,
        eventId: event.id,
        eventTitle: event.title,
        groupId: event.groupId,
        groupName: group.name,
      );
    }
  }

  /// Update event with rolling version history (keeps 2 previous versions)
  Future<void> updateEvent(GroupEvent event, String editedByUserId) async {
    debugPrint('[FirestoreService] Updating event: ${event.title}');
    
    // Get current event data before updating for history
    final currentDoc = await _db.collection('events').doc(event.id).get();
    List<Map<String, dynamic>> history = [];
    
    if (currentDoc.exists) {
      final currentData = currentDoc.data()!;
      if (currentData['editHistory'] != null) {
        history = List<Map<String, dynamic>>.from(currentData['editHistory']);
      }
      
      // Create history entry from current version (before edit)
      final historyEntry = Map<String, dynamic>.from(currentData);
      historyEntry.remove('editHistory'); // Don't nest history
      history.insert(0, historyEntry);
      if (history.length > 2) history = history.sublist(0, 2);
    }

    final updateData = event.toMap();
    updateData['lastEditedBy'] = editedByUserId;
    updateData['lastEditedAt'] = FieldValue.serverTimestamp();
    updateData['editHistory'] = history;

    await _db.collection('events').doc(event.id).update(updateData);

    // NOTE: Notification is handled by add_event_modal.dart with changeSummary
    // Do NOT send notification here to avoid duplicates
  }

  Future<void> deleteEvent(String eventId, String deleterId) async {
    debugPrint('[FirestoreService] Deleting event: $eventId');
    final eventDoc = await _db.collection('events').doc(eventId).get();
    if (eventDoc.exists) {
        final eventData = eventDoc.data()!;
        final title = eventData['title'] ?? 'Event';
        final groupId = eventData['groupId'] ?? '';
        
        await _db.collection('events').doc(eventId).delete();

        // Notify
        final groupDoc = await _db.collection('groups').doc(groupId).get();
        if (groupDoc.exists) {
            final group = Group.fromFirestore(groupDoc);
            debugPrint('[FirestoreService] Notifying ${group.members.length} members for event deletion: $title');
            await NotificationService().notifyEventDeleted(
                memberIds: group.members,
                deleterId: deleterId,
                eventTitle: title,
                groupId: groupId,
            );
        }
    }
  }

  Future<void> rsvpEvent(String eventId, String userId, String status) async {
    debugPrint('[FirestoreService] User $userId RSVPing to event $eventId with status: $status');
    // Update RSVP
    await _db.collection('events').doc(eventId).update({
      'rsvps.$userId': status,
    });
    
    // Notify creator
    try {
      final eventDoc = await _db.collection('events').doc(eventId).get();
      if (!eventDoc.exists) return;
      
      final event = GroupEvent.fromFirestore(eventDoc);
      // Don't notify if creator is RSVPing to their own event
      if (event.creatorId == userId) {
        debugPrint('[FirestoreService] Skipping RSVP notification for event creator $userId');
        return;
      }
      
      final userDoc = await _db.collection('users').doc(userId).get();
      final userName = userDoc.data()?['displayName'] ?? userDoc.data()?['email'] ?? 'Someone';
      
      debugPrint('[FirestoreService] Notifying event creator ${event.creatorId} of RSVP from $userName for event ${event.title}');
      await NotificationService().notifyRSVP(
        creatorId: event.creatorId,
        responderName: userName,
        eventTitle: event.title,
        status: status,
        eventId: eventId,
      );
    } catch (e) {
      print('Error sending RSVP notification: $e');
    }
  }

  Stream<List<GroupEvent>> getGroupEvents(String groupId, DateTime date) {
     final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _db
        .collection('events')
        .where('groupId', isEqualTo: groupId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => GroupEvent.fromFirestore(doc)).toList());
  }

  /// Get all events user has access to (from groups they're a member of)
  Stream<List<GroupEvent>> getAllUserEvents(String userId) async* {
    // First get all groups the user is a member of
    final groupsSnapshot = await _db
        .collection('groups')
        .where('members', arrayContains: userId)
        .get();
    
    final groupIds = groupsSnapshot.docs.map((doc) => doc.id).toList();
    
    if (groupIds.isEmpty) {
      yield [];
      return;
    }
    
    // Listen to events from all user's groups
    // Note: Firestore 'in' queries are limited to 10 items
    // If user is in more than 10 groups, we need to batch the queries
    const batchSize = 10;
    final allEvents = <GroupEvent>[];
    
    for (var i = 0; i < groupIds.length; i += batchSize) {
      final batch = groupIds.skip(i).take(batchSize).toList();
      
      await for (final snapshot in _db
          .collection('events')
          .where('groupId', whereIn: batch)
          .snapshots()) {
        final events = snapshot.docs
            .map((doc) => GroupEvent.fromFirestore(doc))
            .toList();
        
        // Merge with existing events (avoid duplicates)
        for (final event in events) {
          if (!allEvents.any((e) => e.id == event.id)) {
            allEvents.add(event);
          }
        }
        
        // Sort by date (most recent first)
        allEvents.sort((a, b) => b.date.compareTo(a.date));
        yield List.from(allEvents);
      }
    }
  }

  /// Get event attendees with their details
  Future<Map<String, Map<String, dynamic>>> getEventAttendees(
      String eventId, String groupId) async {
    // Get group members
    final groupDoc = await _db.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) return {};
    
    final group = Group.fromFirestore(groupDoc);
    final attendees = <String, Map<String, dynamic>>{};
    
    // Fetch user details for all members
    for (final memberId in group.members) {
      final userDoc = await _db.collection('users').doc(memberId).get();
      if (userDoc.exists) {
        attendees[memberId] = userDoc.data() as Map<String, dynamic>;
      }
    }
    
    // Also fetch placeholder members for this group
    final placeholdersSnapshot = await _db
        .collection('placeholder_members')
        .where('groupId', isEqualTo: groupId)
        .get();
    for (final doc in placeholdersSnapshot.docs) {
      final data = doc.data();
      attendees[doc.id] = {
        'displayName': data['displayName'] ?? 'Placeholder',
        'isPlaceholder': true,
      };
    }
    
    return attendees;
  }

  /// Send RSVP reminder to users who haven't responded
  Future<void> sendRSVPReminder(
      String eventId, String eventTitle, List<String> userIds) async {
    for (final userId in userIds) {
      await sendNotification(
        userId,
        "Reminder: Please RSVP for '$eventTitle'",
        type: NotificationType.eventUpdated,
        relatedId: eventId,
      );
    }
  }

  /// Calculate RSVP statistics for an event
  Future<Map<String, dynamic>> getEventRSVPStats(
      GroupEvent event, String groupId) async {
    // Get all group members
    final groupDoc = await _db.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) {
      return {
        'totalMembers': 0,
        'accepted': 0,
        'declined': 0,
        'maybe': 0,
        'noResponse': 0,
        'responseRate': 0.0,
      };
    }
    
    final group = Group.fromFirestore(groupDoc);
    
    // Also count placeholder members
    final placeholdersSnapshot = await _db
        .collection('placeholder_members')
        .where('groupId', isEqualTo: groupId)
        .get();
    final placeholderIds = placeholdersSnapshot.docs.map((doc) => doc.id).toList();
    
    // Total = regular members + placeholders
    final List<String> allMemberIds = [...group.members, ...placeholderIds];
    final totalMembers = allMemberIds.length;
    final noResponseUsers = event.getUsersWithNoResponse(allMemberIds);
    
    return {
      'totalMembers': totalMembers,
      'accepted': event.acceptedCount,
      'declined': event.declinedCount,
      'maybe': event.maybeCount,
      'noResponse': noResponseUsers.length,
      'responseRate': event.getResponseRate(totalMembers),
      'noResponseUserIds': noResponseUsers,
    };
  }

  // --- Birthdays ---

  Future<void> updateUserBirthday(String userId, DateTime? birthday) async {
    if (birthday != null) {
      await _db.collection('users').doc(userId).update({
        'birthday': Timestamp.fromDate(birthday),
      });
    } else {
      // Clear birthday
      await _db.collection('users').doc(userId).update({
        'birthday': FieldValue.delete(),
      });
    }
  }

  // --- Placeholder Members ---

  /// Create a new placeholder member
  Future<String> createPlaceholderMember(PlaceholderMember member) async {
    final docRef = _db.collection('placeholder_members').doc(member.id);
    await docRef.set(member.toMap());
    return member.id;
  }

  /// Update placeholder member details
  Future<void> updatePlaceholderMember(PlaceholderMember member) async {
    await _db.collection('placeholder_members').doc(member.id).update(member.toMap());
  }

  /// Delete placeholder member and all related data
  Future<void> deletePlaceholderMember(String memberId) async {
    // First, get the placeholder member to know its groupId (needed for security rules)
    final placeholderDoc = await _db.collection('placeholder_members').doc(memberId).get();
    if (!placeholderDoc.exists) {
      throw Exception('Placeholder member not found');
    }
    final groupId = placeholderDoc.data()!['groupId'] as String;
    
    // Delete all locations for this placeholder (groupId filter helps security rules)
    final locationsSnapshot = await _db
        .collection('placeholder_member_locations')
        .where('placeholderMemberId', isEqualTo: memberId)
        .where('groupId', isEqualTo: groupId)
        .get();
    
    final batch = _db.batch();
    for (var doc in locationsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    
    // Cancel any pending inheritance requests (groupId filter required for security rules)
    final requestsSnapshot = await _db
        .collection('inheritance_requests')
        .where('placeholderMemberId', isEqualTo: memberId)
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'pending')
        .get();
    
    for (var doc in requestsSnapshot.docs) {
      batch.update(doc.reference, {'status': 'cancelled'});
    }
    
    // Delete the placeholder member
    batch.delete(_db.collection('placeholder_members').doc(memberId));
    
    await batch.commit();
  }

  /// Get all placeholder members for a group
  Stream<List<PlaceholderMember>> getGroupPlaceholderMembers(String groupId) {
    return _db
        .collection('placeholder_members')
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PlaceholderMember.fromFirestore(doc))
            .toList());
  }

  /// Get a single placeholder member by ID
  Future<PlaceholderMember?> getPlaceholderMember(String memberId) async {
    final doc = await _db.collection('placeholder_members').doc(memberId).get();
    if (!doc.exists) return null;
    return PlaceholderMember.fromFirestore(doc);
  }

  // --- Placeholder Member Locations ---

  /// Set location for a placeholder member on a specific date
  Future<void> setPlaceholderMemberLocation(
    String placeholderMemberId,
    String groupId,
    DateTime date,
    String nation,
    String? state,
  ) async {
    final dateStr = "${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}";
    final docId = "${placeholderMemberId}_$dateStr";
    
    await _db.collection('placeholder_member_locations').doc(docId).set({
      'placeholderMemberId': placeholderMemberId,
      'groupId': groupId,
      'date': Timestamp.fromDate(date),
      'nation': nation,
      'state': state,
    }, SetOptions(merge: true));
  }

  /// Set location for a placeholder member over a date range
  Future<void> setPlaceholderMemberLocationRange(
    String placeholderMemberId,
    String groupId,
    DateTime startDate,
    DateTime endDate,
    String nation,
    String? state,
  ) async {
    final dates = <DateTime>[];
    var currentDate = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    
    while (!currentDate.isAfter(end)) {
      dates.add(currentDate);
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    const maxOpsPerBatch = 500;
    for (var i = 0; i < dates.length; i += maxOpsPerBatch) {
      final batch = _db.batch();
      final batchEnd = (i + maxOpsPerBatch < dates.length) ? i + maxOpsPerBatch : dates.length;
      
      for (var j = i; j < batchEnd; j++) {
        final date = dates[j];
        final dateStr = "${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}";
        final docId = "${placeholderMemberId}_$dateStr";
        
        batch.set(_db.collection('placeholder_member_locations').doc(docId), {
          'placeholderMemberId': placeholderMemberId,
          'groupId': groupId,
          'date': Timestamp.fromDate(date),
          'nation': nation,
          'state': state,
        }, SetOptions(merge: true));
      }
      
      await batch.commit();
    }
  }

  /// Get placeholder member locations for a specific date
  Stream<List<PlaceholderLocation>> getPlaceholderMemberLocations(
    String groupId,
    DateTime date,
  ) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _db
        .collection('placeholder_member_locations')
        .where('groupId', isEqualTo: groupId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PlaceholderLocation.fromFirestore(doc.data()))
            .toList());
  }

  // --- Inheritance Requests ---

  /// Request to inherit a placeholder member's data
  Future<void> requestInheritance(
    String placeholderMemberId,
    String requesterId,
    String groupId,
  ) async {
    // Check if there's already a pending request from this user
    final existingRequest = await _db
        .collection('inheritance_requests')
        .where('placeholderMemberId', isEqualTo: placeholderMemberId)
        .where('requesterId', isEqualTo: requesterId)
        .where('status', isEqualTo: 'pending')
        .get();
    
    if (existingRequest.docs.isNotEmpty) {
      throw Exception('You already have a pending request for this placeholder.');
    }
    
    final requestId = 'request_${_uuid.v4()}';
    await _db.collection('inheritance_requests').doc(requestId).set({
      'placeholderMemberId': placeholderMemberId,
      'requesterId': requesterId,
      'groupId': groupId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Notify group admins
    try {
      // Get placeholder name
      final phDoc = await _db.collection('placeholder_members').doc(placeholderMemberId).get();
      final phName = phDoc.data()?['displayName'] ?? 'Unknown Member';
      
      // Get requester name
      final userDoc = await _db.collection('users').doc(requesterId).get();
      final userName = userDoc.data()?['displayName'] ?? userDoc.data()?['email'] ?? 'Someone';
      
      // Get group admins
      final groupDoc = await _db.collection('groups').doc(groupId).get();
      final group = Group.fromFirestore(groupDoc);
      
      await NotificationService().notifyInheritanceRequest(
        adminIds: [...group.admins, group.ownerId], // Include owner explicitly
        requesterId: requesterId,
        requesterName: userName,
        placeholderName: phName,
        groupId: groupId,
      );
    } catch (e) {
      print('Error sending inheritance request notification: $e');
    }
  }

  /// Get pending inheritance requests for a group (owner/admin view)
  Stream<List<InheritanceRequest>> getPendingInheritanceRequests(String groupId) {
    return _db
        .collection('inheritance_requests')
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InheritanceRequest.fromFirestore(doc))
            .toList());
  }

  /// Get pending inheritance requests for a specific user (member view)
  Stream<List<InheritanceRequest>> getMyPendingInheritanceRequests(String groupId, String userId) {
    return _db
        .collection('inheritance_requests')
        .where('groupId', isEqualTo: groupId)
        .where('requesterId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InheritanceRequest.fromFirestore(doc))
            .toList());
  }

  /// Process an inheritance request (approve or reject)
  Future<void> processInheritanceRequest(
    String requestId,
    bool approved,
    String processedBy,
  ) async {
    final requestDoc = await _db.collection('inheritance_requests').doc(requestId).get();
    if (!requestDoc.exists) {
      throw Exception('Request not found');
    }
    
    final request = InheritanceRequest.fromFirestore(requestDoc);
    
    if (approved) {
      // Perform the inheritance
      await performInheritance(
        request.placeholderMemberId,
        request.requesterId,
        request.groupId,
      );
      // Notification is handled in performInheritance for approval
    } else {
        // Handle rejection notification here
        // Get placeholder name for msg
        String phName = 'Member';
        try {
            final phDoc = await _db.collection('placeholder_members').doc(request.placeholderMemberId).get();
            phName = phDoc.data()?['displayName'] ?? 'Member';
        } catch (_) {}

        await NotificationService().notifyInheritanceProcessed(
            requesterId: request.requesterId,
            placeholderName: phName, // Best effort
            approved: false,
            groupId: request.groupId,
        );
    }
    
    // Update request status
    await _db.collection('inheritance_requests').doc(requestId).update({
      'status': approved ? 'approved' : 'rejected',
      'processedBy': processedBy,
      'processedAt': FieldValue.serverTimestamp(),
    });
    
    // Cancel all other pending requests for the same placeholder if approved
    if (approved) {
      final otherRequests = await _db
          .collection('inheritance_requests')
          .where('placeholderMemberId', isEqualTo: request.placeholderMemberId)
          .where('groupId', isEqualTo: request.groupId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      final batch = _db.batch();
      for (var doc in otherRequests.docs) {
        batch.update(doc.reference, {'status': 'cancelled'});
      }
      await batch.commit();
    }
  }

  /// Perform the actual inheritance - transfer all data from placeholder to real user
  Future<void> performInheritance(
    String placeholderMemberId,
    String userId,
    String groupId,
  ) async {
    // Get the placeholder member data
    final placeholderDoc = await _db.collection('placeholder_members').doc(placeholderMemberId).get();
    if (!placeholderDoc.exists) {
      throw Exception('Placeholder member not found');
    }
    
    final placeholder = PlaceholderMember.fromFirestore(placeholderDoc);
    
    // Transfer data to user profile
    final userUpdate = <String, dynamic>{};
    
    if (placeholder.defaultLocation != null) {
      userUpdate['defaultLocation'] = placeholder.defaultLocation;
    }
    if (placeholder.birthday != null) {
      userUpdate['birthday'] = Timestamp.fromDate(placeholder.birthday!);
    }
    if (placeholder.hasLunarBirthday) {
      userUpdate['hasLunarBirthday'] = true;
      userUpdate['lunarBirthdayMonth'] = placeholder.lunarBirthdayMonth;
      userUpdate['lunarBirthdayDay'] = placeholder.lunarBirthdayDay;
    }
    
    if (userUpdate.isNotEmpty) {
      await _db.collection('users').doc(userId).update(userUpdate);
    }
    
    // Transfer all location entries
    final locationsSnapshot = await _db
        .collection('placeholder_member_locations')
        .where('placeholderMemberId', isEqualTo: placeholderMemberId)
        .where('groupId', isEqualTo: groupId)
        .get();
    
    final batch = _db.batch();
    
    for (var doc in locationsSnapshot.docs) {
      final data = doc.data();
      final date = (data['date'] as Timestamp).toDate();
      final dateStr = "${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}";
      final newDocId = "${userId}_${groupId}_$dateStr";
      
      // Create new location entry for the real user
      batch.set(_db.collection('user_locations').doc(newDocId), {
        'userId': userId,
        'groupId': groupId,
        'date': data['date'],
        'nation': data['nation'],
        'state': data['state'],
      }, SetOptions(merge: true));
      
      // Delete the old placeholder location
      batch.delete(doc.reference);
    }
    
    // Delete the placeholder member
    batch.delete(_db.collection('placeholder_members').doc(placeholderMemberId));
    
    await batch.commit();
    
    // Send notification to the user
    // Send notification to the user
    await NotificationService().notifyInheritanceProcessed(
        requesterId: userId,
        placeholderName: placeholder.displayName,
        approved: true,
        groupId: groupId,
    );
  }

  /// Cancel pending requests when user leaves group
  Future<void> cancelUserInheritanceRequests(String userId, String groupId) async {
    final requests = await _db
        .collection('inheritance_requests')
        .where('requesterId', isEqualTo: userId)
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'pending')
        .get();
    
    final batch = _db.batch();
    for (var doc in requests.docs) {
      batch.update(doc.reference, {'status': 'cancelled'});
    }
    await batch.commit();
  }

  // --- Join Requests ---

  /// Get pending join requests for a group (for owner/admin view)
  Stream<List<JoinRequest>> getPendingJoinRequests(String groupId) {
    return _db
        .collection('join_requests')
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => JoinRequest.fromFirestore(doc))
            .toList());
  }

  /// Get user's pending join requests (to show pending status)
  Stream<List<JoinRequest>> getMyPendingJoinRequests(String userId) {
    return _db
        .collection('join_requests')
        .where('requesterId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => JoinRequest.fromFirestore(doc))
            .toList());
  }

  /// Process a join request (approve or reject)
  Future<void> processJoinRequest(
    String requestId,
    bool approved,
    String processedBy,
  ) async {
    final requestDoc = await _db.collection('join_requests').doc(requestId).get();
    if (!requestDoc.exists) {
      throw Exception('Join request not found');
    }
    
    final request = JoinRequest.fromFirestore(requestDoc);
    
    if (approved) {
      // Add user to group members
      await _db.collection('groups').doc(request.groupId).update({
        'members': FieldValue.arrayUnion([request.requesterId]),
      });
      
      // Force sync the new member's joinedGroupIds immediately
      // This allows them to read other group members' profiles right away
      await _db.collection('users').doc(request.requesterId).update({
        'joinedGroupIds': FieldValue.arrayUnion([request.groupId]),
      });
      
      // Get group name for notification
      final groupDoc = await _db.collection('groups').doc(request.groupId).get();
      final groupName = groupDoc.data()?['name'] ?? 'the group';
      
      // Notify the requester
      await NotificationService().notifyJoinProcessed(
        requesterId: request.requesterId,
        groupName: groupName,
        approved: approved,
      );
    } else {
      // Notify rejection
      final groupDoc = await _db.collection('groups').doc(request.groupId).get();
      final groupName = groupDoc.data()?['name'] ?? 'the group';
      
      await NotificationService().notifyJoinProcessed(
        requesterId: request.requesterId,
        groupName: groupName,
        approved: approved,
      );
    }
    
    // Update request status
    await _db.collection('join_requests').doc(requestId).update({
      'status': approved ? 'approved' : 'rejected',
      'processedBy': processedBy,
      'processedAt': FieldValue.serverTimestamp(),
    });
  }


  /// Cancel user's pending join requests (when they want to withdraw)
  Future<void> cancelJoinRequest(String requestId) async {
    await _db.collection('join_requests').doc(requestId).delete();
  }
}

