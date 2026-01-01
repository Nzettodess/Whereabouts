import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models.dart';

/// Service for managing push notifications (FCM) and in-app notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  String? get oneSignalPlayerId => _oneSignalPlayerId;

  static const String _pushEnabledKey = 'push_notifications_enabled';
  static const String _lastBirthdayCheckKey = 'last_birthday_check_date';
  static const String _lastMonthlyBirthdayKey = 'last_monthly_birthday_check';
  
  // Cache for user names (optional, but helps performance during bulk checks)
  final Map<String, String> _userNameCache = {};
  
  // OneSignal Push API - Vercel serverless function path
  static const String _pushApiUrl = '/api/send-notification';

  bool _initialized = false;
  String? _currentUserId;
  String? _oneSignalPlayerId;
  
  bool get isNotificationSupported {
    if (!kIsWeb) return true;
    try {
      return (web.window as JSObject).hasProperty('Notification'.toJS).toDart;
    } catch (_) {
      return false;
    }
  }

  bool get isOneSignalJSLoaded {
    if (!kIsWeb) return false;
    try {
      return (web.window as JSObject).hasProperty('getOneSignalPlayerId'.toJS).toDart;
    } catch (_) {
      return false;
    }
  }

  String get oneSignalAppId {
    if (!kIsWeb) return 'N/A';
    try {
      final jsWindow = web.window as JSObject;
      if (jsWindow.hasProperty('getOneSignalAppId'.toJS).toDart) {
        final result = jsWindow.callMethod('getOneSignalAppId'.toJS);
        return result?.toString() ?? 'Unknown';
      }
    } catch (_) {}
    return 'Not Found';
  }

  String get oneSignalExternalId {
    if (!kIsWeb) return 'N/A';
    try {
      final jsWindow = web.window as JSObject;
      if (jsWindow.hasProperty('getOneSignalExternalId'.toJS).toDart) {
        final result = jsWindow.callMethod('getOneSignalExternalId'.toJS);
        return result?.toString() ?? 'None';
      }
    } catch (_) {}
    return 'Error';
  }

  Future<bool> checkOneSignalSubscription() async {
    if (!kIsWeb) return false;
    try {
      final jsWindow = web.window as JSObject;
      if (jsWindow.hasProperty('isOneSignalSubscribed'.toJS).toDart) {
        final result = jsWindow.callMethod('isOneSignalSubscribed'.toJS);
        if (result != null) {
          final jsPromise = result as JSPromise;
          final value = await jsPromise.toDart.timeout(const Duration(seconds: 2));
          if (value != null && value.isA<JSBoolean>()) {
            return (value as JSBoolean).toDart;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  Future<String> getNotificationPermission() async {
    if (!kIsWeb) return 'default';
    try {
      final jsWindow = web.window as JSObject;
      if (jsWindow.hasProperty('getNotificationPermission'.toJS).toDart) {
        final result = jsWindow.callMethod('getNotificationPermission'.toJS);
        return result?.toString() ?? 'default';
      }
    } catch (_) {}
    return 'default';
  }

  Future<void> initialize(String userId) async {
    debugPrint('--- NOTIFICATION SERVICE INIT START (User: $userId) ---');
    if (_initialized && _currentUserId == userId && _oneSignalPlayerId != null) {
      debugPrint('Already initialized and healthy. Skipping.');
      return;
    }
    
    _currentUserId = userId;
    
    // Clear "None" from cache if present
    if (_oneSignalPlayerId == 'None') _oneSignalPlayerId = null;

    // Get OneSignal player ID and save to Firestore (web only)
    if (kIsWeb) {
      debugPrint('Linking OneSignal Identity to Firebase UID: $userId');
      // Login to OneSignal to associate device with Firebase UID
      await _callJsLoginOneSignal(userId);

      debugPrint('Fetching OneSignal Player ID (OneSignal internal ID)...');
      await _getAndSaveOneSignalPlayerId();
      
      // Sync push status to OneSignal
      final enabled = await isPushEnabled();
      debugPrint('Push enabled preference: $enabled');
      await setPushEnabled(enabled);
    }
    
    _initialized = true;
    debugPrint('--- NOTIFICATION SERVICE INIT COMPLETE ---');
  }

  // FCM token persistence has been removed - using OneSignal as primary provider

  /// Reset service when user logs out
  Future<void> removeToken() async {
    if (_currentUserId == null) return;
    debugPrint('Removing notification tokens for user: $_currentUserId');
    
    // Remove OneSignal player ID
    if (_oneSignalPlayerId != null) {
      try {
        await _db.collection('users').doc(_currentUserId).update({
          'oneSignalPlayerIds': FieldValue.arrayRemove([_oneSignalPlayerId]),
        });
        debugPrint('OneSignal player ID removed for user: $_currentUserId');
      } catch (e) {
        debugPrint('Error removing OneSignal player ID: $e');
      }
    }
    
    _currentUserId = null;
    _oneSignalPlayerId = null;
    _initialized = false;
  }

  /// Clear all OneSignal player IDs for the current user
  Future<void> clearPlayerIds() async {
    if (_currentUserId == null) return;
    try {
      await _db.collection('users').doc(_currentUserId).update({
        'oneSignalPlayerIds': [],
      });
      _oneSignalPlayerId = null;
      debugPrint('Cleared all OneSignal player IDs in Firestore for user: $_currentUserId');
    } catch (e) {
      debugPrint('Error clearing OneSignal player IDs: $e');
    }
  }

  // ============= OneSignal Integration =============

  /// Get OneSignal player ID from JavaScript and save to Firestore
  Future<void> _getAndSaveOneSignalPlayerId() async {
    if (!kIsWeb) return;
    
    try {
      // First try to get ID if already granted
      String? result = await _callJsGetPlayerId();
      debugPrint('Initial GetPlayerId Result: $result');
      
      // If no ID or result is a status string, request permission
      if (result == null || result == 'default' || result == 'denied') {
        debugPrint('ID not available yet. Requesting permission/status...');
        result = await _callJsRequestPermission();
        debugPrint('RequestPermission Result: $result');
      }
      
      // Validation: Ensure it's a reasonably long string, not a status string like "granted"
      if (result != null && result.length > 15) {
        debugPrint('Valid OneSignal Player ID obtained: $result');
        _oneSignalPlayerId = result;
        await _saveOneSignalPlayerIdToFirestore(result);
      } else {
        debugPrint('OneSignal returned non-ID result or too short: $result (Permission likely not granted)');
      }
    } catch (e) {
      debugPrint('CRITICAL ERROR in _getAndSaveOneSignalPlayerId: $e');
    }
  }

  /// Call JavaScript loginOneSignal function
  Future<void> _callJsLoginOneSignal(String externalId) async {
    if (!kIsWeb) return;
    try {
      final jsWindow = web.window as JSObject;
      if (jsWindow.hasProperty('loginOneSignal'.toJS).toDart) {
        jsWindow.callMethod('loginOneSignal'.toJS, externalId.toJS);
        debugPrint('JS: Called loginOneSignal with External ID: $externalId');
      } else {
        debugPrint('JS ERROR: loginOneSignal function NOT FOUND in index.html');
      }
    } catch (e) {
      debugPrint('Error calling JS loginOneSignal: $e');
    }
  }

  /// Call JavaScript requestPushPermission function
  Future<String?> _callJsRequestPermission() async {
    if (!kIsWeb) return null;
    
    try {
      final jsWindow = web.window as JSObject;
      if (!jsWindow.hasProperty('requestPushPermission'.toJS).toDart) {
        debugPrint('JS ERROR: requestPushPermission function NOT FOUND');
        return null;
      }
      
      final result = jsWindow.callMethod('requestPushPermission'.toJS);
      if (result != null) {
        final jsPromise = result as JSPromise;
        // Add a 30 second timeout for the permission prompt
        final value = await jsPromise.toDart.timeout(const Duration(seconds: 30));
        return value?.toString();
      }
    } catch (e) {
      debugPrint('JS requestPushPermission EXCEPTION: $e');
    }
    return null;
  }

  /// Call JavaScript getOneSignalPlayerId function
  Future<String?> _callJsGetPlayerId() async {
    if (!kIsWeb) return null;
    
    try {
      final jsWindow = web.window as JSObject;
      if (!jsWindow.hasProperty('getOneSignalPlayerId'.toJS).toDart) {
        debugPrint('JS ERROR: getOneSignalPlayerId function NOT FOUND');
        return null;
      }

      final result = jsWindow.callMethod('getOneSignalPlayerId'.toJS);
      
      if (result != null) {
        final jsPromise = result as JSPromise;
        final playerId = await jsPromise.toDart.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
              debugPrint('JS TIMEOUT: getOneSignalPlayerId timed out (10s limit).');
              return null;
          }
        );
        return playerId?.toString();
      }
    } catch (e) {
      debugPrint('JS getOneSignalPlayerId EXCEPTION: $e');
    }
    return null;
  }

  /// Save OneSignal player ID to Firestore
  Future<void> _saveOneSignalPlayerIdToFirestore(String playerId) async {
    if (_currentUserId == null) return;
    
    try {
      await _db.collection('users').doc(_currentUserId).update({
        'oneSignalPlayerIds': FieldValue.arrayUnion([playerId]),
        'lastOneSignalUpdate': FieldValue.serverTimestamp(),
      });
      debugPrint('OneSignal player ID ($playerId) persisted to Firestore for $_currentUserId');
    } catch (e) {
      debugPrint('Error saving player ID to Firestore: $e');
    }
  }

  Future<String?> _sendPushNotification({
    required List<String> playerIds,
    required String message,
    String? title,
    Map<String, dynamic>? data,
    String? pushDedupeKey, // Add external_id support for deduplication
  }) async {
    if (playerIds.isEmpty) {
      debugPrint('PUSH SKIP: playerIds list is empty');
      return 'Error: No recipients';
    }

    // ENSURE PUSH IS ENABLED IN SETTINGS
    final bool pushEnabled = await isPushEnabled();
    if (!pushEnabled) {
      debugPrint('PUSH SKIP: User disabled push notifications in settings');
      return 'Skipped (Disabled in Settings)';
    }
    
    try {
      // For web, use absolute URL to avoid issues with relative paths in some environments
      String apiUrl = _pushApiUrl;
      if (kIsWeb) {
        final origin = web.window.location.origin;
        apiUrl = (origin.endsWith('/') ? origin : '$origin/') + 
                 (_pushApiUrl.startsWith('/') ? _pushApiUrl.substring(1) : _pushApiUrl);
      }
      
      debugPrint('--- CALLING PUSH API ---');
      debugPrint('Endpoint: $apiUrl');
      debugPrint('Recipients (UIDs): $playerIds');
      debugPrint('Payload: $title - $message');
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'playerIds': playerIds, // These are intended to be External IDs (Firebase UIDs)
          'title': title ?? 'Orbit',
          'message': message,
          'data': data,
          'external_id': pushDedupeKey, // Pass custom ID for OneSignal deduplication
        }),
      );
      
      debugPrint('API Status Code: ${response.statusCode}');
      debugPrint('API Raw Body: ${response.body}');
      
      if (response.statusCode == 200) {
        return 'Sent (${response.body})';
      } else {
        return 'Error ${response.statusCode}: ${response.body}';
      }
    } catch (e) {
      debugPrint('PUSH API EXCEPTION: $e');
      return 'Exception: $e';
    }
  }

  /// Get OneSignal player IDs for a user
  Future<List<String>> _getPlayerIdsForUser(String userId) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        final playerIds = data?['oneSignalPlayerIds'];
        if (playerIds != null && playerIds is List) {
          // Filter out "None", nulls, or invalid strings that might be stuck in Firestore
          return List<String>.from(playerIds)
              .where((id) => id != 'None' && id.isNotEmpty && id.length > 15)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error getting player IDs for user $userId: $e');
    }
    return [];
  }

  // Unused FCM handlers removed during cleanup

  // Unused background message handlers have been removed as part of FCM cleanup

  // ============= Push Preference Management =============

  /// Check if push notifications are enabled for this user
  Future<bool> isPushEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pushEnabledKey) ?? true; // Enabled by default
  }

  /// Set push notification preference
  Future<void> setPushEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushEnabledKey, enabled);
    
    // Call JS bridge to opt-out/in of OneSignal
    if (kIsWeb) {
      try {
        final jsWindow = web.window as JSObject;
        if (jsWindow.hasProperty('setOneSignalPushEnabled'.toJS).toDart) {
          jsWindow.callMethod('setOneSignalPushEnabled'.toJS, enabled.toJS);
        }
      } catch (e) {
        debugPrint('Error calling JS setOneSignalPushEnabled: $e');
      }
    }
    
    debugPrint('Push notifications ${enabled ? 'enabled' : 'disabled'}');
  }

  // ============= In-App Notification Creation =============

  /// Send notification with deduplication support
  /// If dedupeKey is provided, it will update existing notification instead of creating new one
  /// Now uses doc ID for deduplication to avoid slow queries and missing indexes
  Future<String?> sendNotification({
    required String userId,
    required String message,
    required NotificationType type,
    String? dedupeKey,
    String? groupId,
    String? relatedId,
  }) async {
    try {
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

      // Define doc reference - use dedupeKey if available to naturally overwrite/deduplicate
      DocumentReference docRef;
      if (dedupeKey != null) {
        // Use a composite ID to ensure uniqueness per user
        final docId = '${userId}_$dedupeKey';
        docRef = _db.collection('notifications').doc(docId);
      } else {
        // Generate a unique ID using timestamp to guarantee this is seen as a new notification
        // even if message and relatedId are identical (e.g. separate RSVP reminders)
        final uniqueKey = '${userId}_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}';
        docRef = _db.collection('notifications').doc(uniqueKey);
      }

      await docRef.set(notificationData, SetOptions(merge: true));
      debugPrint('Notification saved for $userId (ID: ${docRef.id})');
      
      // Send push notification via OneSignal
      return await _sendPushToUser(userId, message, type.name);
    } catch (e) {
      debugPrint('Error sending notification: $e');
      return 'Error: $e';
    }
  }

  /// Send push notification to a specific user
  Future<String?> _sendPushToUser(String userId, String message, String type) async {
    // Target user by External ID (Firebase UID)
    // The backend now uses include_aliases: { external_id: ... }
    return await _sendPushNotification(
      playerIds: [userId],
      message: message,
      data: {'type': type},
    );
  }

  /// Send notifications to multiple users efficiently
  Future<void> sendNotificationToMany({
    required List<String> userIds,
    required String message,
    required NotificationType type,
    String? title,
    String? dedupeKeyPrefix,
    String? groupId,
    String? relatedId,
    String? pushDedupeKey, // Add external_id for push deduplication
  }) async {
    if (userIds.isEmpty) return;
    
    debugPrint('Sending batch notification to ${userIds.length} users');

    try {
      // 1. Create in-app notifications in Firestore using a batch
      final batch = _db.batch();
      final now = FieldValue.serverTimestamp();
      
      for (final userId in userIds) {
        final dedupeKey = dedupeKeyPrefix != null ? '${dedupeKeyPrefix}_$userId' : null;
        
        // Use composite ID for natural deduplication in batch
        DocumentReference docRef;
        if (dedupeKey != null) {
          docRef = _db.collection('notifications').doc('${userId}_$dedupeKey');
        } else {
          // Force uniqueness with timestamp and random suffix to prevent any "overwriting"
          final uniqueKey = '${userId}_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}';
          docRef = _db.collection('notifications').doc(uniqueKey);
        }
        
        batch.set(docRef, {
          'userId': userId,
          'message': message,
          'timestamp': now,
          'read': false,
          'type': type.name,
          if (dedupeKey != null) 'dedupeKey': dedupeKey,
          if (groupId != null) 'groupId': groupId,
          if (relatedId != null) 'relatedId': relatedId,
        }, SetOptions(merge: true));
      }
      
      await batch.commit();
      debugPrint('Firestore batch notifications created');

      // 2. Send push notifications in a single batch request
      await _sendPushNotification(
        playerIds: userIds,
        message: message,
        title: title,
        data: {'type': type.name},
        pushDedupeKey: pushDedupeKey,
      );
      debugPrint('Batch push notification triggered (Dedupe: $pushDedupeKey)');
    } catch (e) {
      debugPrint('Error in batch notification: $e');
    }
  }

  // ============= Specific Notification Types =============

  /// Send join request notification to group owner
  Future<void> notifyJoinRequest({
    required String ownerId,
    required String groupId,
    required String requesterId,
    required String requesterName,
    required String groupName,
  }) async {
    await sendNotification(
      userId: ownerId,
      message: '$requesterName requested to join $groupName',
      type: NotificationType.joinRequest,
      dedupeKey: 'join_${groupId}_$requesterId',
      groupId: groupId,
      relatedId: requesterId,
    );
  }

  /// Send join approval/rejection notification
  Future<void> notifyJoinProcessed({
    required String requesterId,
    required String groupName,
    required bool approved,
  }) async {
    await sendNotification(
      userId: requesterId,
      message: approved 
          ? 'Your request to join $groupName was approved! 🎉'
          : 'Your request to join $groupName was declined.',
      type: approved ? NotificationType.joinApproved : NotificationType.joinRejected,
    );
  }

  /// Send inheritance request notification to group owner/admins
  Future<void> notifyInheritanceRequest({
    required List<String> adminIds,
    required String requesterId,
    required String requesterName,
    required String placeholderName,
    required String groupId,
  }) async {
    final recipients = adminIds.where((id) => id != requesterId).toSet().toList(); // Dedupe
    debugPrint('[InheritanceNotif] adminIds: $adminIds');
    debugPrint('[InheritanceNotif] requesterId: $requesterId');
    debugPrint('[InheritanceNotif] recipients after filter: $recipients');
    
    if (recipients.isEmpty) {
      debugPrint('[InheritanceNotif] WARNING: No recipients to notify!');
      return;
    }
    
    await sendNotificationToMany(
      userIds: recipients,
      message: '$requesterName requested to inherit "$placeholderName"',
      type: NotificationType.inheritanceRequest,
      dedupeKeyPrefix: 'inherit_${groupId}_${requesterId}',
      groupId: groupId,
      relatedId: requesterId,
    );
  }

  /// Send inheritance approval/rejection notification
  Future<void> notifyInheritanceProcessed({
    required String requesterId,
    required String placeholderName,
    required bool approved,
    required String groupId,
  }) async {
    await sendNotification(
      userId: requesterId,
      message: approved
          ? 'Request to inherit "$placeholderName" approved! Data transferred. 🎉'
          : 'Request to inherit "$placeholderName" was declined.',
      type: approved ? NotificationType.inheritanceApproved : NotificationType.inheritanceRejected,
      groupId: groupId,
    );
  }

  /// Send role change notification
  Future<void> notifyRoleChange({
    required String userId,
    required String groupName,
    required String roleAction, // "promoted to admin", "demoted from admin", "is now the owner of"
    required String groupId,
  }) async {
    await sendNotification(
      userId: userId,
      message: 'You have been $roleAction $groupName',
      type: NotificationType.roleChange,
      groupId: groupId,
    );
  }

  /// Send member removal notification
  Future<void> notifyMemberRemoved({
    required String userId,
    required String groupName,
    required String groupId,
  }) async {
    await sendNotification(
      userId: userId,
      message: 'You have been removed from $groupName',
      type: NotificationType.removedFromGroup,
      groupId: groupId,
    );
  }

  /// Send event created notification to group members
  Future<void> notifyEventCreated({
    required List<String> memberIds,
    required String creatorId,
    required String eventId,
    required String eventTitle,
    required String groupId,
    required String groupName,
  }) async {
    final recipients = memberIds.where((id) => id != creatorId).toList();
    await sendNotificationToMany(
      userIds: recipients,
      message: 'New event in $groupName: $eventTitle. Click to RSVP now!',
      type: NotificationType.eventCreated,
      title: eventTitle,
      groupId: groupId,
      relatedId: eventId,
    );
  }

  /// Send event updated notification (with deduplication)
  Future<void> notifyEventUpdated({
    required List<String> memberIds,
    required String editorId,
    required String eventId,
    required String eventTitle,
    required String groupId,
    String? changeSummary,
  }) async {
    final recipients = memberIds.where((id) => id != editorId).toList();
    
    if (recipients.isEmpty) return;
    
    debugPrint('[EventUpdate] changeSummary: $changeSummary');
    
    // Format: "EventName: change1, change2 updated" or "EventName: updated"
    final message = (changeSummary != null && changeSummary.isNotEmpty)
        ? '$eventTitle: $changeSummary updated'
        : '$eventTitle: updated';
    
    debugPrint('[EventUpdate] message: $message');

    // Use separate notifications for each update (timestamped IDs used internally)
    await sendNotificationToMany(
      userIds: recipients,
      message: message,
      type: NotificationType.eventUpdated,
      title: eventTitle,
      groupId: groupId,
      relatedId: eventId,
    );
  }

  /// Send event deleted notification to group members
  Future<void> notifyEventDeleted({
    required List<String> memberIds,
    required String deleterId,
    required String eventTitle,
    required String groupId,
  }) async {
    final recipients = memberIds.where((id) => id != deleterId).toList();
    await sendNotificationToMany(
      userIds: recipients,
      message: 'Event cancelled: $eventTitle',
      type: NotificationType.eventDeleted,
      title: eventTitle,
      groupId: groupId,
    );
  }

  /// Send RSVP notification to event creator
  Future<void> notifyRSVP({
    required String creatorId,
    required String responderName,
    required String eventTitle,
    required String status,
    required String eventId,
  }) async {
    await sendNotification(
      userId: creatorId,
      message: '$responderName RSVP\'d "$status" to $eventTitle',
      type: NotificationType.rsvpReceived,
      relatedId: eventId,
    );
  }

  /// Send RSVP reminder to multiple group members
  Future<void> notifyRSVPReminder({
    required List<String> memberIds,
    required String senderId,
    required String eventId,
    required String eventTitle,
    required String groupId,
  }) async {
    final recipients = memberIds.where((id) => id != senderId).toList();
    if (recipients.isEmpty) return;

    await sendNotificationToMany(
      userIds: recipients,
      message: 'Reminder: Please RSVP for "$eventTitle"',
      type: NotificationType.eventUpdated,
      title: eventTitle,
      groupId: groupId,
      relatedId: eventId,
    );
  }

  /// Send location change notification (with deduplication)
  Future<void> notifyLocationChanged({
    required List<String> memberIds,
    required String userId,
    required String userName,
    required String location,
    required DateTime date,
    required String groupId,
  }) async {
    final recipients = memberIds.where((id) => id != userId).toList();
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    
    await sendNotificationToMany(
      userIds: recipients,
      message: '$userName will be in $location on $dateStr',
      type: NotificationType.locationChanged,
      dedupeKeyPrefix: 'location_${userId}_$dateStr',
      groupId: groupId,
      relatedId: userId,
    );
  }

  /// Send location range change notification
  Future<void> notifyLocationRangeChanged({
    required List<String> memberIds,
    required String userId,
    required String userName,
    required String location,
    required DateTime startDate,
    required DateTime endDate,
    required String groupId,
  }) async {
    final recipients = memberIds.where((id) => id != userId).toList();
    final df = DateFormat('MMM d');
    final rangeStr = '${df.format(startDate)} - ${df.format(endDate)}';
    
    await sendNotificationToMany(
      userIds: recipients,
      message: '$userName will be in $location ($rangeStr)',
      type: NotificationType.locationChanged,
      groupId: groupId,
      relatedId: userId,
    );
  }

  /// Send general location update notification (range or single)
  Future<void> notifyLocationUpdate({
    required List<String> memberIds,
    required String updaterId,
    required String updatedUserId,
    required String groupId,
    required String newLocation,
    String? updatedUserName,
  }) async {
    final recipients = memberIds.where((id) => id != updaterId).toList();
    
    // If we don't have the name, just say "A member"
    final name = updatedUserName ?? 'A member';
    final message = '$name updated location to $newLocation';
    
    await sendNotificationToMany(
      userIds: recipients,
      message: message,
      type: NotificationType.locationChanged,
      groupId: groupId,
      relatedId: updatedUserId,
    );
  }

  /// Send birthday notification
  Future<void> notifyBirthday({
    required List<String> memberIds,
    required String birthdayPersonId,
    required String birthdayPersonName,
    required bool isLunar,
    required String groupId,
  }) async {
    final recipients = memberIds.where((id) => id != birthdayPersonId).toList();
    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    final message = isLunar 
        ? '🏮 $birthdayPersonName\'s lunar birthday is today!'
        : '🎂 $birthdayPersonName\'s birthday is today!';
    
    final pushDedupeKey = 'birthday_${groupId}_${birthdayPersonId}_${dateStr}_${isLunar ? 'lunar' : 'solar'}';
    
    await sendNotificationToMany(
      userIds: recipients,
      message: message,
      type: NotificationType.birthdayToday,
      dedupeKeyPrefix: 'birthday_${birthdayPersonId}_${dateStr}_${isLunar ? 'lunar' : 'solar'}',
      groupId: groupId,
      relatedId: birthdayPersonId,
      pushDedupeKey: pushDedupeKey,
    );
  }

  /// Run all birthday checks (day-of and monthly summary)
  /// Now group-aware: any member can trigger for the whole group.
  Future<void> checkAllBirthdays(String userId, {bool force = false}) async {
    // 1. Device-level throttler (Primary gate to prevent excessive Firestore reads on every resume)
    if (!force && !await shouldCheckBirthdaysToday()) {
      debugPrint('Birthday check skipped: Already checked today on this device.');
      return;
    }

    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final currentMonthStr = '${today.year}-${today.month}';
    final todayNormalized = DateTime(today.year, today.month, today.day);

    debugPrint('--- GROUP-AWARE BIRTHDAY CHECK START ---');

    try {
      // 2. Get user's groups
      final groupsSnapshot = await _db
          .collection('groups')
          .where('members', arrayContains: userId)
          .get();

      if (groupsSnapshot.docs.isEmpty) {
        if (!force) await markBirthdayCheckDone();
        return;
      }

      for (final groupDoc in groupsSnapshot.docs) {
        final group = Group.fromFirestore(groupDoc);
        final groupId = group.id;
        final memberIds = group.members;

        // Check if group-level check is already done for today
        final bool groupDailyDone = group.lastBirthdayCheck == todayStr;
        final bool groupMonthlyDone = group.lastMonthlyBirthdayCheck == currentMonthStr;

        if (!force && groupDailyDone && (today.day != 1 || groupMonthlyDone)) {
          debugPrint('Group $groupId: Birthday check already done today ($todayStr). Skipping.');
          continue;
        }

        debugPrint('Processing Group $groupId (${group.name})...');
        final birthdayPeopleThisMonth = <String>[];
        final membersToNotifyMonthly = List<String>.from(memberIds);

        // A. Process real users in this group
        for (final memberId in memberIds) {
          final userDoc = await _db.collection('users').doc(memberId).get();
          if (!userDoc.exists) continue;

          final userData = userDoc.data()!;
          userData['uid'] = memberId;
          final displayName = userData['displayName'] ?? userData['email'] ?? 'User';

          // Solar Birthday (Today)
          final solarBirthday = Birthday.getSolarBirthday(userData, today.year);
          if (solarBirthday != null && 
              DateTime(solarBirthday.occurrenceDate.year, solarBirthday.occurrenceDate.month, solarBirthday.occurrenceDate.day) == todayNormalized) {
            await notifyBirthday(
              memberIds: memberIds, 
              birthdayPersonId: memberId, 
              birthdayPersonName: displayName, 
              isLunar: false, 
              groupId: groupId
            );
          }

          // Lunar Birthday (Today)
          final lunarBirthday = Birthday.getLunarBirthday(userData, today.year, today);
          if (lunarBirthday != null) {
            await notifyBirthday(
              memberIds: memberIds, 
              birthdayPersonId: memberId, 
              birthdayPersonName: displayName, 
              isLunar: true, 
              groupId: groupId
            );
          }

          // Monthly Collection
          if (today.day == 1 || force) {
            if (solarBirthday != null && solarBirthday.occurrenceDate.month == today.month) {
              final day = solarBirthday.occurrenceDate.day;
              birthdayPeopleThisMonth.add('$displayName (${day}${_getDaySuffix(day)})');
            }
            // Lunar month check
            for (int d = 1; d <= DateTime(today.year, today.month + 1, 0).day; d++) {
              final checkDate = DateTime(today.year, today.month, d);
              if (Birthday.getLunarBirthday(userData, today.year, checkDate) != null) {
                birthdayPeopleThisMonth.add('$displayName 🏮 (${d}${_getDaySuffix(d)})');
                break;
              }
            }
          }
        }

        // B. Process placeholders in this group
        final phSnapshot = await _db.collection('placeholder_members').where('groupId', isEqualTo: groupId).get();
        for (final phDoc in phSnapshot.docs) {
          final ph = PlaceholderMember.fromFirestore(phDoc);
          final displayName = ph.displayName;

          // Solar
          final solarBirthday = Birthday.fromPlaceholderMember(ph, today.year);
          if (solarBirthday != null && 
              DateTime(solarBirthday.occurrenceDate.year, solarBirthday.occurrenceDate.month, solarBirthday.occurrenceDate.day) == todayNormalized) {
            await notifyBirthday(memberIds: memberIds, birthdayPersonId: ph.id, birthdayPersonName: displayName, isLunar: false, groupId: groupId);
          }

          // Lunar
          final lunarBirthday = Birthday.fromPlaceholderLunar(ph, today.year, today);
          if (lunarBirthday != null) {
            await notifyBirthday(memberIds: memberIds, birthdayPersonId: ph.id, birthdayPersonName: displayName, isLunar: true, groupId: groupId);
          }

          // Monthly
          if (today.day == 1 || force) {
            if (solarBirthday != null && solarBirthday.occurrenceDate.month == today.month) {
              final day = solarBirthday.occurrenceDate.day;
              birthdayPeopleThisMonth.add('$displayName (${day}${_getDaySuffix(day)})');
            }
            for (int d = 1; d <= DateTime(today.year, today.month + 1, 0).day; d++) {
              final checkDate = DateTime(today.year, today.month, d);
              if (Birthday.fromPlaceholderLunar(ph, today.year, checkDate) != null) {
                birthdayPeopleThisMonth.add('$displayName 🏮 (${d}${_getDaySuffix(d)})');
                break;
              }
            }
          }
        }

        // C. Monthly Summary Notification
        if (birthdayPeopleThisMonth.isNotEmpty && (force || !groupMonthlyDone)) {
          debugPrint('Group $groupId: Notifying monthly summary...');
          await notifyMonthlyBirthdays(
            userIds: membersToNotifyMonthly,
            birthdayPeople: birthdayPeopleThisMonth,
            month: today.month,
            groupId: groupId,
          );
          if (!force) {
             await _db.collection('groups').doc(groupId).update({'lastMonthlyBirthdayCheck': currentMonthStr});
          }
        }

        // D. Mark Group-level daily check as done
        if (!force) {
          await _db.collection('groups').doc(groupId).update({'lastBirthdayCheck': todayStr});
        }
      }

      // 3. Mark Device-level check as done
      if (!force) await markBirthdayCheckDone();
      debugPrint('--- GROUP-AWARE BIRTHDAY CHECK COMPLETE ---');

    } catch (e) {
      debugPrint('Error during group-aware birthday checks: $e');
    }
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  /// Send monthly birthday summary notification
  Future<void> notifyMonthlyBirthdays({
    required List<String> userIds,
    required List<String> birthdayPeople,
    required int month,
    required String groupId,
  }) async {
    if (birthdayPeople.isEmpty || userIds.isEmpty) return;
    
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthName = monthNames[month - 1];
    
    final message = birthdayPeople.length == 1
        ? '🎂 $monthName Birthday: ${birthdayPeople.first}'
        : '🎂 $monthName Birthdays: ${birthdayPeople.join(', ')}';
        
    final today = DateTime.now();
    final pushDedupeKey = 'birthdayMonth_${groupId}_${today.year}_$month';

    await sendNotificationToMany(
      userIds: userIds,
      message: message,
      type: NotificationType.birthdayMonthly,
      dedupeKeyPrefix: 'birthdayMonth_${today.year}_$month',
      groupId: groupId,
      pushDedupeKey: pushDedupeKey,
    );
  }

  // ============= Birthday Check Helpers =============

  /// Check if we should run birthday checks today
  Future<bool> shouldCheckBirthdaysToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getString(_lastBirthdayCheckKey);
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    return lastCheck != todayStr;
  }

  /// Mark birthday check as done for today
  Future<void> markBirthdayCheckDone() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await prefs.setString(_lastBirthdayCheckKey, todayStr);
  }

  /// Check if we should show monthly birthday summary
  Future<bool> shouldShowMonthlyBirthdaySummary() async {
    final today = DateTime.now();
    if (today.day != 1) return false; // Only on 1st of month
    
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getString(_lastMonthlyBirthdayKey);
    final currentMonth = '${today.year}-${today.month}';
    
    return lastCheck != currentMonth;
  }

  /// Mark monthly birthday summary as shown
  Future<void> markMonthlyBirthdaySummaryDone() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final currentMonth = '${today.year}-${today.month}';
    await prefs.setString(_lastMonthlyBirthdayKey, currentMonth);
  }

  // ============= Notification Management =============

  /// Get unread notification count
  Stream<int> getUnreadCount(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      final batch = _db.batch();
      final unread = await _db
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();
      
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'read': true});
      }
      
      await batch.commit();
      debugPrint('Marked ${unread.docs.length} notifications as read');
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  /// Delete old notifications (older than 30 days)
  Future<void> cleanupOldNotifications(String userId) async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final old = await _db
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoff))
          .get();
      
      final batch = _db.batch();
      for (final doc in old.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint('Cleaned up ${old.docs.length} old notifications');
    } catch (e) {
      debugPrint('Error cleaning up notifications: $e');
    }
  }
}
