import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';

/// Service for managing push notifications (FCM) and in-app notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _pushEnabledKey = 'push_notifications_enabled';
  static const String _lastBirthdayCheckKey = 'last_birthday_check_date';
  static const String _lastMonthlyBirthdayKey = 'last_monthly_birthday_check';

  bool _initialized = false;
  String? _currentUserId;
  String? _fcmToken;

  /// Initialize the notification service
  Future<void> initialize(String userId) async {
    if (_initialized && _currentUserId == userId) return;
    
    _currentUserId = userId;
    
    // Request permissions (will prompt user on first install)
    await _requestPermissions();
    
    // Get FCM token and save it
    await _getAndSaveToken();
    
    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _saveTokenToFirestore(newToken);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background/terminated message taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    
    _initialized = true;
    debugPrint('NotificationService initialized for user: $userId');
  }

  /// Request notification permissions
  Future<bool> _requestPermissions() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
                      settings.authorizationStatus == AuthorizationStatus.provisional;
      
      debugPrint('Notification permission: ${settings.authorizationStatus}');
      return granted;
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
    }
  }

  /// Get FCM token and save to Firestore
  Future<void> _getAndSaveToken() async {
    try {
      // For web, we need to pass the VAPID key
      if (kIsWeb) {
        // Token will be null if permissions denied or not available
        _fcmToken = await _messaging.getToken(
          vapidKey: 'BDckkZhJu0uf_EMAofN6_8-qE5GntR-qNNC404-6cEZcADjoFIu-s8pKKMzENrFBek_pO6_xWM3DdD8TVU_2OXA',
        );
      } else {
        _fcmToken = await _messaging.getToken();
      }
      
      if (_fcmToken != null) {
        await _saveTokenToFirestore(_fcmToken!);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  /// Save FCM token to Firestore for the current user
  Future<void> _saveTokenToFirestore(String token) async {
    if (_currentUserId == null) return;
    
    try {
      await _db.collection('users').doc(_currentUserId).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      _fcmToken = token;
      debugPrint('FCM token saved for user: $_currentUserId');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Remove FCM token when user logs out
  Future<void> removeToken() async {
    if (_currentUserId == null || _fcmToken == null) return;
    
    try {
      await _db.collection('users').doc(_currentUserId).update({
        'fcmTokens': FieldValue.arrayRemove([_fcmToken]),
      });
      debugPrint('FCM token removed for user: $_currentUserId');
    } catch (e) {
      debugPrint('Error removing FCM token: $e');
    }
    
    _currentUserId = null;
    _fcmToken = null;
    _initialized = false;
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message received: ${message.notification?.title}');
    // In-app notifications are handled by Firestore stream, no action needed
  }

  /// Handle when user taps a notification that opened the app
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('Notification opened app: ${message.notification?.title}');
    // Could navigate to notification center here
  }

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
    debugPrint('Push notifications ${enabled ? 'enabled' : 'disabled'}');
  }

  // ============= In-App Notification Creation =============

  /// Send notification with deduplication support
  /// If dedupeKey is provided, it will update existing notification instead of creating new one
  Future<void> sendNotification({
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
          return;
        }
      }

      // Create new notification
      await _db.collection('notifications').add(notificationData);
      debugPrint('Created notification for $userId: $message');
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
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
