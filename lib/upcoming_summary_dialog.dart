import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:grouped_list/grouped_list.dart';
import 'models.dart';
import 'models/upcoming_item.dart';
import 'models/placeholder_member.dart';
import 'add_event_modal.dart';
import 'widgets/rich_description_viewer.dart';
import 'widgets/event_detail_dialog.dart';

/// Dialog showing upcoming events, location changes, and birthdays
/// grouped by date. Only dates with items are displayed.
class UpcomingSummaryDialog extends StatefulWidget {
  final String currentUserId;
  final List<GroupEvent> events;
  final List<UserLocation> locations;
  final List<Holiday> holidays;
  final List<Map<String, dynamic>> allUsers;
  final List<PlaceholderMember> placeholderMembers;
  final Map<String, String> groupNames; // groupId -> groupName
  final void Function(DateTime date)? onDateTap; // Callback for opening date detail
  final bool canWrite; // Whether write operations are allowed (false if session terminated)

  const UpcomingSummaryDialog({
    super.key,
    required this.currentUserId,
    required this.events,
    required this.locations,
    required this.holidays,
    required this.allUsers,
    required this.placeholderMembers,
    required this.groupNames,
    this.onDateTap,
    this.canWrite = true, // Default to true for backwards compatibility
  });

  @override
  State<UpcomingSummaryDialog> createState() => _UpcomingSummaryDialogState();
}

class _UpcomingSummaryDialogState extends State<UpcomingSummaryDialog> {
  // Filter state
  UpcomingItemType? _selectedFilter; // null means "All"
  
  /// Check if writes are allowed, show dialog if not
  bool _checkCanWrite() {
    if (!widget.canWrite) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(children: [
            Icon(Icons.block, color: Colors.red[700], size: 22),
            const SizedBox(width: 8),
            const Text('Read-Only Mode'),
          ]),
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
    return true;
  }
  
  // Infinite scroll state
  int _daysToShow = 60; // Start with 60 days
  static const int _daysIncrement = 60; // Load 60 more days at a time
  static const int _maxDays = 365; // Max 1 year
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      // Near bottom, load more
      if (_daysToShow < _maxDays) {
        setState(() {
          _daysToShow = (_daysToShow + _daysIncrement).clamp(0, _maxDays);
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final upcomingItems = _buildUpcomingItems();
    final filteredItems = _selectedFilter == null
        ? upcomingItems
        : upcomingItems.where((item) {
            // Special case: Birthdays filter includes both regular and lunar birthdays
            if (_selectedFilter == UpcomingItemType.birthday) {
              return item.type == UpcomingItemType.birthday || 
                     item.type == UpcomingItemType.lunarBirthday;
            }
            return item.type == _selectedFilter;
          }).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 450;
    final isVeryNarrow = screenWidth < 400;
    
    // Use 90% of screen width on mobile, capped at 500 for larger screens
    final dialogWidth = isNarrow ? screenWidth * 0.90 : 500.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: isNarrow ? const EdgeInsets.symmetric(horizontal: 10, vertical: 24) : null,
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header - simple style like Groups dialog with more spacing
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 12 : 20,
                vertical: isNarrow ? 12 : 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event_note, 
                        color: Theme.of(context).colorScheme.onSurface,
                        size: isNarrow ? 18 : 22,
                      ),
                      SizedBox(width: isNarrow ? 6 : 8),
                      Text(
                        "Upcoming",
                        style: TextStyle(
                          fontSize: isNarrow ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    iconSize: isNarrow ? 20 : 24,
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: isNarrow ? 32 : 48,
                      minHeight: isNarrow ? 32 : 48,
                    ),
                  ),
                ],
              ),
            ),
            
            // Filter chips - compact on mobile
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isVeryNarrow ? 4 : (isNarrow ? 8 : 16),
                vertical: isVeryNarrow ? 2 : (isNarrow ? 4 : 8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(null, 'All', Icons.list, isVeryNarrow),
                    SizedBox(width: isVeryNarrow ? 4 : 6),
                    _buildFilterChip(UpcomingItemType.event, 'Events', Icons.celebration, isVeryNarrow),
                    SizedBox(width: isVeryNarrow ? 4 : 6),
                    _buildFilterChip(UpcomingItemType.locationChange, 'Locations', Icons.location_on, isVeryNarrow),
                    SizedBox(width: isVeryNarrow ? 4 : 6),
                    _buildFilterChip(UpcomingItemType.birthday, 'Birthdays', Icons.cake, isVeryNarrow),
                    SizedBox(width: isVeryNarrow ? 4 : 6),
                    _buildFilterChip(UpcomingItemType.holiday, 'Holidays', Icons.flag, isVeryNarrow),
                    SizedBox(width: isVeryNarrow ? 4 : 8),
                  ],
                ),
              ),
            ),
            
            const Divider(height: 1),
            
            // Content with rounded bottom
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                child: filteredItems.isEmpty
                    ? _buildEmptyState()
                    : Column(
                        children: [
                          Expanded(
                            child: GroupedListView<UpcomingItem, String>(
                              controller: _scrollController,
                              elements: filteredItems,
                              groupBy: (item) => _formatDateKey(item.date),
                              groupSeparatorBuilder: (String groupKey) =>
                                  _buildDateHeader(groupKey, filteredItems),
                              itemBuilder: (context, UpcomingItem item) =>
                                  _buildItemCard(item),
                              itemComparator: (a, b) => a.date.compareTo(b.date),
                              order: GroupedListOrder.ASC,
                              useStickyGroupSeparators: true,
                              floatingHeader: true,
                              padding: const EdgeInsets.only(bottom: 8),
                            ),
                          ),
                          // Load More button
                          if (_daysToShow < _maxDays)
                            Builder(builder: (context) {
                              final screenWidth = MediaQuery.of(context).size.width;
                              final isNarrow = screenWidth < 450;
                              final isVeryNarrow = screenWidth < 390;
                              return Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: isVeryNarrow ? 8 : 16,
                                  horizontal: isVeryNarrow ? 12 : 24,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _daysToShow = _daysToShow + _daysIncrement;
                                        if (_daysToShow > _maxDays) _daysToShow = _maxDays;
                                      });
                                    },
                                    icon: Icon(Icons.expand_more, size: isVeryNarrow ? 16 : 20),
                                    label: Text(
                                      isNarrow 
                                        ? 'More ($_daysToShow/$_maxDays)'
                                        : 'Load more (showing $_daysToShow of $_maxDays days)',
                                      style: TextStyle(fontSize: isVeryNarrow ? 11 : 14),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(vertical: isVeryNarrow ? 6 : 12),
                                    ),
                                  ),
                                ),
                              );
                            })
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'Showing all $_maxDays days',
                                style: TextStyle(
                                  color: Theme.of(context).hintColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(UpcomingItemType? type, String label, IconData icon, [bool isVeryNarrow = false]) {
    final isSelected = _selectedFilter == type;
    final iconSz = isVeryNarrow ? 14.0 : 16.0;
    return FilterChip(
      label: isSelected 
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: iconSz, color: Colors.white),
                SizedBox(width: isVeryNarrow ? 2 : 4),
                Text(label, style: TextStyle(fontSize: isVeryNarrow ? 11 : 14)),
              ],
            )
          : Icon(icon, size: iconSz, color: Theme.of(context).colorScheme.onSurface),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? type : null;
        });
      },
      selectedColor: Colors.deepPurple,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      side: BorderSide(color: Theme.of(context).dividerColor),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: isVeryNarrow ? 11 : 14,
      ),
      checkmarkColor: Colors.white,
      showCheckmark: false,
      visualDensity: isVeryNarrow ? VisualDensity.compact : null,
      padding: isSelected 
          ? (isVeryNarrow ? const EdgeInsets.symmetric(horizontal: 4) : null)
          : EdgeInsets.symmetric(horizontal: isVeryNarrow ? 2 : 4),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, size: 64, color: Theme.of(context).hintColor),
          const SizedBox(height: 16),
          Text(
            'No upcoming items',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).hintColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Events, location changes, and birthdays\nwill appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).hintColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Widget _buildDateHeader(String groupKey, List<UpcomingItem> items) {
    final date = DateTime.parse(groupKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(date.year, date.month, date.day);
    final itemCount = items.where((i) => _formatDateKey(i.date) == groupKey).length;
    
    String dateLabel;
    if (itemDate == today) {
      dateLabel = 'Today';
    } else if (itemDate == today.add(const Duration(days: 1))) {
      dateLabel = 'Tomorrow';
    } else {
      dateLabel = DateFormat('EEEE').format(date); // Day name
    }
    
    final dateFormatted = DateFormat('MMM d').format(date);
    
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: itemDate == today 
                  ? Colors.deepPurple 
                  : (Theme.of(context).brightness == Brightness.dark 
                      ? Colors.deepPurple.shade800 
                      : Colors.deepPurple.shade100),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              dateFormatted,
              style: TextStyle(
                color: itemDate == today 
                    ? Colors.white 
                    : (Theme.of(context).brightness == Brightness.dark 
                        ? Colors.deepPurple.shade200 
                        : Colors.deepPurple.shade700),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            dateLabel,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(UpcomingItem item) {
    IconData icon;
    Color iconColor;
    Color bgColor;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    switch (item.type) {
      case UpcomingItemType.event:
        icon = Icons.celebration;
        iconColor = isDark ? Colors.orange.shade300 : Colors.orange.shade700;
        bgColor = isDark ? Colors.orange.withOpacity(0.2) : Colors.orange.shade50;
        break;
      case UpcomingItemType.locationChange:
        icon = Icons.location_on;
        iconColor = isDark ? Colors.blue.shade300 : Colors.blue.shade700;
        bgColor = isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50;
        break;
      case UpcomingItemType.birthday:
        icon = Icons.cake;
        iconColor = isDark ? Colors.pink.shade300 : Colors.pink.shade700;
        bgColor = isDark ? Colors.pink.withOpacity(0.2) : Colors.pink.shade50;
        break;
      case UpcomingItemType.lunarBirthday:
        icon = Icons.cake; // Fallback, but emoji is used instead
        iconColor = isDark ? Colors.amber.shade300 : Colors.amber.shade700;
        bgColor = isDark ? Colors.amber.withOpacity(0.2) : Colors.amber.shade50;
        break;
      case UpcomingItemType.holiday:
        icon = Icons.flag;
        iconColor = isDark ? Colors.red.shade300 : Colors.red.shade700;
        bgColor = isDark ? Colors.red.withOpacity(0.2) : Colors.red.shade50;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Builder(
        builder: (context) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isNarrow = screenWidth < 450;
          final isVeryNarrow = screenWidth < 400;
          final iconSize = isVeryNarrow ? 28.0 : (isNarrow ? 32.0 : 40.0);
          
          return Card(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _handleItemTap(item),
              child: Padding(
                padding: EdgeInsets.all(isVeryNarrow ? 6 : (isNarrow ? 8 : 12)),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: item.type == UpcomingItemType.lunarBirthday
                              ? Text('🏮', style: TextStyle(fontSize: isVeryNarrow ? 14 : (isNarrow ? 16 : 20)))
                              : Icon(icon, color: iconColor, size: isVeryNarrow ? 14 : (isNarrow ? 16 : 20)),
                        ),
                      ),
                      SizedBox(width: isVeryNarrow ? 6 : (isNarrow ? 8 : 12)),
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isVeryNarrow ? 11 : (isNarrow ? 12 : 14),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: isVeryNarrow ? 2 : 4),
                      // Compact group badges
                      _buildGroupBadges(item.groupNames, isNarrow),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Handle tap on an item card
  void _handleItemTap(UpcomingItem item) {
    if (item.type == UpcomingItemType.event && item.event != null) {
      // Show event detail dialog
      _showEventDetail(item.event!);
    } else {
      // For locations and birthdays, close this dialog and open date detail
      Navigator.pop(context);
      widget.onDateTap?.call(item.date);
    }
  }

  /// Show event detail dialog with edit button
  void _showEventDetail(GroupEvent event) {
    showEventDetailDialog(
      context,
      event,
      groupName: widget.groupNames[event.groupId],
      showDate: true,
      onEdit: () {
        if (!_checkCanWrite()) return;
        Navigator.pop(context); // Close event detail
        Navigator.pop(this.context); // Close upcoming summary
        // Show edit modal
        showModalBottomSheet(
          context: this.context,
          isScrollControlled: true,
          builder: (context) => AddEventModal(
            currentUserId: widget.currentUserId,
            initialDate: event.date,
            eventToEdit: event,
          ),
        );
      },
    );
  }

  /// Build stacked group badges - shows all groups for deduplicated items
  Widget _buildGroupBadges(List<String> groupNames, [bool isNarrow = false]) {
    if (groupNames.isEmpty) return const SizedBox.shrink();
    
    // On mobile, show max 2 badges in a single row
    if (isNarrow) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 65),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              groupNames.first,
              style: TextStyle(
                fontSize: 9,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (groupNames.length > 1)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                '+${groupNames.length - 1}',
                style: TextStyle(fontSize: 8, color: Colors.grey.shade500),
              ),
            ),
        ],
      );
    }
    
    if (groupNames.length == 1) {
      // Single group - simple badge
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          groupNames.first,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    
    // Multiple groups - stacked badges
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...groupNames.take(3).map((name) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.deepPurple.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }),
        if (groupNames.length > 3)
          Text(
            '+${groupNames.length - 3} more',
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade500,
            ),
          ),
      ],
    );
  }

  List<UpcomingItem> _buildUpcomingItems() {
    final items = <UpcomingItem>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDate = today.add(Duration(days: _daysToShow));

    // Helper to check if date is in upcoming range
    bool isUpcoming(DateTime date) {
      final dateOnly = DateTime(date.year, date.month, date.day);
      return !dateOnly.isBefore(today) && dateOnly.isBefore(endDate);
    }

    // Add events
    for (final event in widget.events) {
      if (isUpcoming(event.date)) {
        final groupName = widget.groupNames[event.groupId] ?? 'Group';
        items.add(UpcomingItem.fromEvent(event, groupName));
      }
    }

    // Add location changes - deduplicate by user+date+location, stack group names
    final userDefaults = <String, String?>{};
    for (final user in widget.allUsers) {
      final uid = user['uid'] as String?;
      if (uid != null) {
        userDefaults[uid] = user['defaultLocation'] as String?;
      }
    }

    // Group locations by user+date+nation+state to deduplicate across groups
    final locationGroups = <String, List<UserLocation>>{};
    for (final location in widget.locations) {
      if (isUpcoming(location.date)) {
        final dateKey = _formatDateKey(location.date);
        final locationKey = '${location.userId}|$dateKey|${location.nation}|${location.state ?? ''}';
        locationGroups.putIfAbsent(locationKey, () => []).add(location);
      }
    }

    // Create one item per unique location with stacked group names
    for (final entry in locationGroups.entries) {
      final locations = entry.value;
      final firstLocation = locations.first;
      
      // Find user/placeholder name
      String userName = 'Unknown';
      
      // First try to find in regular users
      final user = widget.allUsers.firstWhere(
        (u) => u['uid'] == firstLocation.userId,
        orElse: () => <String, dynamic>{},
      );
      
      if (user.isNotEmpty && user['displayName'] != null) {
        userName = user['displayName'] as String;
      } else {
        // Try to find in placeholder members
        final placeholder = widget.placeholderMembers.firstWhere(
          (p) => p.id == firstLocation.userId,
          orElse: () => PlaceholderMember(
            id: '', 
            groupId: '', 
            displayName: 'Unknown', 
            createdBy: '', 
            createdAt: DateTime.now(),
          ),
        );
        if (placeholder.id.isNotEmpty) {
          userName = placeholder.displayName;
        }
      }
      
      // Collect all unique group names for this location
      final groupNamesList = locations
          .map((loc) => widget.groupNames[loc.groupId] ?? 'Group')
          .toSet()
          .toList();
      
      final locationStr = firstLocation.state != null && firstLocation.state!.isNotEmpty
          ? '${firstLocation.state}, ${firstLocation.nation}'
          : firstLocation.nation;
      
      items.add(UpcomingItem(
        type: UpcomingItemType.locationChange,
        groupId: firstLocation.groupId,
        groupName: groupNamesList.first,
        groupNames: groupNamesList,
        userId: firstLocation.userId,
        userName: userName,
        date: firstLocation.date,
        title: '$userName → $locationStr',
        subtitle: null, // Groups shown as badges instead
        location: firstLocation,
      ));
    }


    // Add birthdays
    for (final user in widget.allUsers) {
      final uid = user['uid'] as String?;
      if (uid == null) continue;

      final groupId = user['groupId'] as String? ?? '';
      final groupName = widget.groupNames[groupId] ?? 'Group';

      // Solar birthday - check current year and next year
      final solarBirthday = Birthday.getSolarBirthday(user, now.year);
      if (solarBirthday != null && isUpcoming(solarBirthday.occurrenceDate)) {
        items.add(UpcomingItem.fromBirthday(solarBirthday, groupId, groupName));
      } else {
        // Check next year's occurrence for dates already passed this year
        final nextYearBirthday = Birthday.getSolarBirthday(user, now.year + 1);
        if (nextYearBirthday != null && isUpcoming(nextYearBirthday.occurrenceDate)) {
          items.add(UpcomingItem.fromBirthday(nextYearBirthday, groupId, groupName));
        }
      }

      // Lunar birthday - check each day in range
      for (int d = 0; d < _daysToShow; d++) {
        final checkDate = today.add(Duration(days: d));
        final lunarBirthday = Birthday.getLunarBirthday(user, now.year, checkDate);
        if (lunarBirthday != null) {
          items.add(UpcomingItem.fromBirthday(lunarBirthday, groupId, groupName));
        }
      }
    }

    // Add placeholder member birthdays
    for (final placeholder in widget.placeholderMembers) {
      final groupId = placeholder.groupId;
      final groupName = widget.groupNames[groupId] ?? 'Group';

      // Solar birthday (if set) - check current year and next year
      if (placeholder.birthday != null) {
        final solarBirthday = Birthday.fromPlaceholderMember(placeholder, now.year);
        if (solarBirthday != null && isUpcoming(solarBirthday.occurrenceDate)) {
          items.add(UpcomingItem.fromBirthday(solarBirthday, groupId, groupName));
        } else {
          // Check next year's occurrence for dates already passed this year
          final nextYearBirthday = Birthday.fromPlaceholderMember(placeholder, now.year + 1);
          if (nextYearBirthday != null && isUpcoming(nextYearBirthday.occurrenceDate)) {
            items.add(UpcomingItem.fromBirthday(nextYearBirthday, groupId, groupName));
          }
        }
      }

      // Lunar birthday - check each day in range
      if (placeholder.hasLunarBirthday && 
          placeholder.lunarBirthdayMonth != null && 
          placeholder.lunarBirthdayDay != null) {
        for (int d = 0; d < _daysToShow; d++) {
          final checkDate = today.add(Duration(days: d));
          final lunarBirthday = Birthday.fromPlaceholderLunar(placeholder, now.year, checkDate);
          if (lunarBirthday != null) {
            items.add(UpcomingItem.fromBirthday(lunarBirthday, groupId, groupName));
          }
        }
      }
    }

    // Add holidays
    for (final holiday in widget.holidays) {
      if (isUpcoming(holiday.date)) {
        items.add(UpcomingItem.fromHoliday(holiday));
      }
    }

    // Sort by date
    items.sort((a, b) => a.date.compareTo(b.date));

    return items;
  }
}

