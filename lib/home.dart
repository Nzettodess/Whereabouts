import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart'; // Needed for CalendarController
import 'login.dart';
import 'profile.dart';
import 'group_management.dart';
import 'firestore_service.dart';
import 'models.dart';
import 'models/placeholder_member.dart';
import 'location_picker.dart';
import 'google_calendar_service.dart';
import 'add_event_modal.dart';
import 'notification_center.dart';
import 'settings.dart';
import 'rsvp_management.dart';
import 'widgets/home_calendar.dart';
import 'widgets/home_drawer.dart';
import 'upcoming_summary_dialog.dart';
import 'detail_modal.dart';
import 'widgets/credits_feedback_dialog.dart';
import 'birthday_baby_dialog.dart';
import 'services/connectivity_service.dart';
import 'services/session_service.dart';
import 'services/holiday_cache_service.dart';
import 'services/notification_service.dart';
import 'widgets/skeleton_loading.dart';
import 'widgets/delayed_empty_state.dart';
import 'widgets/home_speed_dial.dart';
import 'widgets/home_app_bar.dart';

class HomeWithLogin extends StatefulWidget {
  const HomeWithLogin({super.key});

  @override
  State<HomeWithLogin> createState() => _HomeWithLoginState();
}

class _HomeWithLoginState extends State<HomeWithLogin>
    with WidgetsBindingObserver {
  User? _user = FirebaseAuth.instance.currentUser;
  String? _photoUrl;
  String? _displayName;
  double _previousKeyboardHeight = 0;
  final FirestoreService _firestoreService = FirestoreService();
  final GoogleCalendarService _googleCalendarService = GoogleCalendarService();

  List<UserLocation> _locations = [];
  List<UserLocation> _realUserLocations = [];
  List<UserLocation> _placeholderUserLocations = [];
  List<GroupEvent> _events = [];
  List<Holiday> _holidays = [];
  List<String> _religiousCalendars = []; // Enabled religious calendars
  String _tileCalendarDisplay =
      'none'; // For tile display: none, chinese, islamic

  String _currentMonthTitle = "Calendar";
  DateTime _currentViewMonth = DateTime.now();
  List<Map<String, dynamic>> _allUsers = [];
  List<PlaceholderMember> _placeholderMembers = [];
  List<Group> _myGroups = [];
  final CalendarController _calendarController = CalendarController();

  // Subscription management to prevent stale data
  StreamSubscription? _groupsSubscription;
  StreamSubscription? _locationsSubscription;
  StreamSubscription? _placeholderLocationsSubscription;
  StreamSubscription? _usersSubscription;
  StreamSubscription? _placeholderMembersSubscription;
  StreamSubscription? _eventsSubscription;
  StreamSubscription? _settingsSubscription;
  StreamSubscription? _profileSubscription;
  StreamSubscription<bool>? _connectivitySubscription;

  // Session service for multi-device detection
  SessionService? _sessionService;
  Set<String> _knownSessionIds = {};
  final ValueNotifier<List<Map<String, dynamic>>> _sessionsNotifier =
      ValueNotifier([]);
  bool _silenceMultiSessionWarning = false;
  bool _isMultiSessionWarningOpen = false;
  bool _isSessionTerminated = false;

  // Offline status for persistent banner
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize connectivity service
    ConnectivityService().init();
    _setupConnectivityListener();

    // Listen to auth state changes (login/logout)
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _user = user;
        });
      }

      if (user != null) {
        // User logged in - end any previous session first (for account switching)
        _endSessionTracking();

        _loadUserProfile(); // Sets up real-time sync
        _loadData();
        _startSessionTracking(user.uid);
        // Initialize FCM for push notifications
        NotificationService().initialize(user.uid);
        // Check for birthday notifications (day-of and monthly summary)
        _checkBirthdayNotifications(user.uid);
      } else {
        // User logged out - clear data and cancel subscriptions
        _endSessionTracking();
        _cancelAllSubscriptions();
        _firestoreService.clearAllCaches();
        if (mounted) {
          setState(() {
            _photoUrl = null;
            _displayName = null;
            _locations = [];
            _events = [];
            _holidays = [];
            _allUsers = [];
          });
        }
      }
    });
  }

  void _setupConnectivityListener() {
    // Check initial state
    _isOffline = !ConnectivityService().isOnline;

    _connectivitySubscription = ConnectivityService().onlineStatus.listen((
      isOnline,
    ) {
      if (!mounted) return;

      final wasOffline = _isOffline;
      setState(() => _isOffline = !isOnline);

      // Only show "back online" snackbar when transitioning from offline to online
      if (wasOffline && isOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_done, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Back online!'),
              ],
            ),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _startSessionTracking(String userId) {
    _sessionService = SessionService(userId);
    _knownSessionIds = {};
    _silenceMultiSessionWarning = false;
    _sessionService?.startSession(
      onMultipleSessions: (sessions) {
        if (mounted) {
          final currentSessionId = _sessionService?.currentSessionId;
          final sessionIds = sessions.map((s) => s['id'] as String).toSet();

          // Identify "new" session IDs (IDs present in current stream but not in _knownSessionIds)
          final newSessionIds = sessionIds.difference(_knownSessionIds);

          // Always update the notifier so open dialogs see current data
          _sessionsNotifier.value = sessions;

          final hasRealNewSessions = newSessionIds.any(
            (id) => id != currentSessionId,
          );

          // Only trigger warning if silenced is false, has new sessions, not already open, AND count > 1
          if (!_silenceMultiSessionWarning &&
              hasRealNewSessions &&
              !_isMultiSessionWarningOpen &&
              sessions.length > 1) {
            _showMultiSessionWarning();
          }

          // Always update the known IDs
          _knownSessionIds = sessionIds;
        }
      },
      onSessionTerminated: () {
        if (mounted) {
          // Clear navigation stack (close all dialogs/sheets)
          Navigator.of(context).popUntil((route) => route.isFirst);
          _showSessionTerminatedDialog();
        }
      },
    );
  }

  void _showSessionTerminatedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.orange[700], size: 22),
            const SizedBox(width: 8),
            const Flexible(child: Text('Session Terminated')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This session was terminated from another device.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'You can safely close this tab. If you continue, a new session will be created which may conflict with other active sessions.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Show terminated banner
              setState(() => _isSessionTerminated = true);
            },
            child: Text('Close Tab', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Clear terminated state and start new session
              setState(() => _isSessionTerminated = false);
              if (_user != null) {
                _startSessionTracking(_user!.uid);
              }
            },
            child: const Text('Continue Anyway'),
          ),
        ],
      ),
    );
  }

  void _endSessionTracking() {
    _sessionService?.endSession();
    _sessionService = null;
  }

  /// Check if writes are allowed (session is active and online)
  bool get _canWrite => !_isSessionTerminated && !_isOffline;

  /// Show dialog when write is blocked and return false
  bool _checkCanWrite() {
    if (_isSessionTerminated) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.block, color: Colors.grey[700], size: 22),
              const SizedBox(width: 8),
              const Text('Session Terminated'),
            ],
          ),
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

    if (_isOffline) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.orange[800], size: 22),
              const SizedBox(width: 8),
              const Text('Read-Only Mode'),
            ],
          ),
          content: const Text(
            'You are currently offline. Changes cannot be saved until you are back online.',
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

  void _showMultiSessionWarning() {
    _isMultiSessionWarningOpen = true;

    // Using a slightly longer delay (500ms) on Web to avoid engine/window.dart assertions
    // which happen when dialogs are shown before window metrics have settled.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) {
        _isMultiSessionWarningOpen = false;
        return;
      }

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange[700],
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'Multiple Sessions',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400, maxWidth: 300),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'You are logged in on multiple devices or tabs.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange[700],
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'This may cause data sync conflicts.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<List<Map<String, dynamic>>>(
                      valueListenable: _sessionsNotifier,
                      builder: (context, currentSessions, _) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Sessions (${currentSessions.length}):',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...currentSessions
                                .take(5)
                                .map(
                                  (s) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          size: 6,
                                          color: s['isCurrentSession'] == true
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '${s['device']}${s['isCurrentSession'] == true ? ' (current)' : ''}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight:
                                                  s['isCurrentSession'] == true
                                                  ? FontWeight.w500
                                                  : FontWeight.normal,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            if (currentSessions.length > 5)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '...and ${currentSessions.length - 5} more',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Silent checkbox
                    InkWell(
                      onTap: () {
                        setDialogState(() {
                          _silenceMultiSessionWarning =
                              !_silenceMultiSessionWarning;
                        });
                      },
                      child: Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _silenceMultiSessionWarning,
                              onChanged: (val) {
                                setDialogState(() {
                                  _silenceMultiSessionWarning = val ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              "Don't show again for this session",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await _sessionService?.terminateOtherSessions();
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Other sessions terminated'),
                      ),
                    );
                  }
                },
                child: Text(
                  'Terminate others',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ).then((_) {
        _isMultiSessionWarningOpen = false;
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('App Lifecycle State Changed: $state');
    
    if (state == AppLifecycleState.resumed) {
      if (_user != null) {
        debugPrint('App Resumed - Triggering background birthday checks...');
        _checkBirthdayNotifications(_user!.uid);
      }
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Use both viewInsets and platformDispatcher for better compatibility across platforms (App/Web)
    final keyboardHeight = WidgetsBinding
        .instance
        .platformDispatcher
        .views
        .first
        .viewInsets
        .bottom;

    // If keyboard was present and is now gone
    if (_previousKeyboardHeight > 0 && keyboardHeight == 0) {
      // Small delay to let the OS/Browser finish its transition
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          // Force unfocus to ensure focus-related UI shifts are cleared
          FocusManager.instance.primaryFocus?.unfocus();
          // Safety: specifically unfocus any active text field if keyboard is gone
          if (keyboardHeight == 0) {
            FocusScope.of(context).unfocus();
          }
          // Force a rebuild to reset any MediaQuery dependent values
          setState(() {});
        }
      });
    }
    _previousKeyboardHeight = keyboardHeight;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _endSessionTracking();
    _connectivitySubscription?.cancel();
    _cancelAllSubscriptions();
    super.dispose();
  }

  void _cancelAllSubscriptions() {
    _groupsSubscription?.cancel();
    _groupsSubscription = null;
    _locationsSubscription?.cancel();
    _locationsSubscription = null;
    _placeholderLocationsSubscription?.cancel();
    _placeholderLocationsSubscription = null;
    _usersSubscription?.cancel();
    _usersSubscription = null;
    _placeholderMembersSubscription?.cancel();
    _placeholderMembersSubscription = null;
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _settingsSubscription?.cancel();
    _settingsSubscription = null;
    _profileSubscription?.cancel();
    _profileSubscription = null;
  }

  void _cancelDataSubscriptions() {
    // Cancel inner data subscriptions (not groups subscription)
    _locationsSubscription?.cancel();
    _locationsSubscription = null;
    _placeholderLocationsSubscription?.cancel();
    _placeholderLocationsSubscription = null;
    _usersSubscription?.cancel();
    _usersSubscription = null;
    _placeholderMembersSubscription?.cancel();
    _placeholderMembersSubscription = null;
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _settingsSubscription?.cancel();
    _settingsSubscription = null;
  }

  void _handleLoginSuccess() async {
    // Auth state listener will handle the update
    // Just reload data manually for immediate update
    _loadUserProfile();
    _loadData();
  }

  void _loadUserProfile() {
    if (_user == null) return;

    // Cache-First: yield last seen profile immediately if available
    final cached = _firestoreService.getLastSeenProfile(_user!.uid);
    if (cached != null) {
      _photoUrl = cached['photoURL'];
      _displayName = cached['displayName'];
    }

    _profileSubscription?.cancel();
    _profileSubscription = _firestoreService
        .getUserProfileStream(_user!.uid)
        .listen((data) {
          if (!mounted) return;
          setState(() {
            _photoUrl = data['photoURL'];
            _displayName = data['displayName'];
          });
        });
  }

  /// Check and send birthday notifications (day-of and monthly summary)
  /// Called once on app load, with deduplication to prevent spam
  Future<void> _checkBirthdayNotifications(String userId) async {
    await NotificationService().checkAllBirthdays(userId);
  }

  void _updateCombinedLocations() {
    if (!mounted) return;

    final all = [..._realUserLocations, ..._placeholderUserLocations];

    // Deduplicate: If a user has multiple entries for the same day (due to multiple shared groups),
    // we only keep one to avoid calendar clutter.
    final Map<String, UserLocation> deduped = {};
    for (final loc in all) {
      final dateStr =
          "${loc.date.year}-${loc.date.month.toString().padLeft(2, '0')}-${loc.date.day.toString().padLeft(2, '0')}";
      final key = "${loc.userId}_$dateStr";
      if (!deduped.containsKey(key)) {
        deduped[key] = loc;
      }
    }

    setState(() {
      _locations = deduped.values.toList();
    });
  }

  void _loadData() {
    if (_user == null) return;

    // Cancel existing subscriptions
    _cancelAllSubscriptions();

    final userId = _user!.uid;

    // --- 1. Cache First: Immediate UI Update ---
    final cachedGroups = _firestoreService.getLastSeenGroups(userId);
    if (cachedGroups != null) {
      print('[Home] Applying cached groups');
      _myGroups = cachedGroups;
      final groupIds = cachedGroups.map((g) => g.id).toList();
      _loadDataFromCache(userId, groupIds);
    }

    // --- 2. Live Listeners: Background Updates ---
    _groupsSubscription = _firestoreService.getUserGroups(userId).listen((
      userGroups,
    ) {
      if (!mounted) return;

      // Calculate member signatures to detect content changes (not just list changes)
      // This ensures that if someone joins/leaves a group, our data filters update.
      final oldSignature = _myGroups
          .map((g) => '${g.id}:${g.members.join(',')}')
          .join('|');
      final newSignature = userGroups
          .map((g) => '${g.id}:${g.members.join(',')}')
          .join('|');

      setState(() {
        _myGroups = userGroups;
      });

      // Restart listeners if group list OR member composition changed
      if (oldSignature != newSignature || _eventsSubscription == null) {
        print('[Home] Groups or members changed, resetting data listeners');
        _setupDataListeners(userId, userGroups.map((g) => g.id).toList());
      }
    });
  }

  void _loadDataFromCache(String userId, List<String> groupIds) {
    // Events
    final cachedEvents = _firestoreService.getLastSeenEvents(userId);
    if (cachedEvents != null) {
      _events = cachedEvents;
    }

    // Users
    final cachedUsers = _firestoreService.getLastSeenUsers();
    if (cachedUsers != null) {
      // Filter to only my group members and DEDUPLICATE by userId
      final myGroupMemberIds = <String>{};
      for (final group in _myGroups) {
        myGroupMemberIds.addAll(group.members);
      }

      final userIdToGroupId =
          <String, String>{}; // First group the user is found in
      for (final user in cachedUsers) {
        final userId = user['uid'] as String;
        if (myGroupMemberIds.contains(userId) &&
            !userIdToGroupId.containsKey(userId)) {
          // Use first group found for this user
          final matchingGroups = _myGroups
              .where((g) => g.members.contains(userId))
              .toList();
          if (matchingGroups.isNotEmpty) {
            userIdToGroupId[userId] = matchingGroups.first.id;
          }
        }
      }

      final filteredUsersWithGroups = <Map<String, dynamic>>[];
      for (final user in cachedUsers) {
        final userId = user['uid'] as String;
        if (userIdToGroupId.containsKey(userId)) {
          final userWithGroup = Map<String, dynamic>.from(user);
          userWithGroup['groupId'] = userIdToGroupId[userId];
          filteredUsersWithGroups.add(userWithGroup);
        }
      }
      _allUsers = filteredUsersWithGroups;
    }

    // Own Locations
    final cachedLocs = _firestoreService.getLastSeenAllLocations(userId);
    if (cachedLocs != null) {
      // Logic from _setupDataListeners for merging
      final myGroupMemberIds = <String>{};
      for (final group in _myGroups) {
        myGroupMemberIds.addAll(group.members);
      }
      final filteredLocs = cachedLocs
          .where((loc) => myGroupMemberIds.contains(loc.userId))
          .toList();

      // Placeholder Locations
      final cachedPlaceholderLocs = _firestoreService
          .getLastSeenPlaceholderLocations(userId);
      if (cachedPlaceholderLocs != null) {
        _locations = [...filteredLocs, ...cachedPlaceholderLocs];
      } else {
        _locations = filteredLocs;
      }
    }

    // Placeholder Members
    final cachedPlaceholderMembers = _firestoreService
        .getLastSeenPlaceholderMembers(userId);
    if (cachedPlaceholderMembers != null) {
      _placeholderMembers = cachedPlaceholderMembers;
    }

    if (mounted) setState(() {});
  }

  void _setupDataListeners(String userId, List<String> groupIds) {
    _cancelDataSubscriptions();

    final myGroupMemberIds = <String>{};
    for (final group in _myGroups) {
      myGroupMemberIds.addAll(group.members);
    }

    // 1. Events
    _eventsSubscription = _firestoreService.getAllUserEvents(userId).listen((
      events,
    ) {
      if (mounted) setState(() => _events = events);
    });

    // 2. Locations (Real Users) - Now passing groupIds for targeted fetching
    _locationsSubscription = _firestoreService
        .getAllUserLocationsStream(userId, groupIds)
        .listen((allLocs) {
          if (!mounted) return;

          // Filter by group members (Secondary filter for local safety)
          final userLocations = allLocs
              .where((loc) => myGroupMemberIds.contains(loc.userId))
              .toList();

          _realUserLocations = userLocations;
          _updateCombinedLocations();
        });

    // 3. Placeholder Locations
    if (groupIds.isNotEmpty) {
      _placeholderLocationsSubscription = _firestoreService
          .getPlaceholderLocationsStream(userId, groupIds)
          .listen((pLocs) {
            if (!mounted) return;
            _placeholderUserLocations = pLocs;
            _updateCombinedLocations();
          });
    }

    // 4. Users - Only fetch users who are in my groups (security rule compliant)
    final memberIdsList = myGroupMemberIds.toList();
    _usersSubscription = _firestoreService
        .getUsersByIdsStream(memberIdsList)
        .listen((allUsers) {
          if (!mounted) return;

          // Assign each user to their first matching group (for display purposes)
          final userIdToGroupId = <String, String>{};
          for (final user in allUsers) {
            final uid = user['uid'] as String? ?? '';
            if (!userIdToGroupId.containsKey(uid)) {
              final matchingGroups = _myGroups
                  .where((g) => g.members.contains(uid))
                  .toList();
              if (matchingGroups.isNotEmpty) {
                userIdToGroupId[uid] = matchingGroups.first.id;
              }
            }
          }

          final filteredUsersWithGroups = <Map<String, dynamic>>[];
          for (final user in allUsers) {
            final uid = user['uid'] as String? ?? '';
            if (userIdToGroupId.containsKey(uid)) {
              final userWithGroup = Map<String, dynamic>.from(user);
              userWithGroup['groupId'] = userIdToGroupId[uid];
              filteredUsersWithGroups.add(userWithGroup);
            }
          }

          setState(() {
            _allUsers = filteredUsersWithGroups;
          });
        });

    // 5. Placeholder Members
    if (groupIds.isNotEmpty) {
      _placeholderMembersSubscription = _firestoreService
          .getPlaceholderMembersStream(userId, groupIds)
          .listen((members) {
            if (mounted) setState(() => _placeholderMembers = members);
          });
    }

    // 6. Settings and Holidays
    _settingsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
          if (!mounted || !snapshot.exists) return;
          final data = snapshot.data();
          if (data == null) return;

          debugPrint(
            '[Home] Settings Update: tileCalendarDisplay=${data['tileCalendarDisplay']}, religiousCalendars=${data['religiousCalendars']}',
          );
          setState(() {
            _religiousCalendars = List<String>.from(
              data['religiousCalendars'] ?? [],
            );
            _tileCalendarDisplay = data['tileCalendarDisplay'] ?? 'none';
            _photoUrl = data['photoURL'];
          });

          _loadHolidaysFromData(data);
        });
  }

  void _loadHolidaysFromData(Map<String, dynamic> data) {
    final calendarIds = <String>[];
    final defaultLocation = data['defaultLocation'];

    if (defaultLocation != null &&
        defaultLocation is String &&
        defaultLocation.isNotEmpty) {
      final countryCodeMap = {
        "United States": "US",
        "United Kingdom": "GB",
        "Canada": "CA",
        "Australia": "AU",
        "New Zealand": "NZ",
        "Singapore": "SG",
        "Malaysia": "MY",
        "Indonesia": "ID",
        "Thailand": "TH",
        "Philippines": "PH",
        "Vietnam": "VN",
        "Japan": "JP",
        "South Korea": "KR",
        "China": "CN",
        "Hong Kong": "HK",
        "Taiwan": "TW",
        "India": "IN",
        "Germany": "DE",
        "France": "FR",
        "Italy": "IT",
        "Spain": "ES",
        "Netherlands": "NL",
        "Belgium": "BE",
        "Switzerland": "CH",
        "Austria": "AT",
        "Sweden": "SE",
        "Norway": "NO",
        "Denmark": "DK",
        "Finland": "FI",
        "Poland": "PL",
        "Ireland": "IE",
        "Portugal": "PT",
        "Greece": "GR",
        "Brazil": "BR",
        "Mexico": "MX",
        "Argentina": "AR",
        "Chile": "CL",
        "Colombia": "CO",
        "South Africa": "ZA",
        "Egypt": "EG",
        "Nigeria": "NG",
        "Russia": "RU",
        "Turkey": "TR",
        "Saudi Arabia": "SA",
        "United Arab Emirates": "AE",
        "Israel": "IL",
      };

      final parts = defaultLocation.split(',');
      String? foundCountryCode;
      for (var part in parts) {
        var cleanPart = part.trim();
        if (countryCodeMap.containsKey(cleanPart)) {
          foundCountryCode = countryCodeMap[cleanPart];
          break;
        }
        final match = countryCodeMap.keys.firstWhere(
          (k) => cleanPart.contains(k),
          orElse: () => '',
        );
        if (match.isNotEmpty) {
          foundCountryCode = countryCodeMap[match];
          break;
        }
      }

      if (foundCountryCode != null) {
        final calendarId =
            GoogleCalendarService.countryCalendars[foundCountryCode];
        debugPrint(
          '[Home] Mapping Public Holiday (PH): $defaultLocation -> $foundCountryCode -> $calendarId',
        );
        if (calendarId != null) calendarIds.add(calendarId);
      } else {
        debugPrint(
          '[Home] No Public Holiday (PH) mapping found for location: $defaultLocation',
        );
      }
    }

    final additional = data['additionalHolidayCountry'];
    if (additional != null && additional is String && additional.isNotEmpty) {
      final calendarId = GoogleCalendarService.countryCalendars[additional];
      if (calendarId != null && !calendarIds.contains(calendarId))
        calendarIds.add(calendarId);
    }

    for (final religionKey in _religiousCalendars) {
      final calendarId = GoogleCalendarService.religiousCalendars[religionKey];
      if (calendarId != null && !calendarIds.contains(calendarId))
        calendarIds.add(calendarId);
    }

    _fetchHolidays(calendarIds);
  }

  void _fetchHolidays(List<String> calendarIds) async {
    if (_user == null) return;

    final cacheService = HolidayCacheService(_user!.uid);
    debugPrint(
      '[Home] Fetching holidays for ${calendarIds.length} calendars: $calendarIds',
    );
    final holidays = await cacheService.getHolidays(calendarIds);
    // debugPrint('[Home] Fetched ${holidays.length} Public Holiday (PH) total for $calendarIds');

    if (mounted) {
      setState(() {
        _holidays = holidays;
      });
    }
  }

  void _openAddEventModal() {
    if (!_checkCanWrite()) return;
    if (_user != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => AddEventModal(
          currentUserId: _user!.uid,
          initialDate: DateTime.now(),
        ),
      );
    }
  }

  void _openUpcomingSummary() async {
    if (_user == null) return;

    // Build group names map
    final groupNames = <String, String>{};
    final groupsSnapshot = await _firestoreService
        .getUserGroups(_user!.uid)
        .first;
    for (final group in groupsSnapshot) {
      groupNames[group.id] = group.name;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => UpcomingSummaryDialog(
        currentUserId: _user!.uid,
        events: _events,
        locations: _locations,
        holidays: _holidays,
        allUsers: _allUsers,
        placeholderMembers: _placeholderMembers,
        groupNames: groupNames,
        canWrite: _canWrite,
        onDateTap: (date) {
          // Get data for the selected date
          final dayLocations = _getLocationsForDate(date);
          final dayEvents = _events
              .where(
                (e) =>
                    e.date.year == date.year &&
                    e.date.month == date.month &&
                    e.date.day == date.day,
              )
              .toList();
          final dayHolidays = _holidays
              .where(
                (h) =>
                    h.date.year == date.year &&
                    h.date.month == date.month &&
                    h.date.day == date.day,
              )
              .toList();
          final dayBirthdays = _getBirthdaysForDate(date);

          // Open detail modal
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => DetailModal(
              date: date,
              locations: dayLocations,
              events: dayEvents,
              holidays: dayHolidays,
              birthdays: dayBirthdays,
              currentUserId: _user!.uid,
              canWrite: _canWrite,
              allUsers: _allUsers,
            ),
          );
        },
      ),
    );
  }

  void _openBirthdayBabyDialog() {
    // Map group IDs to names for the dialog
    final groupNames = <String, String>{};
    // Need access to current groups, but they are in stream.
    // We can infer group names if needed or pass empty if not used for display.

    showDialog(
      context: context,
      builder: (context) => BirthdayBabyDialog(
        currentUserId: _user!.uid,
        allUsers: _allUsers,
        placeholderMembers: _placeholderMembers,
        groupNames: groupNames,
      ),
    );
  }

  void _openLocationPicker() async {
    if (!_checkCanWrite()) return;
    if (_user == null) return;

    // Check if user has any groups or placeholders to manage
    if (_myGroups.isEmpty && _placeholderMembers.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No Groups'),
            content: const Text(
              'You need to belong to at least one group to set a location context.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Fetch user's default location
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .get();
    final defaultLocation = doc.data()?['defaultLocation'] as String?;

    // Helper function to remove emoji flags
    String stripEmojis(String text) {
      // Remove emojis (including flag emojis) and extra whitespace
      return text
          .replaceAll(
            RegExp(
              r'[\u{1F1E6}-\u{1F1FF}]|\p{Emoji_Presentation}|\p{Emoji}\uFE0F',
              unicode: true,
            ),
            '',
          )
          .trim();
    }

    // Parse country and state from default location
    String? defaultCountry;
    String? defaultState;

    if (defaultLocation != null && defaultLocation.isNotEmpty) {
      final parts = defaultLocation.split(',');

      if (parts.length == 2) {
        // Format: "🇲🇾 Country, State" (e.g., "🇲🇾 Malaysia, Penang")
        defaultCountry = stripEmojis(parts[0].trim()); // First part is COUNTRY
        defaultState = stripEmojis(parts[1].trim()); // Second part is STATE
      } else {
        // Format: "🇺🇸 Country" only
        defaultCountry = stripEmojis(parts[0].trim());
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        // Filter group members who allow location editing (privacy check)
        // Exclude current user, exclude placeholders, only real members
        final editableMembers = _allUsers.where((user) {
          final uid = user['uid'] as String?;
          if (uid == null || uid == _user!.uid) return false; // Skip self
          if (uid.startsWith('placeholder_')) return false; // Skip placeholders

          // Check privacy settings - if blockLocationDate is true, exclude
          final privacySettings =
              user['privacySettings'] as Map<String, dynamic>?;
          if (privacySettings != null &&
              privacySettings['blockLocationDate'] == true) {
            return false;
          }
          return true;
        }).toList();

        // Check if current user is owner or admin of any group
        // We'll check this based on groups data we already have
        // For simplicity, pass true if we have editable members or placeholders
        final canManageOthers =
            editableMembers.isNotEmpty || _placeholderMembers.isNotEmpty;

        return LocationPicker(
          defaultCountry: defaultCountry,
          defaultState: defaultState,
          currentUserId: _user!.uid,
          placeholderMembers: List<PlaceholderMember>.from(_placeholderMembers),
          groupMembers: editableMembers,
          isOwnerOrAdmin: canManageOthers,
          onLocationSelected: (country, state, startDate, endDate, selectedMemberIds) async {
            try {
              // Set location for each selected member
              for (final memberId in selectedMemberIds) {
                if (memberId.startsWith('placeholder_')) {
                  // Placeholder member - use placeholder location service
                  await _firestoreService.setPlaceholderMemberLocationRange(
                    memberId,
                    // Find the group ID from placeholder
                    _placeholderMembers
                        .firstWhere((p) => p.id == memberId)
                        .groupId,
                    startDate,
                    endDate,
                    country,
                    state,
                  );
                } else {
                  // Regular user
                  await _firestoreService.setLocationRange(
                    memberId,
                    "global",
                    startDate,
                    endDate,
                    country,
                    state,
                  );
                  // Notification is handled internally by FirestoreService now
                }
              } // end for loop

              if (mounted) {
                final dayCount = endDate.difference(startDate).inDays + 1;
                final memberCount = selectedMemberIds.length;
                final dateRange = dayCount == 1
                    ? DateFormat('MMM dd, yyyy').format(startDate)
                    : "${DateFormat('MMM dd').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}";

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Location set for $memberCount member${memberCount > 1 ? 's' : ''} "
                      "to ${state != null ? '$state, ' : ''}$country for $dateRange",
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Error saving location: $e"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        );
      },
    );
  }

  // Helper to get locations for a specific date (for DetailModal from Upcoming)
  List<UserLocation> _getLocationsForDate(DateTime date) {
    // Get explicit locations for this date
    final explicit = _locations
        .where(
          (l) =>
              l.date.year == date.year &&
              l.date.month == date.month &&
              l.date.day == date.day,
        )
        .toList();

    final explicitUserIds = explicit.map((l) => l.userId).toSet();

    // Add default locations for users without explicit entries
    final others = <UserLocation>[];
    for (final user in _allUsers) {
      if (!explicitUserIds.contains(user['uid'])) {
        final defaultLoc = user['defaultLocation'] as String?;
        final userGroupId = user['groupId'] as String? ?? 'global';

        if (defaultLoc != null && defaultLoc.isNotEmpty) {
          final parts = defaultLoc.split(', ');
          final country = parts[0];
          final state = parts.length > 1 ? parts[1] : null;

          others.add(
            UserLocation(
              userId: user['uid'],
              groupId: userGroupId,
              date: date,
              nation: country,
              state: state,
            ),
          );
        } else {
          others.add(
            UserLocation(
              userId: user['uid'],
              groupId: userGroupId,
              date: date,
              nation: "No location selected",
              state: null,
            ),
          );
        }
      }
    }

    return [...explicit, ...others];
  }

  // Helper to get birthdays for a specific date
  List<Birthday> _getBirthdaysForDate(DateTime date) {
    final birthdays = <Birthday>[];

    for (final user in _allUsers) {
      // Get solar birthday
      final solarBirthday = Birthday.getSolarBirthday(user, date.year);
      if (solarBirthday != null) {
        if (solarBirthday.occurrenceDate.month == date.month &&
            solarBirthday.occurrenceDate.day == date.day) {
          birthdays.add(solarBirthday);
        }
      }

      // Get lunar birthday
      final lunarBirthday = Birthday.getLunarBirthday(user, date.year, date);
      if (lunarBirthday != null) {
        birthdays.add(lunarBirthday);
      }
    }

    return birthdays;
  }

  // Helper to get events for a specific date
  List<GroupEvent> _getEventsForDate(DateTime date) {
    return _events.where((e) {
      final eventDate = e.date;
      return eventDate.year == date.year &&
          eventDate.month == date.month &&
          eventDate.day == date.day;
    }).toList();
  }

  // Helper to get holidays for a specific date
  List<Holiday> _getHolidaysForDate(DateTime date) {
    return _holidays.where((h) {
      final holidayDate = h.date;
      return holidayDate.year == date.year &&
          holidayDate.month == date.month &&
          holidayDate.day == date.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Show calendar behind login overlay so users can see what the app is about
    if (_user == null) {
      debugPrint('[Home] Building Login/Preview View');
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.7),
              ),
            ),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset("assets/orbit_logo.svg", height: 40),
              const SizedBox(width: 8),
              Text(
                "Orbit",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            // Show the calendar in the background
            HomeCalendar(
              currentUserId: '', // Empty for preview mode
              locations: [],
              events: [],
              holidays: [],
              controller: _calendarController,
              currentViewMonth: _currentViewMonth,
              religiousCalendars: [],
              tileCalendarDisplay: 'none',
              allUsers: [],
              placeholderMembers: [],
              onMonthChanged: (title, viewMonth) {},
              canWrite: false,
            ),
            // Blur filter over the calendar
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.black.withValues(alpha: 0.1)),
              ),
            ),
            // Login overlay on top
            LoginOverlay(onSignedIn: _handleLoginSuccess),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        extendBodyBehindAppBar: true,
      appBar: HomeAppBar(
        user: _user,
        canWrite: _canWrite,
        photoUrl: _photoUrl,
        displayName: _displayName,
        allUsers: _allUsers,
        onUpcomingTap: _openUpcomingSummary,
        onBirthdayTap: _openBirthdayBabyDialog,
        onProfileTap: () {
          if (!_checkCanWrite()) return;
          showDialog(
            context: context,
            builder: (_) => ProfileDialog(user: _user!),
          );
        },
        getLocationsForDate: _getLocationsForDate,
        getEventsForDate: _getEventsForDate,
        getHolidaysForDate: _getHolidaysForDate,
        getBirthdaysForDate: _getBirthdaysForDate,
      ),
        drawer: HomeDrawer(
          user: _user,
          displayName: _displayName,
          photoUrl: _photoUrl,
          onProfileTap: () {
            if (!_checkCanWrite()) return;
            showDialog(
              context: context,
              builder: (_) => ProfileDialog(user: _user!),
            );
          },
          onManageGroupsTap: () {
            if (!_checkCanWrite()) return;
            showDialog(
              context: context,
              builder: (context) => const GroupManagementDialog(),
            );
          },
          onUpcomingTap: _openUpcomingSummary,
          onBirthdayBabyTap: _openBirthdayBabyDialog,

          onRSVPManagementTap: () {
            if (!_checkCanWrite()) return;
            showDialog(
              context: context,
              builder: (context) =>
                  RSVPManagementDialog(currentUserId: _user!.uid),
            );
          },
          onSettingsTap: () {
            if (!_checkCanWrite()) return;
            if (_user != null) {
              showDialog(
                context: context,
                builder: (context) => SettingsDialog(currentUserId: _user!.uid),
              ).then((_) {
                // Force refresh data after settings change (holidays, calendars, etc.)
                _loadData();
                if (mounted) setState(() {});
              });
            }
          },
        ),
        body: Stack(
          children: [
            // Persistent offline banner
            // Persistent offline banner
            if (_isOffline)
              Positioned(
                top: MediaQuery.of(context).padding.top + kToolbarHeight,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.orange[800],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'You are offline. Changes cannot be saved.',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Simple status label for consistency with "Resume" layout
                      const Text(
                        'Read Only',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            // Session terminated banner
            if (_isSessionTerminated)
              Positioned(
                top:
                    MediaQuery.of(context).padding.top +
                    kToolbarHeight +
                    (_isOffline ? 40 : 0),
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.grey[700],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cancel_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Session terminated. You can safely close this tab.',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _isSessionTerminated = false);
                          if (_user != null) {
                            _startSessionTracking(_user!.uid);
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                        ),
                        child: const Text(
                          'Resume',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(
                top:
                    MediaQuery.of(context).padding.top +
                    kToolbarHeight +
                    16 +
                    (_isOffline ? 40 : 0) +
                    (_isSessionTerminated ? 40 : 0),
              ),
              child: Column(
                children: [
                  DelayedEmptyStateWidget(
                    stream: _firestoreService.getUserGroups(_user!.uid),
                    delayMs: 800, // Wait 800ms before showing empty state
                    skeletonBuilder: () => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            SkeletonCircle(size: 40),
                            const SizedBox(height: 10),
                            const SkeletonBox(width: 120, height: 16),
                            const SizedBox(height: 5),
                            const SkeletonBox(width: 200, height: 14),
                          ],
                        ),
                      ),
                    ),
                    emptyBuilder: () => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(
                              Icons.group_add,
                              size: 40,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "No Groups Yet",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "Create or join a group to see events.",
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) =>
                                      const GroupManagementDialog(),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text("Get Started"),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Calendar Controls
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _currentMonthTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: () {
                                _calendarController.backward!();
                              },
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                _calendarController.displayDate =
                                    DateTime.now();
                              },
                              icon: const Icon(Icons.today, size: 16),
                              label: const Text('Today'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.deepPurple, // Solid purple
                                foregroundColor:
                                    Colors.white, // White text/icon
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () {
                                _calendarController.forward!();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Calendar
                  Expanded(
                    child: HomeCalendar(
                      controller: _calendarController,
                      locations: _locations,
                      events: _events,
                      holidays: _holidays,
                      allUsers: _allUsers,
                      placeholderMembers: _placeholderMembers,
                      tileCalendarDisplay: _tileCalendarDisplay,
                      religiousCalendars: _religiousCalendars,
                      currentUserId: _user?.uid ?? '',
                      currentViewMonth: _currentViewMonth,
                      canWrite: _canWrite,
                      onMonthChanged: (title, date) {
                        setState(() {
                          _currentMonthTitle = title;
                          _currentViewMonth = date;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20), // Space for FAB
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: HomeSpeedDial(
          onAddEvent: _openAddEventModal,
          onAddLocation: _openLocationPicker,
        ),
      ),
    );
  }
}
