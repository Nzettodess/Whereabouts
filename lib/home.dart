import 'dart:ui';
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
import 'location_picker.dart';
import 'google_calendar_service.dart';
import 'add_event_modal.dart';
import 'notification_center.dart';
import 'settings.dart';
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
  final CalendarController _calendarController = CalendarController();

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
        // User logged out - clear data
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
    
    // Listen to locations
    FirebaseFirestore.instance.collection('user_locations').snapshots().listen((snapshot) {
      setState(() {
        _locations = snapshot.docs.map((doc) => UserLocation.fromFirestore(doc.data())).toList();
      });
    });

    // Listen to events
    FirebaseFirestore.instance.collection('events').snapshots().listen((snapshot) {
      setState(() {
        _events = snapshot.docs.map((doc) => GroupEvent.fromFirestore(doc)).toList();
      });
    });

    // Listen to all users for default locations
    FirebaseFirestore.instance.collection('users').snapshots().listen((snapshot) {
      setState(() {
        _allUsers = snapshot.docs.map((doc) => doc.data()..['uid'] = doc.id).toList();
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
      builder: (context) => LocationPicker(
        defaultCountry: defaultCountry,
        defaultState: defaultState,
        onLocationSelected: (country, state, startDate, endDate) async {
          try {
            await _firestoreService.setLocationRange(
              _user!.uid,
              "global",
              startDate,
              endDate,
              country,
              state,
            );
            
            if (mounted) {
              final dayCount = endDate.difference(startDate).inDays + 1;
              final dateRange = dayCount == 1 
                  ? DateFormat('MMM dd, yyyy').format(startDate)
                  : "${DateFormat('MMM dd').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}";
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Location set to ${state != null ? '$state, ' : ''}$country for $dateRange ($dayCount day${dayCount > 1 ? 's' : ''})"
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
      ),
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
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NotificationCenter(currentUserId: _user!.uid)),
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
