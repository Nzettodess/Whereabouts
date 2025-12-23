import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import '../models.dart';

/// Service for managing push notifications (FCM) and in-app notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get oneSignalPlayerId => _oneSignalPlayerId;

  static const String _pushEnabledKey = 'push_notifications_enabled';
  static const String _lastBirthdayCheckKey = 'last_birthday_check_date';
  static const String _lastMonthlyBirthdayKey = 'last_monthly_birthday_check';
  
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
    if (_initialized && _currentUserId == userId && _oneSignalPlayerId != null) return;
    
    _currentUserId = userId;
    
    // Clear "None" from cache if present
    if (_oneSignalPlayerId == 'None') _oneSignalPlayerId = null;

    // Get OneSignal player ID and save to Firestore (web only)
    if (kIsWeb) {
      await _getAndSaveOneSignalPlayerId();
      
      // Sync push status to OneSignal
      final enabled = await isPushEnabled();
      await setPushEnabled(enabled);
    }
    
    _initialized = true;
    debugPrint('NotificationService initialized for user: $userId');
  }

  // FCM token persistence has been removed - using OneSignal as primary provider

  /// Reset service when user logs out
  Future<void> removeToken() async {
    if (_currentUserId == null) return;
    
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
      debugPrint('Cleared all OneSignal player IDs for user: $_currentUserId');
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
      
      // If no ID or result is a status string, request permission
      if (result == null || result == 'default' || result == 'denied') {
        debugPrint('Requesting OneSignal permission/status...');
        result = await _callJsRequestPermission();
      }
      
      // Validation: Ensure it's a reasonably long string, not a status string like "granted"
      if (result != null && result.length > 15) {
        _oneSignalPlayerId = result;
        await _saveOneSignalPlayerIdToFirestore(result);
      } else {
        debugPrint('OneSignal returned non-ID result or too short: $result');
      }
    } catch (e) {
      debugPrint('Error getting OneSignal player ID: $e');
    }
  }

  /// Call JavaScript requestPushPermission function
  Future<String?> _callJsRequestPermission() async {
    if (!kIsWeb) return null;
    
    try {
      final jsWindow = web.window as JSObject;
      if (!jsWindow.hasProperty('requestPushPermission'.toJS).toDart) {
        debugPrint('JS requestPushPermission function not found');
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
      debugPrint('JS requestPushPermission error: $e');
    }
    return null;
  }

  /// Call JavaScript getOneSignalPlayerId function
  Future<String?> _callJsGetPlayerId() async {
    if (!kIsWeb) return null;
    
    try {
      final jsWindow = web.window as JSObject;
      if (!jsWindow.hasProperty('getOneSignalPlayerId'.toJS).toDart) {
        debugPrint('JS getOneSignalPlayerId function not found');
        return null;
      }

      final result = jsWindow.callMethod('getOneSignalPlayerId'.toJS);
      if (result != null) {
        final jsPromise = result as JSPromise;
        final value = await jsPromise.toDart.timeout(const Duration(seconds: 5));
        return value?.toString();
      }
    } catch (e) {
      debugPrint('JS getOneSignalPlayerId error: $e');
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
      debugPrint('OneSignal player ID saved for user: $_currentUserId');
    } catch (e) {
      debugPrint('Error saving OneSignal player ID: $e');
    }
  }

  /// Send push notification via serverless function
  Future<String?> _sendPushNotification({
    required List<String> playerIds,
    required String message,
    String? title,
    Map<String, dynamic>? data,
  }) async {
    if (playerIds.isEmpty) {
      debugPrint('PUSH ERROR: playerIds is empty');
      return 'Error: No playerIds';
    }
    
    try {
      // For web, use absolute URL to avoid issues with relative paths in some environments
      String apiUrl = _pushApiUrl;
      if (kIsWeb) {
        final origin = web.window.location.origin;
        apiUrl = (origin.endsWith('/') ? origin : '$origin/') + 
                 (_pushApiUrl.startsWith('/') ? _pushApiUrl.substring(1) : _pushApiUrl);
      }
      
      debugPrint('Sending push to $apiUrl for ${playerIds.length} players');
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'playerIds': playerIds,
          'title': title ?? 'Orbit',
          'message': message,
          'data': data,
        }),
      );
      
      if (response.statusCode == 200) {
        debugPrint('Push notification logic triggered successfully');
        return 'Sent (${response.body})';
      } else {
        debugPrint('Push notification API error (Status ${response.statusCode}): ${response.body}');
        return 'Error ${response.statusCode}: ${response.body}';
      }
    } catch (e) {
      debugPrint('Error calling push API: $e');
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

      if (dedupeKey != null) {
        // Check for existing notification with same dedupeKey
        final existing = await _db
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .where('dedupeKey', isEqualTo: dedupeKey)
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          // Update existing notification
          await existing.docs.first.reference.update({
            'message': message,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });
          debugPrint('Updated existing notification: $dedupeKey');
          // Still trigger push for update
          return await _sendPushToUser(userId, message, type.name);
        }
      }

      // Create new notification
      await _db.collection('notifications').add(notificationData);
      debugPrint('Created notification for $userId: $message');
      
      // Send push notification via OneSignal
      return await _sendPushToUser(userId, message, type.name);
    } catch (e) {
      debugPrint('Error sending notification: $e');
      return 'Error: $e';
    }
  }

  /// Send push notification to a specific user
  Future<String?> _sendPushToUser(String userId, String message, String type) async {
    final playerIds = await _getPlayerIdsForUser(userId);
    if (playerIds.isNotEmpty) {
      return await _sendPushNotification(
        playerIds: playerIds,
        message: message,
        data: {'type': type},
      );
    }
    return 'No Player IDs found';
  }

  /// Send notifications to multiple users
  Future<void> sendNotificationToMany({
    required List<String> userIds,
    required String message,
    required NotificationType type,
    String? dedupeKeyPrefix,
    String? groupId,
    String? relatedId,
  }) async {
    for (final userId in userIds) {
      await sendNotification(
        userId: userId,
        message: message,
        type: type,
        dedupeKey: dedupeKeyPrefix != null ? '${dedupeKeyPrefix}_$userId' : null,
        groupId: groupId,
        relatedId: relatedId,
      );
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
      message: 'New event in $groupName: $eventTitle',
      type: NotificationType.eventCreated,
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
  }) async {
    final recipients = memberIds.where((id) => id != editorId).toList();
    for (final userId in recipients) {
      await sendNotification(
        userId: userId,
        message: 'Event updated: $eventTitle',
        type: NotificationType.eventUpdated,
        dedupeKey: 'event_$eventId',
        groupId: groupId,
        relatedId: eventId,
      );
    }
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
    
    for (final recipientId in recipients) {
      await sendNotification(
        userId: recipientId,
        message: '$userName will be in $location on $dateStr',
        type: NotificationType.locationChanged,
        dedupeKey: 'location_${userId}_$dateStr',
        groupId: groupId,
        relatedId: userId,
      );
    }
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
        ? '🌙 $birthdayPersonName\'s lunar birthday is today!'
        : '🎂 $birthdayPersonName\'s birthday is today!';
    
    for (final recipientId in recipients) {
      await sendNotification(
        userId: recipientId,
        message: message,
        type: NotificationType.birthdayToday,
        dedupeKey: 'birthday_${birthdayPersonId}_$dateStr',
        groupId: groupId,
        relatedId: birthdayPersonId,
      );
    }
  }

  /// Send monthly birthday summary notification
  Future<void> notifyMonthlyBirthdays({
    required String userId,
    required List<String> birthdayPeople,
    required int month,
  }) async {
    if (birthdayPeople.isEmpty) return;
    
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthName = monthNames[month - 1];
    
    final message = birthdayPeople.length == 1
        ? '🎂 $monthName Birthday: ${birthdayPeople.first}'
        : '🎂 $monthName Birthdays: ${birthdayPeople.join(', ')}';
    
    await sendNotification(
      userId: userId,
      message: message,
      type: NotificationType.birthdayMonthly,
      dedupeKey: 'birthdayMonth_${DateTime.now().year}_$month',
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
