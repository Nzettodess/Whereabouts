import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

class HomeWithLogin extends StatefulWidget {
  const HomeWithLogin({super.key});

  @override
  State<HomeWithLogin> createState() => _HomeWithLoginState();
}

class _HomeWithLoginState extends State<HomeWithLogin> {
  User? _user = FirebaseAuth.instance.currentUser;
  String? _photoUrl;
  final FirestoreService _firestoreService = FirestoreService();
  final GoogleCalendarService _googleCalendarService = GoogleCalendarService();
  
  List<UserLocation> _locations = [];
  List<GroupEvent> _events = [];
  List<Holiday> _holidays = [];
  List<String> _religiousCalendars = []; // Enabled religious calendars
  String _tileCalendarDisplay = 'none'; // For tile display: none, chinese, islamic
  
  String _currentMonthTitle = "Calendar";
  DateTime _currentViewMonth = DateTime.now();
  List<Map<String, dynamic>> _allUsers = [];
  List<PlaceholderMember> _placeholderMembers = [];
  final CalendarController _calendarController = CalendarController();
  
  // Subscription management to prevent stale data
  StreamSubscription? _groupsSubscription;
  StreamSubscription? _locationsSubscription;
  StreamSubscription? _placeholderLocationsSubscription;
  StreamSubscription? _usersSubscription;
  StreamSubscription? _placeholderMembersSubscription;
  StreamSubscription? _eventsSubscription;
  StreamSubscription? _settingsSubscription;

  @override
  void initState() {
    super.initState();
    
    // Listen to auth state changes (login/logout)
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      setState(() {
        _user = user;
      });
      
      if (user != null) {
        // User logged in
        _loadUserProfile();
        _loadData();
      } else {
        // User logged out - clear data and cancel subscriptions
        _cancelAllSubscriptions();
        setState(() {
          _photoUrl = null;
          _locations = [];
          _events = [];
          _holidays = [];
          _allUsers = [];
        });
      }
    });
  }
  
  @override
  void dispose() {
    _cancelAllSubscriptions();
    super.dispose();
  }
  
  void _cancelAllSubscriptions() {
    _groupsSubscription?.cancel();
    _locationsSubscription?.cancel();
    _placeholderLocationsSubscription?.cancel();
    _usersSubscription?.cancel();
    _placeholderMembersSubscription?.cancel();
    _eventsSubscription?.cancel();
    _settingsSubscription?.cancel();
  }
  
  void _cancelDataSubscriptions() {
    // Cancel inner data subscriptions (not groups subscription)
    _locationsSubscription?.cancel();
    _placeholderLocationsSubscription?.cancel();
    _usersSubscription?.cancel();
    _placeholderMembersSubscription?.cancel();
  }

  void _handleLoginSuccess() async {
    // Auth state listener will handle the update
    // Just reload data manually for immediate update
    await _loadUserProfile();
    _loadData();
  }

  Future<void> _loadUserProfile() async {
    if (_user == null) return;
    final doc = await FirebaseFirestore.instance.collection("users").doc(_user!.uid).get();
    if (doc.exists) {
      setState(() {
        _photoUrl = doc.data()?['photoURL'];
      });
    }
  }

  void _loadData() {
    if (_user == null) return;
    
    // Cancel existing subscriptions before creating new ones
    _cancelAllSubscriptions();

    // Get current user's groups to filter locations, users, and events
    _groupsSubscription = _firestoreService.getUserGroups(_user!.uid).listen((userGroups) {
      // Cancel previous data subscriptions when groups change
      _cancelDataSubscriptions();
      
      final myGroupIds = userGroups.map((g) => g.id).toList();
      
      // Build a set of all member IDs across all my groups (for filtering)
      final myGroupMemberIds = <String>{};
      for (final group in userGroups) {
        myGroupMemberIds.addAll(group.members);
      }
      
      // Listen to events - filter by user's groups
      // Firestore 'whereIn' is limited to 10 items, so batch if needed
      if (myGroupIds.isNotEmpty) {
        _eventsSubscription?.cancel();
        if (myGroupIds.length <= 10) {
          _eventsSubscription = FirebaseFirestore.instance
              .collection('events')
              .where('groupId', whereIn: myGroupIds)
              .snapshots()
              .listen((snapshot) {
            setState(() {
              _events = snapshot.docs.map((doc) => GroupEvent.fromFirestore(doc)).toList();
            });
          });
        } else {
          // For more than 10 groups, query in batches and merge
          _loadEventsBatched(myGroupIds);
        }
      } else {
        setState(() {
          _events = [];
        });
      }
      
      // Listen to user_locations - filter to only my group members
      _locationsSubscription = FirebaseFirestore.instance.collection('user_locations').snapshots().listen((userLocSnapshot) {
        final userLocations = userLocSnapshot.docs
          .map((doc) => UserLocation.fromFirestore(doc.data()))
          .where((loc) => myGroupMemberIds.contains(loc.userId)) // Filter by group members
          .toList();
        
        // Also listen to placeholder_member_locations - filter to my groups
        _placeholderLocationsSubscription?.cancel();
        _placeholderLocationsSubscription = FirebaseFirestore.instance.collection('placeholder_member_locations').snapshots().listen((placeholderLocSnapshot) {
          final placeholderLocations = placeholderLocSnapshot.docs
            .map((doc) {
              final data = doc.data();
              return UserLocation(
                userId: data['placeholderMemberId'] ?? '',
                groupId: data['groupId'] ?? 'global',
                date: (data['date'] as Timestamp).toDate(),
                nation: data['nation'] ?? '',
                state: data['state'],
              );
            })
            .where((loc) => myGroupIds.contains(loc.groupId)) // Filter by my groups
            .toList();
          
          setState(() {
            _locations = [...userLocations, ...placeholderLocations];
          });
        });
      });
      
      // Listen to all users but filter to only those in my groups
      _usersSubscription = FirebaseFirestore.instance.collection('users').snapshots().listen((snapshot) {
        final allUsers = snapshot.docs.map((doc) => doc.data()..['uid'] = doc.id).toList();
        
        // Filter to only my group members and DEDUPLICATE by userId
        // Each user should appear only once, not per-group
        final userIdToGroupId = <String, String>{}; // First group the user is found in
        for (final user in allUsers) {
          final userId = user['uid'] as String;
          if (myGroupMemberIds.contains(userId) && !userIdToGroupId.containsKey(userId)) {
            // Use first group found for this user
            final matchingGroups = userGroups.where((g) => g.members.contains(userId)).toList();
            if (matchingGroups.isNotEmpty) {
              userIdToGroupId[userId] = matchingGroups.first.id;
            }
          }
        }
        
        // Create deduplicated user list with single groupId per user
        final filteredUsersWithGroups = <Map<String, dynamic>>[];
        for (final user in allUsers) {
          final userId = user['uid'] as String;
          if (userIdToGroupId.containsKey(userId)) {
            final userWithGroup = Map<String, dynamic>.from(user);
            userWithGroup['groupId'] = userIdToGroupId[userId];
            filteredUsersWithGroups.add(userWithGroup);
          }
        }
        
        // Also listen to placeholder members (filter by my groups)
        _placeholderMembersSubscription?.cancel();
        _placeholderMembersSubscription = FirebaseFirestore.instance.collection('placeholder_members').snapshots().listen((placeholderSnapshot) {
          final allPlaceholders = placeholderSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'uid': doc.id,
              'displayName': '👻 ${data['displayName'] ?? 'Placeholder'}',
              'defaultLocation': data['defaultLocation'],
              'birthday': data['birthday'],
              'hasLunarBirthday': data['hasLunarBirthday'] ?? false,
              'lunarBirthdayMonth': data['lunarBirthdayMonth'],
              'lunarBirthdayDay': data['lunarBirthdayDay'],
              'isPlaceholder': true,
              'groupId': data['groupId'],
            };
          }).toList();
          
          // Filter placeholders to only those in my groups
          final filteredPlaceholders = allPlaceholders.where((p) {
            return myGroupIds.contains(p['groupId']);
          }).toList();
          
          // Also populate placeholder members list for location picker
          final placeholderMembersList = placeholderSnapshot.docs
            .where((doc) => myGroupIds.contains(doc.data()['groupId']))
            .map((doc) => PlaceholderMember.fromFirestore(doc))
            .toList();
          
          setState(() {
            _allUsers = [...filteredUsersWithGroups, ...filteredPlaceholders];
            _placeholderMembers = placeholderMembersList;
          });
        });
      });
    });

    // Listen to user settings for Holiday changes
    FirebaseFirestore.instance.collection('users').doc(_user!.uid).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        
        // Load religious calendars
        final religious = data?['religiousCalendars'];
        if (religious != null && religious is List) {
          setState(() {
            _religiousCalendars = List<String>.from(religious);
          });
        }

        // Load tile calendar display preference
        final tileDisplay = data?['tileCalendarDisplay'];
        if (tileDisplay != null && tileDisplay is String) {
          setState(() {
            _tileCalendarDisplay = tileDisplay;
          });
        }
        
        // Gather calendar IDs for holiday fetching
        final calendarIds = <String>[];
        
        // Primary country from default location
        final defaultLocation = data?['defaultLocation'];
        if (defaultLocation != null && defaultLocation is String && defaultLocation.isNotEmpty) {

          // Map country name to code
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

          // Default location format: "State, Country" or "Country"
          // We'll split by comma and check each part to see if it's a valid country
          final parts = defaultLocation.split(',');
          String? foundCountryCode;
          
          for (var part in parts) {
            var cleanPart = part.trim();
            // Remove emojis/flags if present (simple regex for non-ascii might be too aggressive, 
            // so let's just try to match the name directly first)
            
            // Check exact match
            if (countryCodeMap.containsKey(cleanPart)) {
              foundCountryCode = countryCodeMap[cleanPart];
              break;
            }
            
            // Check if part contains country name (e.g. "🇲🇾 Malaysia")
            final match = countryCodeMap.keys.firstWhere(
              (k) => cleanPart.contains(k), 
              orElse: () => ''
            );
            if (match.isNotEmpty) {
              foundCountryCode = countryCodeMap[match];
              break;
            }
          }
          
          if (foundCountryCode != null) {
            final calendarId = GoogleCalendarService.countryCalendars[foundCountryCode];
            if (calendarId != null) {
              calendarIds.add(calendarId);
            }
          }
        }
        
        // Additional country from settings
        final additional = data?['additionalHolidayCountry'];
        if (additional != null && additional is String && additional.isNotEmpty) {
          final calendarId = GoogleCalendarService.countryCalendars[additional];
          if (calendarId != null && !calendarIds.contains(calendarId)) {
            calendarIds.add(calendarId);
          }
        }
        
        // Religious calendars from state (already loaded above)
        for (final religionKey in _religiousCalendars) {
          final calendarId = GoogleCalendarService.religiousCalendars[religionKey];
          if (calendarId != null && !calendarIds.contains(calendarId)) {
            calendarIds.add(calendarId);
          }
        }
        
        // Fetch holidays from all selected calendars
        if (calendarIds.isNotEmpty) {
          _fetchHolidays(calendarIds);
        } else {
          setState(() {
            _holidays = [];
          });
        }
      }
    });
  }

  // Load events in batches when user is in more than 10 groups
  void _loadEventsBatched(List<String> groupIds) async {
    const batchSize = 10;
    final allEvents = <GroupEvent>[];
    
    for (var i = 0; i < groupIds.length; i += batchSize) {
      final batch = groupIds.skip(i).take(batchSize).toList();
      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('groupId', whereIn: batch)
          .get();
      
      allEvents.addAll(snapshot.docs.map((doc) => GroupEvent.fromFirestore(doc)));
    }
    
    if (mounted) {
      setState(() {
        _events = allEvents;
      });
    }
  }

  void _fetchHolidays(List<String> calendarIds) {
    _googleCalendarService.fetchMultipleCalendars(calendarIds, DateTime.now().year).then((holidays) {
      setState(() {
        _holidays = holidays;
      });
    });
  }

  void _openAddEventModal() {
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


  void _openLocationPicker() async {
    if (_user == null) return;
    
    // Fetch user's default location
    final doc = await FirebaseFirestore.instance.collection('users').doc(_user!.uid).get();
    final defaultLocation = doc.data()?['defaultLocation'] as String?;
    
    // Helper function to remove emoji flags
    String stripEmojis(String text) {
      // Remove emojis (including flag emojis) and extra whitespace
      return text.replaceAll(RegExp(r'[\u{1F1E6}-\u{1F1FF}]|\p{Emoji_Presentation}|\p{Emoji}\uFE0F', unicode: true), '').trim();
    }
    
    // Parse country and state from default location
    String? defaultCountry;
    String? defaultState;
    
    if (defaultLocation != null && defaultLocation.isNotEmpty) {
      final parts = defaultLocation.split(',');
      
      if (parts.length == 2) {
        // Format: "🇲🇾 Country, State" (e.g., "🇲🇾 Malaysia, Penang")
        defaultCountry = stripEmojis(parts[0].trim());  // First part is COUNTRY
        defaultState = stripEmojis(parts[1].trim());     // Second part is STATE
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
          if (uid == null || uid == _user!.uid) return false;  // Skip self
          if (uid.startsWith('placeholder_')) return false;  // Skip placeholders
          
          // Check privacy settings - if blockLocationDate is true, exclude
          final privacySettings = user['privacySettings'] as Map<String, dynamic>?;
          if (privacySettings != null && privacySettings['blockLocationDate'] == true) {
            return false;
          }
          return true;
        }).toList();
        
        // Check if current user is owner or admin of any group
        // We'll check this based on groups data we already have
        // For simplicity, pass true if we have editable members or placeholders
        final canManageOthers = editableMembers.isNotEmpty || _placeholderMembers.isNotEmpty;
        
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
                  _placeholderMembers.firstWhere((p) => p.id == memberId).groupId,
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
              }
            }
            
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
                    "to ${state != null ? '$state, ' : ''}$country for $dateRange"
                  )
                )
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error saving location: $e"))
              );
            }
          }
        },
      );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = _user != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            Image.asset("assets/logo.png", height: 32),
            const SizedBox(width: 8),
            const Text("Whereabouts", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          if (loggedIn) ...[
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.black),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => NotificationCenter(currentUserId: _user!.uid),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0, left: 8.0),
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => ProfileDialog(user: _user!),
                  );
                },
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[200],
                  child: ClipOval(
                    child: Image.network(
                      _user?.photoURL ?? _photoUrl ?? "https://ui-avatars.com/api/?name=${Uri.encodeComponent(_user?.displayName ?? 'User')}",
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.network(
                          "https://ui-avatars.com/api/?name=${Uri.encodeComponent(_user?.displayName ?? 'User')}",
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ]
        ],
      ),
      drawer: loggedIn
          ? HomeDrawer(
              user: _user,
              photoUrl: _photoUrl,
              onProfileTap: () {
                showDialog(
                  context: context,
                  builder: (_) => ProfileDialog(user: _user!),
                );
              },
              onManageGroupsTap: () {
                showDialog(
                  context: context,
                  builder: (context) => const GroupManagementDialog(),
                );
              },
              onRSVPManagementTap: () {
                showDialog(
                  context: context,
                  builder: (context) => RSVPManagementDialog(
                    currentUserId: _user!.uid,
                  ),
                );
              },
              onSettingsTap: () {
                if (_user != null) {
                  showDialog(
                    context: context,
                    builder: (context) => SettingsDialog(currentUserId: _user!.uid),
                  );
                }
              },
            )
          : null,
      body: Stack(
        children: [
          Column(
            children: [
                const SizedBox(height: 20),
                if (loggedIn)
                  StreamBuilder<List<Group>>(
                    stream: _firestoreService.getUserGroups(_user!.uid),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                const Icon(Icons.group_add, size: 40, color: Colors.deepPurple),
                                const SizedBox(height: 10),
                                const Text(
                                  "No Groups Yet",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 5),
                                const Text("Create or join a group to see events.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => const GroupManagementDialog(),
                                    );
                                  },
                                  child: const Text("Get Started"),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                
                // Calendar Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_currentMonthTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                              _calendarController.displayDate = DateTime.now();
                            },
                            icon: const Icon(Icons.today, size: 16),
                            label: const Text('Today'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    tileCalendarDisplay: _tileCalendarDisplay,
                    religiousCalendars: _religiousCalendars,
                    currentUserId: _user?.uid ?? '',
                    currentViewMonth: _currentViewMonth,
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
          if (!loggedIn) ...[
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.black.withOpacity(0.2)),
              ),
            ),
            LoginOverlay(onSignedIn: _handleLoginSuccess),
          ],
        ],
      ),
      floatingActionButton: loggedIn ? Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "event",
            onPressed: _openAddEventModal,
            child: const Icon(Icons.event),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "location",
            onPressed: _openLocationPicker,
            child: const Icon(Icons.add_location),
          ),
        ],
      ) : null,
    );
  }
}
