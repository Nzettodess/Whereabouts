import '../models.dart';

/// Types of upcoming items that can appear in the summary
enum UpcomingItemType { 
  event, 
  locationChange, 
  birthday, 
  lunarBirthday,
  holiday,
}

/// A unified model representing any upcoming item (event, location change, or birthday)
class UpcomingItem {
  final UpcomingItemType type;
  final String groupId;
  final String groupName;
  final List<String> groupNames; // For stacked group badges (deduplicated items)
  final String? userId;
  final String? userName;
  final DateTime date;
  final String title;
  final String? subtitle;
  final GroupEvent? event;
  final UserLocation? location;
  final Birthday? birthday;
  final Holiday? holiday;

  UpcomingItem({
    required this.type,
    required this.groupId,
    required this.groupName,
    List<String>? groupNames,
    this.userId,
    this.userName,
    required this.date,
    required this.title,
    this.subtitle,
    this.event,
    this.location,
    this.birthday,
    this.holiday,
  }) : groupNames = groupNames ?? [groupName];

  /// Create an UpcomingItem from a GroupEvent
  factory UpcomingItem.fromEvent(GroupEvent event, String groupName) {
    // Build subtitle with venue and time only (group shown as badge, title as main header)
    final parts = <String>[];
    
    // Add venue first
    if (event.venue != null && event.venue!.isNotEmpty) {
      parts.add(event.venue!);
    }
    
    // Add time if event has time set
    if (event.hasTime) {
      final hour = event.date.hour;
      final minute = event.date.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final timeStr = '$displayHour:${minute.toString().padLeft(2, '0')} $period';
      parts.add(timeStr);
    }
    
    return UpcomingItem(
      type: UpcomingItemType.event,
      groupId: event.groupId,
      groupName: groupName,
      userId: event.creatorId,
      date: event.date,
      title: event.title,
      subtitle: parts.isEmpty ? null : parts.join(' • '),
      event: event,
    );
  }



  /// Create an UpcomingItem from a location change
  factory UpcomingItem.fromLocationChange(
    UserLocation location,
    String userName,
    String groupName,
  ) {
    final locationStr = location.state != null && location.state!.isNotEmpty
        ? '${location.state}, ${location.nation}'
        : location.nation;
    
    return UpcomingItem(
      type: UpcomingItemType.locationChange,
      groupId: location.groupId,
      groupName: groupName,
      userId: location.userId,
      userName: userName,
      date: location.date,
      title: '$userName → $locationStr',
      subtitle: groupName,
      location: location,
    );
  }

  /// Create an UpcomingItem from a Birthday
  factory UpcomingItem.fromBirthday(
    Birthday birthday,
    String groupId,
    String groupName,
  ) {
    final ageStr = birthday.age > 0 && !birthday.isLunar ? ' (${birthday.age})' : '';
    
    return UpcomingItem(
      type: birthday.isLunar ? UpcomingItemType.lunarBirthday : UpcomingItemType.birthday,
      groupId: groupId,
      groupName: groupName,
      userId: birthday.userId,
      userName: birthday.displayName,
      date: birthday.occurrenceDate,
      title: "${birthday.displayName}'s Birthday$ageStr",
      subtitle: groupName,
      birthday: birthday,
    );
  }

  /// Get the appropriate icon for this item type
  String get icon {
    switch (type) {
      case UpcomingItemType.event:
        return '🎉';
      case UpcomingItemType.locationChange:
        return '📍';
      case UpcomingItemType.birthday:
        return '🎂';
      case UpcomingItemType.lunarBirthday:
        return '🏮';
      case UpcomingItemType.holiday:
        return '🎌';
    }
  }

  /// Create an UpcomingItem from a Holiday
  factory UpcomingItem.fromHoliday(Holiday holiday) {
    return UpcomingItem(
      type: UpcomingItemType.holiday,
      groupId: 'public',
      groupName: 'Public Holiday',
      date: holiday.date,
      title: holiday.localName,
      subtitle: null,
      holiday: holiday,
    );
  }
}
