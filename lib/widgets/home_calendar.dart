import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models.dart';
import '../religious_calendar_helper.dart';
import '../detail_modal.dart';

class HomeCalendar extends StatefulWidget {
  final CalendarController controller;
  final List<UserLocation> locations;
  final List<GroupEvent> events;
  final List<Holiday> holidays;
  final List<Map<String, dynamic>> allUsers;
  final String tileCalendarDisplay;
  final List<String> religiousCalendars;
  final Function(String, DateTime) onMonthChanged;
  final String currentUserId;
  final DateTime currentViewMonth;

  const HomeCalendar({
    super.key,
    required this.controller,
    required this.locations,
    required this.events,
    required this.holidays,
    required this.allUsers,
    required this.tileCalendarDisplay,
    required this.religiousCalendars,
    required this.onMonthChanged,
    required this.currentUserId,
    required this.currentViewMonth,
  });

  @override
  State<HomeCalendar> createState() => _HomeCalendarState();
}

class _HomeCalendarState extends State<HomeCalendar> {


  // Helper to get effective locations for a date (includes ALL users for detail modal)
  List<UserLocation> _getLocationsForDate(DateTime date) {
    // 1. Get explicit locations (manually set for this date)
    final explicit = widget.locations.where((l) => 
      l.date.year == date.year && l.date.month == date.month && l.date.day == date.day).toList();
    
    final explicitUserIds = explicit.map((l) => l.userId).toSet();

    // 2. Add locations for all other users (default location or "No location")
    final others = <UserLocation>[];
    for (final user in widget.allUsers) {
      if (!explicitUserIds.contains(user['uid'])) {
        final defaultLoc = user['defaultLocation'] as String?;
        // Use user's groupId if available (for placeholders), otherwise 'global'
        final userGroupId = user['groupId'] as String? ?? 'global';
        
        if (defaultLoc != null && defaultLoc.isNotEmpty) {
          // Has default location
          final parts = defaultLoc.split(', ');
          final country = parts[0];
          final state = parts.length > 1 ? parts[1] : null;
          
          others.add(UserLocation(
            userId: user['uid'],
            groupId: userGroupId,
            date: date,
            nation: country,
            state: state,
          ));
        } else {
          // No location - add placeholder entry for detail modal
          others.add(UserLocation(
            userId: user['uid'],
            groupId: userGroupId,
            date: date,
            nation: "No location selected",
            state: null,
          ));
        }
      }
    }

    return [...explicit, ...others];
  }


  // Helper to get users with explicit location entries (for avatar display)
  // Deduplicated by userId - each user appears only once
  List<UserLocation> _getTravelersForDate(DateTime date) {
    final locationsForDate = widget.locations.where((l) => 
      l.date.year == date.year && l.date.month == date.month && l.date.day == date.day).toList();
    
    // Deduplicate by userId - keep only the first occurrence per user
    final Map<String, UserLocation> uniqueUsers = {};
    for (final loc in locationsForDate) {
      if (!uniqueUsers.containsKey(loc.userId)) {
        uniqueUsers[loc.userId] = loc;
      }
    }
    
    return uniqueUsers.values.toList();
  }

  // Helper to get birthdays for a date (both solar and lunar)
  List<Birthday> _getBirthdaysForDate(DateTime date) {
    final birthdays = <Birthday>[];
    
    for (final user in widget.allUsers) {
      // Get solar birthday
      final solarBirthday = Birthday.getSolarBirthday(user, date.year);
      if (solarBirthday != null) {
        // Check if solar birthday matches this date
        if (solarBirthday.occurrenceDate.month == date.month && 
            solarBirthday.occurrenceDate.day == date.day) {
          birthdays.add(solarBirthday);
        }
      }
      
      // Get lunar birthday (separate from solar)
      final lunarBirthday = Birthday.getLunarBirthday(user, date.year, date);
      if (lunarBirthday != null) {
        birthdays.add(lunarBirthday);
      }
    }
    
    return birthdays;
  }


  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: SfCalendar(
        controller: widget.controller,
        view: CalendarView.month,
        headerHeight: 0,
        monthViewSettings: const MonthViewSettings(
          appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
          showAgenda: false,
        ),
        onViewChanged: (ViewChangedDetails details) {
          if (details.visibleDates.isNotEmpty) {
            final midDate = details.visibleDates[details.visibleDates.length ~/ 2];
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                widget.onMonthChanged(DateFormat('MMMM yyyy').format(midDate), midDate);
              }
            });
          }
        },
        monthCellBuilder: (context, details) {
          final date = details.date;
          final isToday = date.year == DateTime.now().year && 
                         date.month == DateTime.now().month && 
                         date.day == DateTime.now().day;
          final isCurrentMonth = date.month == widget.currentViewMonth.month;
          
          // ignore: unused_local_variable - needed for onTap handler below
          final dayLocations = _getLocationsForDate(date);  // For detail modal
          final dayTravelers = _getTravelersForDate(date);  // For avatar display
          final dayHolidays = widget.holidays.where((h) => 
            h.date.year == date.year && h.date.month == date.month && h.date.day == date.day).toList();
          final dayEvents = widget.events.where((e) => 
            e.date.year == date.year && e.date.month == date.month && e.date.day == date.day).toList();
          final dayBirthdays = _getBirthdaysForDate(date);  // Get birthdays for this date
          
          // Get religious calendar dates for this day
          final religiousDates = ReligiousCalendarHelper.getReligiousDates(
            date, 
            widget.tileCalendarDisplay == 'none' ? [] : [widget.tileCalendarDisplay]
          );
          
          // Items to display as bars (Holidays, Events & Birthdays)
          final allItems = <dynamic>[...dayHolidays, ...dayEvents, ...dayBirthdays];
          final maxBars = 2;
          final displayItems = allItems.take(maxBars).toList();
          final remainingCount = allItems.length - maxBars;

          return Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
              color: isToday 
                ? Colors.deepPurple.withOpacity(0.2) 
                : (isCurrentMonth ? null : Colors.grey[50]),
            ),
            child: Padding(
              padding: const EdgeInsets.all(1.0), // Reduced padding for overflow fix
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(date.day.toString(), 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 14,
                          color: isToday 
                            ? Colors.deepPurple 
                            : (isCurrentMonth ? Colors.black87 : Colors.grey)
                        )),
                      if (religiousDates.isNotEmpty)
                        Expanded(
                          child: Text(
                            religiousDates.join(' '),
                            style: TextStyle(
                              fontSize: 9, 
                              color: isCurrentMonth ? Colors.black54 : Colors.grey, 
                              fontWeight: FontWeight.w500
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 1), // Reduced spacing
                  // Display Bars
                  ...displayItems.map((item) {
                    String title = "";
                    Color color = Colors.blue;
                    if (item is Holiday) {
                      title = item.localName;
                      color = Colors.red.withOpacity(0.7);
                    } else if (item is GroupEvent) {
                      title = item.title;
                      color = Colors.blue.withOpacity(0.7);
                    } else if (item is Birthday) {
                      // Format: "Name - Ageth" for solar, "[农历] Name" for lunar
                      if (item.isLunar) {
                        title = "${item.displayName} [lunar birthday]"; // Lunar birthday - no age
                      } else {
                        final ageSuffix = _getAgeSuffix(item.age);
                        title = "${item.displayName} - ${item.age}$ageSuffix";
                      }
                      color = Colors.green.withOpacity(0.7);
                    }
                    
                    // Dim bars for non-current month
                    if (!isCurrentMonth) {
                      color = color.withOpacity(0.3);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 0.5), // Reduced margin
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      width: double.infinity,
                      child: Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 7.5), // Reduced font size
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                  if (remainingCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Text(
                        "+$remainingCount more",
                        style: TextStyle(
                          fontSize: 7, // Reduced font size
                          color: isCurrentMonth ? Colors.grey : Colors.grey[300], 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  
                  const Spacer(),
                  // Avatars - show for users with explicit location entries
                  if (dayTravelers.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        ...dayTravelers.take(8).map((l) {
                          final user = widget.allUsers.firstWhere((u) => u['uid'] == l.userId, orElse: () => {});
                          final name = user['displayName'] ?? user['email'] ?? "User";
                          final photoUrl = user['photoURL'];
                          
                          // Dynamic sizing based on count
                          final count = dayTravelers.length;
                          final double avatarSize = count <= 8 
                            ? 20.0  // Reduced from 24.0 to prevent overflow
                            : count <= 12 
                              ? 15.0  // Slightly smaller for medium groups
                              : 13.0; // Small for very large groups
                          
                          // Use imageUrl: either photoUrl or fallback
                          final imageUrl = (photoUrl != null && photoUrl is String && photoUrl.isNotEmpty) 
                            ? photoUrl 
                            : "https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&size=${(avatarSize * 3).toInt()}";
                          
                          // Debug logging for avatar loading
                          print('[Avatar] Loading for user: $name (${l.userId})');
                          print('[Avatar] URL: $imageUrl');
                          
                          return Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: Opacity(
                              opacity: isCurrentMonth ? 1.0 : 0.5,
                              child: ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  width: avatarSize,
                                  height: avatarSize,
                                  fit: BoxFit.cover,
                                  httpHeaders: const {
                                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                                    'Referer': 'https://google.com',
                                  },
                                  placeholder: (context, url) {
                                    print('[Avatar] Loading placeholder for: $name');
                                    return Container(
                                      width: avatarSize,
                                      height: avatarSize,
                                      color: Colors.grey[200],
                                    );
                                  },
                                  errorWidget: (context, url, error) {
                                    print('[Avatar] Error loading for $name: $error');
                                    print('[Avatar] Failed URL: $url');
                                    // Tier 2: If primary image fails, try ui-avatars
                                    return Image.network(
                                      "https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&size=${(avatarSize * 3).toInt()}",
                                      width: avatarSize,
                                      height: avatarSize,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        // Tier 3: Ultimate fallback - person icon
                                        return Container(
                                          width: avatarSize,
                                          height: avatarSize,
                                          color: Colors.grey[300],
                                          child: Icon(Icons.person, size: avatarSize * 0.6, color: Colors.grey[600]),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        // Show +N more indicator if there are more than 8
                        if (dayTravelers.length > 8)
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.grey[700],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '+${dayTravelers.length - 8}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 7,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
        onTap: (CalendarTapDetails details) {
          if (details.targetElement == CalendarElement.calendarCell && details.date != null) {
            final date = details.date!;
            final dayLocations = _getLocationsForDate(date);
            final dayHolidays = widget.holidays.where((h) => 
              h.date.year == date.year && h.date.month == date.month && h.date.day == date.day).toList();
            final dayEvents = widget.events.where((e) => 
              e.date.year == date.year && e.date.month == date.month && e.date.day == date.day).toList();
            final dayBirthdays = _getBirthdaysForDate(date);

            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) => DetailModal(
                date: date,
                locations: dayLocations,
                events: dayEvents,
                holidays: dayHolidays,
                birthdays: dayBirthdays,
                currentUserId: widget.currentUserId,
              ),
            );
          }
        },
      ),
    );
  }

  String _getAgeSuffix(int age) {
    if (age % 100 >= 11 && age % 100 <= 13) {
      return 'th';
    }
    switch (age % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
