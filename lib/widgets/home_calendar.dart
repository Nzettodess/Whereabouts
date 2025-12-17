import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models.dart';
import '../models/placeholder_member.dart';
import '../religious_calendar_helper.dart';
import '../detail_modal.dart';

class HomeCalendar extends StatefulWidget {
  final CalendarController controller;
  final List<UserLocation> locations;
  final List<GroupEvent> events;
  final List<Holiday> holidays;
  final List<Map<String, dynamic>> allUsers;
  final List<PlaceholderMember> placeholderMembers;
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
    required this.placeholderMembers,
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
  // === PERFORMANCE OPTIMIZATION: Cached data for O(1) lookups ===
  // Instead of computing data for all 42 cells on every rebuild,
  // we pre-compute once when month changes and store in maps
  // GRANULAR CACHING: Each cache is updated only when its source data changes
  // PRELOADING: Cache includes prev/current/next months for seamless swipe
  Map<String, List<UserLocation>> _cachedLocations = {};
  Map<String, List<UserLocation>> _cachedTravelers = {};
  Map<String, List<GroupEvent>> _cachedEvents = {};
  Map<String, List<Holiday>> _cachedHolidays = {};
  Map<String, List<Birthday>> _cachedBirthdays = {};
  Map<String, List<String>> _cachedReligiousDates = {};
  DateTime? _lastCachedMonth;
  List<DateTime>? _visibleDates; // Cache visible dates for current month
  Set<String> _preloadedMonths = {}; // Track which months are preloaded


  @override
  void didUpdateWidget(HomeCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if month changed - need full recache
    final monthChanged = oldWidget.currentViewMonth.month != widget.currentViewMonth.month ||
        oldWidget.currentViewMonth.year != widget.currentViewMonth.year;
    
    if (monthChanged) {
      _lastCachedMonth = null;
      _visibleDates = null;
      _precomputeMonthData(widget.currentViewMonth);
      return;
    }
    
    // GRANULAR CACHE UPDATES - only update what changed
    _visibleDates ??= _getVisibleDatesForMonth(widget.currentViewMonth);
    
    // Locations or users changed -> update locations/travelers/birthdays caches only
    if (oldWidget.locations != widget.locations || 
        oldWidget.allUsers != widget.allUsers ||
        oldWidget.placeholderMembers != widget.placeholderMembers) {
      _updateLocationsCacheOnly();
    }
    
    // Events changed -> update events cache only
    if (oldWidget.events != widget.events) {
      _updateEventsCacheOnly();
    }
    
    // Holidays changed -> update holidays cache only
    if (oldWidget.holidays != widget.holidays) {
      _updateHolidaysCacheOnly();
    }
    
    // Calendar display setting changed -> update religious dates cache only
    if (oldWidget.tileCalendarDisplay != widget.tileCalendarDisplay) {
      _updateReligiousDatesCacheOnly();
    }
  }

  @override
  void initState() {
    super.initState();
    // Initial precompute
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precomputeMonthData(widget.currentViewMonth);
    });
  }

  /// Force refresh the cache - call this after settings changes
  void forceRefresh() {
    _lastCachedMonth = null;
    _visibleDates = null;
    _preloadedMonths.clear();  // Clear preload tracking to reload all
    _cachedLocations.clear();
    _cachedTravelers.clear();
    _cachedEvents.clear();
    _cachedHolidays.clear();
    _cachedBirthdays.clear();
    _cachedReligiousDates.clear();
    _precomputeMonthData(widget.currentViewMonth);
  }

  // === GRANULAR CACHE UPDATE METHODS ===
  
  void _updateLocationsCacheOnly() {
    final dates = _visibleDates ?? _getVisibleDatesForMonth(widget.currentViewMonth);
    for (final date in dates) {
      final key = _dateKey(date);
      _cachedLocations[key] = _computeLocationsForDate(date);
      _cachedTravelers[key] = _computeTravelersForDate(date);
      _cachedBirthdays[key] = _computeBirthdaysForDate(date);
    }
    if (mounted) setState(() {});
  }
  
  void _updateEventsCacheOnly() {
    final dates = _visibleDates ?? _getVisibleDatesForMonth(widget.currentViewMonth);
    for (final date in dates) {
      final key = _dateKey(date);
      _cachedEvents[key] = widget.events.where((e) => 
        e.date.year == date.year && e.date.month == date.month && e.date.day == date.day).toList();
    }
    if (mounted) setState(() {});
  }
  
  void _updateHolidaysCacheOnly() {
    final dates = _visibleDates ?? _getVisibleDatesForMonth(widget.currentViewMonth);
    for (final date in dates) {
      final key = _dateKey(date);
      _cachedHolidays[key] = widget.holidays.where((h) => 
        h.date.year == date.year && h.date.month == date.month && h.date.day == date.day).toList();
    }
    if (mounted) setState(() {});
  }
  
  void _updateReligiousDatesCacheOnly() {
    final dates = _visibleDates ?? _getVisibleDatesForMonth(widget.currentViewMonth);
    for (final date in dates) {
      final key = _dateKey(date);
      _cachedReligiousDates[key] = widget.tileCalendarDisplay == 'none' 
        ? [] 
        : ReligiousCalendarHelper.getReligiousDates(date, [widget.tileCalendarDisplay]);
    }
    if (mounted) setState(() {});
  }

  /// Pre-compute all data for the visible month (42 dates)
  /// This runs ONCE when month changes, not 42 times per frame
  void _precomputeMonthData(DateTime month) {
    final monthKey = '${month.year}-${month.month}';
    
    // Check if this month is already fully cached
    if (_preloadedMonths.contains(monthKey) && 
        _lastCachedMonth?.year == month.year && 
        _lastCachedMonth?.month == month.month) {
      return; // Already cached for this month
    }
    
    _lastCachedMonth = month;
    
    // DON'T clear all caches - keep preloaded adjacent months!
    // Only compute for this month if not already preloaded
    _visibleDates = _getVisibleDatesForMonth(month);
    
    for (final date in _visibleDates!) {
      final key = _dateKey(date);
      
      // Only compute if not already cached
      if (!_cachedLocations.containsKey(key)) {
        _cachedLocations[key] = _computeLocationsForDate(date);
        _cachedTravelers[key] = _computeTravelersForDate(date);
        _cachedEvents[key] = widget.events.where((e) => 
          e.date.year == date.year && e.date.month == date.month && e.date.day == date.day).toList();
        _cachedHolidays[key] = widget.holidays.where((h) => 
          h.date.year == date.year && h.date.month == date.month && h.date.day == date.day).toList();
        _cachedBirthdays[key] = _computeBirthdaysForDate(date);
        _cachedReligiousDates[key] = widget.tileCalendarDisplay == 'none' 
          ? [] 
          : ReligiousCalendarHelper.getReligiousDates(date, [widget.tileCalendarDisplay]);
      }
    }
    
    _preloadedMonths.add(monthKey);
    
    // PRELOAD ADJACENT MONTHS (async, after current month is displayed)
    // This makes swipe transitions seamless!
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _preloadAdjacentMonths(month);
    });
    
    if (mounted) setState(() {});
  }

  /// Preload previous and next month data for seamless swipe
  void _preloadAdjacentMonths(DateTime currentMonth) {
    final prevMonth = DateTime(currentMonth.year, currentMonth.month - 1, 1);
    final nextMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    
    _preloadMonthIfNeeded(prevMonth);
    _preloadMonthIfNeeded(nextMonth);
    
    // Clean up old months to save memory (keep only 3 months cached)
    _cleanupOldMonths(currentMonth);
  }
  
  /// Preload a single month's data if not already cached
  void _preloadMonthIfNeeded(DateTime month) {
    final monthKey = '${month.year}-${month.month}';
    if (_preloadedMonths.contains(monthKey)) return;
    
    final dates = _getVisibleDatesForMonth(month);
    for (final date in dates) {
      final key = _dateKey(date);
      if (!_cachedLocations.containsKey(key)) {
        _cachedLocations[key] = _computeLocationsForDate(date);
        _cachedTravelers[key] = _computeTravelersForDate(date);
        _cachedEvents[key] = widget.events.where((e) => 
          e.date.year == date.year && e.date.month == date.month && e.date.day == date.day).toList();
        _cachedHolidays[key] = widget.holidays.where((h) => 
          h.date.year == date.year && h.date.month == date.month && h.date.day == date.day).toList();
        _cachedBirthdays[key] = _computeBirthdaysForDate(date);
        _cachedReligiousDates[key] = widget.tileCalendarDisplay == 'none' 
          ? [] 
          : ReligiousCalendarHelper.getReligiousDates(date, [widget.tileCalendarDisplay]);
      }
    }
    _preloadedMonths.add(monthKey);
  }
  
  /// Remove old month caches to save memory
  void _cleanupOldMonths(DateTime currentMonth) {
    final keepMonths = <String>{
      '${currentMonth.year}-${currentMonth.month}',
      '${DateTime(currentMonth.year, currentMonth.month - 1, 1).year}-${DateTime(currentMonth.year, currentMonth.month - 1, 1).month}',
      '${DateTime(currentMonth.year, currentMonth.month + 1, 1).year}-${DateTime(currentMonth.year, currentMonth.month + 1, 1).month}',
    };
    
    // Remove months that are no longer adjacent
    _preloadedMonths.removeWhere((m) => !keepMonths.contains(m));
  }

  /// Get the 42 visible dates for a month view
  List<DateTime> _getVisibleDatesForMonth(DateTime month) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final startWeekday = firstOfMonth.weekday % 7; // Sunday = 0
    final startDate = firstOfMonth.subtract(Duration(days: startWeekday));
    
    return List.generate(42, (i) => startDate.add(Duration(days: i)));
  }

  String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

  // Compute effective locations for a date (includes ALL users for detail modal)
  // Used by _precomputeMonthData - NOT called in monthCellBuilder
  List<UserLocation> _computeLocationsForDate(DateTime date) {
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
    
    // 3. Add placeholder members (with their default locations)
    for (final placeholder in widget.placeholderMembers) {
      if (!explicitUserIds.contains(placeholder.id)) {
        final defaultLoc = placeholder.defaultLocation;
        
        if (defaultLoc != null && defaultLoc.isNotEmpty) {
          // Has default location
          final parts = defaultLoc.split(', ');
          final country = parts[0];
          final state = parts.length > 1 ? parts[1] : null;
          
          others.add(UserLocation(
            userId: placeholder.id,
            groupId: placeholder.groupId,
            date: date,
            nation: country,
            state: state,
          ));
        } else {
          // No location - add placeholder entry for detail modal
          others.add(UserLocation(
            userId: placeholder.id,
            groupId: placeholder.groupId,
            date: date,
            nation: "No location selected",
            state: null,
          ));
        }
      }
    }

    return [...explicit, ...others];
  }


  // Compute users with explicit location entries (for avatar display)
  // Deduplicated by userId - each user appears only once
  // Used by _precomputeMonthData - NOT called in monthCellBuilder
  List<UserLocation> _computeTravelersForDate(DateTime date) {
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

  // Compute birthdays for a date (both solar and lunar)
  // Used by _precomputeMonthData - NOT called in monthCellBuilder
  List<Birthday> _computeBirthdaysForDate(DateTime date) {
    final birthdays = <Birthday>[];
    
    // Regular users
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
    
    // Placeholder members
    for (final placeholder in widget.placeholderMembers) {
      // Solar birthday
      final solarBirthday = Birthday.fromPlaceholderMember(placeholder, date.year);
      if (solarBirthday != null) {
        if (solarBirthday.occurrenceDate.month == date.month && 
            solarBirthday.occurrenceDate.day == date.day) {
          birthdays.add(solarBirthday);
        }
      }
      
      // Lunar birthday
      if (placeholder.hasLunarBirthday && 
          placeholder.lunarBirthdayMonth != null && 
          placeholder.lunarBirthdayDay != null) {
        final lunarBirthday = Birthday.fromPlaceholderLunar(placeholder, date.year, date);
        if (lunarBirthday != null) {
          birthdays.add(lunarBirthday);
        }
      }
    }
    
    return birthdays;
  }

  /// Get responsive sizes based on screen width
  /// Mobile (<500): smaller fonts, tighter spacing, hide lunar month
  /// Tablet (500-800): medium sizing
  /// Desktop (>800): original sizing
  _ResponsiveSizes _getResponsiveSizes(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < 500) {
      // Mobile - compact sizing, hide lunar month text
      // iPhone 14 Pro Max is 430px, so use 500px breakpoint
      return _ResponsiveSizes(
        cardMargin: 8.0,
        dayFontSize: 12.0,
        religiousFontSize: 7.0,
        barFontSize: 6.5,
        moreFontSize: 6.0,
        avatarSize: 16.0,
        avatarSizeMedium: 13.0,
        avatarSizeSmall: 11.0,
        cellPadding: 0.5,
        maxAvatars: 3,  // Fewer avatars on mobile
        showLunarMonth: false,  // Hide month like 十月, only show day
        maxBars: 6,  // More rows since mobile screens are tall
      );
    } else if (width < 800) {
      // Tablet (500-800px) - medium sizing
      return _ResponsiveSizes(
        cardMargin: 12.0,
        dayFontSize: 13.0,
        religiousFontSize: 8.0,
        barFontSize: 7.0,
        moreFontSize: 6.5,
        avatarSize: 18.0,
        avatarSizeMedium: 14.0,
        avatarSizeSmall: 12.0,
        cellPadding: 0.75,
        maxAvatars: 6,
        showLunarMonth: true,  // Show lunar month on tablet
        maxBars: 2,  // Medium event bars
      );
    } else {
      // Desktop - original sizing
      return _ResponsiveSizes(
        cardMargin: 20.0,
        dayFontSize: 14.0,
        religiousFontSize: 9.0,
        barFontSize: 7.5,
        moreFontSize: 7.0,
        avatarSize: 20.0,
        avatarSizeMedium: 15.0,
        avatarSizeSmall: 13.0,
        cellPadding: 1.0,
        maxAvatars: 8,
        showLunarMonth: true,  // Show lunar month on desktop
        maxBars: 3,  // More event bars on large screens
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizes = _getResponsiveSizes(context);
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: sizes.cardMargin),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      // Use LayoutBuilder ONCE here instead of 42 times inside each cell
      // This dramatically improves swipe performance
      child: LayoutBuilder(
        builder: (context, calendarConstraints) {
          // Pre-calculate maxBars once based on calendar height
          // Each cell is roughly calendarHeight / 6 rows
          final estimatedCellHeight = calendarConstraints.maxHeight / 6;
          final reservedHeight = sizes.dayFontSize + 8 + sizes.avatarSize + 12;
          final availableHeight = estimatedCellHeight - reservedHeight;
          final barHeight = sizes.barFontSize + 5;
          final dynamicMaxBars = (availableHeight / barHeight).floor().clamp(1, 10);
          
          return SfCalendar(
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
          
          // === PERFORMANCE: O(1) cached lookups instead of O(n) computations ===
          final key = _dateKey(date);
          final dayLocations = _cachedLocations[key] ?? [];  // For detail modal
          final dayTravelers = _cachedTravelers[key] ?? [];  // For avatar display
          final dayHolidays = _cachedHolidays[key] ?? [];
          final dayEvents = _cachedEvents[key] ?? [];
          final dayBirthdays = _cachedBirthdays[key] ?? [];
          final religiousDates = _cachedReligiousDates[key] ?? [];
          
          // Filter religious dates on narrow screens - hide month like 十月, only show day number
          // Note: 🏮 lantern is already added by ReligiousCalendarHelper
          final filteredReligiousDates = sizes.showLunarMonth 
            ? religiousDates  // Keep full date with lantern from helper
            : religiousDates.map((d) {
                // Extract only the day portion (remove month like 十月, 腊月)
                // Format from helper is "🏮 十月十二" - we want just "🏮十二"
                if (d.contains('月')) {
                  final parts = d.split('月');
                  // Keep the lantern prefix, just remove month
                  final prefix = d.startsWith('🏮') ? '🏮' : '';
                  return parts.length > 1 ? '$prefix${parts[1]}' : d;
                }
                return d;
              }).toList();
          
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;
          
          // Items to display as bars (Holidays, Events & Birthdays)
          // Using pre-calculated dynamicMaxBars from parent LayoutBuilder for performance
          final allItems = <dynamic>[...dayHolidays, ...dayEvents, ...dayBirthdays];
          final displayItems = allItems.take(dynamicMaxBars).toList();
          final remainingCount = (allItems.length - dynamicMaxBars).clamp(0, 99);

          // RepaintBoundary isolates this cell's painting from others
          // AnimatedContainer smoothly transitions colors during month swipe
          return RepaintBoundary(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                border: Border.all(color: isDarkMode ? Colors.white10 : Colors.grey.withOpacity(0.1)),
                color: isToday 
                  ? Theme.of(context).colorScheme.primary.withOpacity(isDarkMode ? 0.35 : 0.2)
                  : (isCurrentMonth 
                      ? Theme.of(context).colorScheme.surface 
                      : (isDarkMode ? Colors.grey.shade900 : Colors.grey[50])),
            ),
            child: Padding(
              padding: EdgeInsets.all(sizes.cellPadding),
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
                          fontSize: sizes.dayFontSize,
                          color: isToday 
                            ? Theme.of(context).colorScheme.primary 
                            : (isCurrentMonth 
                                ? Theme.of(context).colorScheme.onSurface 
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.4))
                        )),
                      if (filteredReligiousDates.isNotEmpty)
                        Expanded(
                          child: Text(
                            filteredReligiousDates.join(' '),
                            style: TextStyle(
                              fontSize: sizes.religiousFontSize, 
                              color: isCurrentMonth 
                                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.3), 
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
                        style: TextStyle(color: Colors.white, fontSize: sizes.barFontSize),
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
                          fontSize: sizes.moreFontSize,
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
                        ...dayTravelers.take(sizes.maxAvatars).map((l) {
                          final user = widget.allUsers.firstWhere((u) => u['uid'] == l.userId, orElse: () => {});
                          final name = user['displayName'] ?? user['email'] ?? "User";
                          final photoUrl = user['photoURL'];
                          
                          // Dynamic sizing based on count - using responsive base sizes
                          final count = dayTravelers.length;
                          final double avatarSize = count <= sizes.maxAvatars 
                            ? sizes.avatarSize
                            : count <= 12 
                              ? sizes.avatarSizeMedium
                              : sizes.avatarSizeSmall;
                          
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
                        // Show +N more indicator if there are more than maxAvatars
                        if (dayTravelers.length > sizes.maxAvatars)
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.grey[700],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '+${dayTravelers.length - sizes.maxAvatars}',
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
          ),
          );  // Close RepaintBoundary
        },
        onTap: (CalendarTapDetails details) {
          if (details.targetElement == CalendarElement.calendarCell && details.date != null) {
            final date = details.date!;
            // Use cached data for onTap as well
            final key = _dateKey(date);
            final dayLocations = _cachedLocations[key] ?? _computeLocationsForDate(date);
            final dayHolidays = _cachedHolidays[key] ?? [];
            final dayEvents = _cachedEvents[key] ?? [];
            final dayBirthdays = _cachedBirthdays[key] ?? _computeBirthdaysForDate(date);

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
      );  // Close SfCalendar
    },  // Close LayoutBuilder builder
      ),  // Close LayoutBuilder
    );  // Close Card
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

/// Helper class for responsive sizing
class _ResponsiveSizes {
  final double cardMargin;
  final double dayFontSize;
  final double religiousFontSize;
  final double barFontSize;
  final double moreFontSize;
  final double avatarSize;
  final double avatarSizeMedium;
  final double avatarSizeSmall;
  final double cellPadding;
  final int maxAvatars;
  final bool showLunarMonth;  // Hide month text like 十月 on narrow screens
  final int maxBars;  // Dynamic event bar count based on cell height

  const _ResponsiveSizes({
    required this.cardMargin,
    required this.dayFontSize,
    required this.religiousFontSize,
    required this.barFontSize,
    required this.moreFontSize,
    required this.avatarSize,
    required this.avatarSizeMedium,
    required this.avatarSizeSmall,
    required this.cellPadding,
    required this.maxAvatars,
    required this.showLunarMonth,
    required this.maxBars,
  });
}
