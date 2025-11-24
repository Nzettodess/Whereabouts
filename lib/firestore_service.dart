import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';

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
      print("Group created successfully");
    } catch (e) {
      print("Error creating group: $e");
      rethrow;
    }
  }

  Future<void> joinGroup(String groupId, String userId) async {
    await _db.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayUnion([userId]),
    });
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
      // Delete group if no members left
      await docRef.delete();
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

    await docRef.update({
      'members': updatedMembers,
      'admins': updatedAdmins,
      'ownerId': updatedOwnerId,
    });
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

  Future<void> sendNotification(String userId, String message) async {
    await _db.collection('notifications').add({
      'userId': userId,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  Stream<List<AppNotification>> getNotifications(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromFirestore(doc))
            .toList());
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _db.collection('notifications').doc(notificationId).update({'read': true});
  }

  // --- Events ---

  Future<void> createEvent(GroupEvent event) async {
    await _db.collection('events').doc(event.id).set(event.toMap());

    // Notify all members
    final groupDoc = await _db.collection('groups').doc(event.groupId).get();
    if (groupDoc.exists) {
      final group = Group.fromFirestore(groupDoc);
      for (final memberId in group.members) {
        if (memberId != event.creatorId) {
          await sendNotification(memberId, "New Event: ${event.title} in ${group.name}");
        }
      }
    }
  }

  Future<void> updateEvent(GroupEvent event) async {
    await _db.collection('events').doc(event.id).update(event.toMap());
  }

  Future<void> deleteEvent(String eventId) async {
    await _db.collection('events').doc(eventId).delete();
  }

  Future<void> rsvpEvent(String eventId, String userId, String status) async {
    await _db.collection('events').doc(eventId).update({
      'rsvps.$userId': status,
    });
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
}
