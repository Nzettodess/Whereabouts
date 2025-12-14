import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:grouped_list/grouped_list.dart';
import 'models.dart';
import 'models/upcoming_item.dart';
import 'add_event_modal.dart';

/// Dialog showing upcoming events, location changes, and birthdays
/// grouped by date. Only dates with items are displayed.
class UpcomingSummaryDialog extends StatefulWidget {
  final String currentUserId;
  final List<GroupEvent> events;
  final List<UserLocation> locations;
  final List<Map<String, dynamic>> allUsers;
  final Map<String, String> groupNames; // groupId -> groupName
  final void Function(DateTime date)? onDateTap; // Callback for opening date detail

  const UpcomingSummaryDialog({
    super.key,
    required this.currentUserId,
    required this.events,
    required this.locations,
    required this.allUsers,
    required this.groupNames,
    this.onDateTap,
  });

  @override
  State<UpcomingSummaryDialog> createState() => _UpcomingSummaryDialogState();
}

class _UpcomingSummaryDialogState extends State<UpcomingSummaryDialog> {
  // Filter state
  UpcomingItemType? _selectedFilter; // null means "All"
  
  @override
  Widget build(BuildContext context) {
    final upcomingItems = _buildUpcomingItems();
    final filteredItems = _selectedFilter == null
        ? upcomingItems
        : upcomingItems.where((item) => item.type == _selectedFilter).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event_note, color: Colors.deepPurple.shade700),
                      const SizedBox(width: 8),
                      Text(
                        "Upcoming",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Filter chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(null, 'All', Icons.list),
                    const SizedBox(width: 8),
                    _buildFilterChip(UpcomingItemType.event, 'Events', Icons.celebration),
                    const SizedBox(width: 8),
                    _buildFilterChip(UpcomingItemType.locationChange, 'Locations', Icons.location_on),
                    const SizedBox(width: 8),
                    _buildFilterChip(UpcomingItemType.birthday, 'Birthdays', Icons.cake),
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
                    : GroupedListView<UpcomingItem, String>(
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
                        padding: const EdgeInsets.only(bottom: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(UpcomingItemType? type, String label, IconData icon) {
    final isSelected = _selectedFilter == type;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? type : null;
        });
      },
      selectedColor: Colors.deepPurple,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      checkmarkColor: Colors.white,
      showCheckmark: false,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No upcoming items',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Events, location changes, and birthdays\nwill appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
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
      color: Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: itemDate == today ? Colors.deepPurple : Colors.deepPurple.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              dateFormatted,
              style: TextStyle(
                color: itemDate == today ? Colors.white : Colors.deepPurple.shade700,
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
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
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
    
    switch (item.type) {
      case UpcomingItemType.event:
        icon = Icons.celebration;
        iconColor = Colors.orange.shade700;
        bgColor = Colors.orange.shade50;
        break;
      case UpcomingItemType.locationChange:
        icon = Icons.location_on;
        iconColor = Colors.blue.shade700;
        bgColor = Colors.blue.shade50;
        break;
      case UpcomingItemType.birthday:
        icon = Icons.cake;
        iconColor = Colors.pink.shade700;
        bgColor = Colors.pink.shade50;
        break;
      case UpcomingItemType.lunarBirthday:
        icon = Icons.nightlight_round;
        iconColor = Colors.purple.shade700;
        bgColor = Colors.purple.shade50;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _handleItemTap(item),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Stacked group badges for items with multiple groups
                _buildGroupBadges(item.groupNames),
              ],
            ),
          ),
        ),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                event.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              tooltip: 'Edit Event',
              onPressed: () {
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
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date and time
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMM d, yyyy').format(event.date) +
                        (event.hasTime ? ' at ${DateFormat('HH:mm').format(event.date)}' : ''),
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Venue
              if (event.venue != null && event.venue!.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.venue!,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              
              // Group
              Row(
                children: [
                  Icon(Icons.group, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    widget.groupNames[event.groupId] ?? 'Group',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
              
              // Description
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  event.description,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Build stacked group badges - shows all groups for deduplicated items
  Widget _buildGroupBadges(List<String> groupNames) {
    if (groupNames.length == 1) {
      // Single group - simple badge
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          groupNames.first,
          style: TextStyle(
            fontSize: 11,
            color: Colors.deepPurple.shade700,
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
    final thirtyDaysLater = today.add(const Duration(days: 30));

    // Helper to check if date is in upcoming range
    bool isUpcoming(DateTime date) {
      final dateOnly = DateTime(date.year, date.month, date.day);
      return !dateOnly.isBefore(today) && dateOnly.isBefore(thirtyDaysLater);
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
      
      // Find user name
      final user = widget.allUsers.firstWhere(
        (u) => u['uid'] == firstLocation.userId,
        orElse: () => {'displayName': 'Unknown'},
      );
      final userName = user['displayName'] as String? ?? 'Unknown';
      
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

      // Solar birthday
      final solarBirthday = Birthday.getSolarBirthday(user, now.year);
      if (solarBirthday != null && isUpcoming(solarBirthday.occurrenceDate)) {
        items.add(UpcomingItem.fromBirthday(solarBirthday, groupId, groupName));
      }

      // Lunar birthday - check each day in range
      for (int d = 0; d < 30; d++) {
        final checkDate = today.add(Duration(days: d));
        final lunarBirthday = Birthday.getLunarBirthday(user, now.year, checkDate);
        if (lunarBirthday != null) {
          items.add(UpcomingItem.fromBirthday(lunarBirthday, groupId, groupName));
        }
      }
    }

    // Sort by date
    items.sort((a, b) => a.date.compareTo(b.date));

    return items;
  }
}
