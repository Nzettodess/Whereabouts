import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:intl/intl.dart';
import 'login.dart';
import 'profile.dart';
import 'group_management.dart';
import 'firestore_service.dart';
import 'models.dart';
import 'location_picker.dart';
import 'calendar_data_source.dart';
import 'google_calendar_service.dart';
import 'detail_modal.dart';
import 'add_event_modal.dart';
import 'notification_center.dart';
import 'settings.dart';
import 'religious_calendar_helper.dart';

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
  
  String _currentMonthTitle = "Calendar";
  List<Map<String, dynamic>> _allUsers = [];
  final CalendarController _calendarController = CalendarController();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadData();
  }

  void _handleLoginSuccess() async {
    setState(() {
      _user = FirebaseAuth.instance.currentUser;
    });
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
          String? foundCountryName;
          
          for (var part in parts) {
            var cleanPart = part.trim();
            // Remove emojis/flags if present (simple regex for non-ascii might be too aggressive, 
            // so let's just try to match the name directly first)
            
            // Check exact match
            if (countryCodeMap.containsKey(cleanPart)) {
              foundCountryName = cleanPart;
              foundCountryCode = countryCodeMap[cleanPart];
              break;
            }
            
            // Check if part contains country name (e.g. "🇲🇾 Malaysia")
            final match = countryCodeMap.keys.firstWhere(
              (k) => cleanPart.contains(k), 
              orElse: () => ''
            );
            if (match.isNotEmpty) {
              foundCountryName = match;
              foundCountryCode = countryCodeMap[match];
              break;
            }
          }
          
          print('DEBUG: Default location: $defaultLocation');
          print('DEBUG: Extracted country: $foundCountryName, Code: $foundCountryCode');
          
          if (foundCountryCode != null) {
            final calendarId = GoogleCalendarService.countryCalendars[foundCountryCode];
            print('DEBUG: Calendar ID: $calendarId');
            if (calendarId != null) {
              calendarIds.add(calendarId);
            }
          } else {
            print('DEBUG: No matching country found in default location');
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

  // Helper to get effective locations for a date
  List<UserLocation> _getLocationsForDate(DateTime date) {
    // 1. Get explicit locations
    final explicit = _locations.where((l) => 
      l.date.year == date.year && l.date.month == date.month && l.date.day == date.day).toList();
    
    final explicitUserIds = explicit.map((l) => l.userId).toSet();

    // 2. Add default locations for users who don't have explicit location
    final defaults = <UserLocation>[];
    for (final user in _allUsers) {
      if (!explicitUserIds.contains(user['uid']) && user['defaultLocation'] != null && (user['defaultLocation'] as String).isNotEmpty) {
        // Parse default location "Country, State" or just "Country"
        final parts = (user['defaultLocation'] as String).split(', ');
        final country = parts[0];
        final state = parts.length > 1 ? parts[1] : null;
        
        defaults.add(UserLocation(
          userId: user['uid'],
          groupId: "global", // or "default"
          date: date,
          nation: country,
          state: state,
        ));
      }
    }

    return [...explicit, ...defaults];
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

  void _openLocationPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => LocationPicker(
        onLocationSelected: (country, state) async {
          if (_user != null) {
            try {
              await _firestoreService.setLocation(
                _user!.uid, 
                "global", 
                DateTime.now(), 
                country, 
                state
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Location set to $country, ${state ?? ''}"))
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error saving location: $e"))
                );
              }
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
          ? Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: const BoxDecoration(color: Colors.deepPurple),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context); // Close drawer
                            showDialog(
                              context: context,
                              builder: (_) => ProfileDialog(user: _user!),
                            );
                          },
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            child: ClipOval(
                              child: Image.network(
                                _user?.photoURL ?? _photoUrl ?? "https://ui-avatars.com/api/?name=${Uri.encodeComponent(_user?.displayName ?? 'User')}",
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.network(
                                    "https://ui-avatars.com/api/?name=${Uri.encodeComponent(_user?.displayName ?? 'User')}",
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _user?.displayName ?? _user?.email ?? "User",
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.group),
                    title: const Text("Manage Groups"),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => const GroupManagementDialog(),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text("Settings"),
                    onTap: () {
                      Navigator.pop(context);
                      if (_user != null) {
                        showDialog(
                          context: context,
                          builder: (context) => SettingsDialog(currentUserId: _user!.uid),
                        );
                      }
                    },
                  ),
                ],
              ),
            )
          : null,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
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
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: SizedBox(
                    height: 500,
                    child: SfCalendar(
                      controller: _calendarController,
                      view: CalendarView.month,
                      headerHeight: 0,
                      dataSource: MyCalendarDataSource(_locations, _holidays, _events),
                      monthViewSettings: const MonthViewSettings(
                        appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
                        showAgenda: false,
                      ),
                      onViewChanged: (ViewChangedDetails details) {
                        if (details.visibleDates.isNotEmpty) {
                          final midDate = details.visibleDates[details.visibleDates.length ~/ 2];
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                _currentMonthTitle = DateFormat('MMMM yyyy').format(midDate);
                              });
                            }
                          });
                        }
                      },
                      monthCellBuilder: (context, details) {
                        final date = details.date;
                        final dayLocations = _getLocationsForDate(date);
                        final dayHolidays = _holidays.where((h) => 
                          h.date.year == date.year && h.date.month == date.month && h.date.day == date.day).toList();
                        
                        // Get religious calendar dates for this day
                        final religiousDates = ReligiousCalendarHelper.getReligiousDates(date, _religiousCalendars);
                        
                        return Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.withOpacity(0.1)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(date.day.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                              // Show religious calendar dates
                              if (religiousDates.isNotEmpty)
                                ...religiousDates.map((rd) => Text(
                                  rd,
                                  style: const TextStyle(fontSize: 7, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )),
                              const Spacer(),
                              if (dayHolidays.isNotEmpty)
                                const Icon(Icons.star, color: Colors.red, size: 10),
                              if (dayLocations.isNotEmpty)
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  children: dayLocations.take(3).map((l) {
                                    final user = _allUsers.firstWhere((u) => u['uid'] == l.userId, orElse: () => {});
                                    final name = user['displayName'] ?? user['email'] ?? "User";
                                    final photoUrl = user['photoURL'];
                                    return Padding(
                                      padding: const EdgeInsets.all(1.0),
                                      child: CircleAvatar(
                                        radius: 6,
                                        backgroundColor: Colors.grey[200],
                                        child: ClipOval(
                                          child: Image.network(
                                            photoUrl != null && photoUrl.isNotEmpty ? photoUrl : "https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&size=24",
                                            width: 12,
                                            height: 12,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Image.network(
                                                "https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&size=24",
                                                width: 12,
                                                height: 12,
                                                fit: BoxFit.cover,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              const SizedBox(height: 2),
                            ],
                          ),
                        );
                      },
                      onTap: (details) {
                        if (details.date != null && _user != null) {
                          final date = details.date!;
                          final dayLocations = _getLocationsForDate(date);
                          final dayHolidays = _holidays.where((h) => 
                            h.date.year == date.year && h.date.month == date.month && h.date.day == date.day).toList();
                          final dayEvents = _events.where((e) => 
                            e.date.year == date.year && e.date.month == date.month && e.date.day == date.day).toList();

                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) => DetailModal(
                              date: date,
                              locations: dayLocations,
                              events: dayEvents,
                              holidays: dayHolidays,
                              currentUserId: _user!.uid,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 80), // Space for FAB
              ],
            ),
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
