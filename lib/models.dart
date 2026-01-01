import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lunar/lunar.dart';
import 'models/placeholder_member.dart';
export 'models/placeholder_member.dart';

class Group {
  final String id;
  final String name;
  final String ownerId;
  final List<String> admins;
  final List<String> members;
  final String? lastBirthdayCheck;
  final String? lastMonthlyBirthdayCheck;

  Group({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.admins,
    required this.members,
    this.lastBirthdayCheck,
    this.lastMonthlyBirthdayCheck,
  });

  factory Group.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Group(
      id: doc.id,
      name: data['name'] ?? '',
      ownerId: data['ownerId'] ?? '',
      admins: List<String>.from(data['admins'] ?? []),
      members: List<String>.from(data['members'] ?? []),
      lastBirthdayCheck: data['lastBirthdayCheck'],
      lastMonthlyBirthdayCheck: data['lastMonthlyBirthdayCheck'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerId': ownerId,
      'admins': admins,
      'members': members,
      'lastBirthdayCheck': lastBirthdayCheck,
      'lastMonthlyBirthdayCheck': lastMonthlyBirthdayCheck,
    };
  }
}

class UserLocation {
  final String userId;
  final String groupId;
  final DateTime date;
  final String nation;
  final String? state;

  UserLocation({
    required this.userId,
    required this.groupId,
    required this.date,
    required this.nation,
    this.state,
  });

  factory UserLocation.fromFirestore(Map<String, dynamic> data) {
    DateTime parsedDate;
    final dynamic dateData = data['date'];
    if (dateData is Timestamp) {
      parsedDate = dateData.toDate();
    } else if (dateData is String) {
      parsedDate = DateTime.tryParse(dateData) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return UserLocation(
      userId: data['userId'] ?? '',
      groupId: data['groupId'] ?? '',
      date: parsedDate,
      nation: data['nation'] ?? '',
      state: data['state'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'groupId': groupId,
      'date': "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
      'nation': nation,
      'state': state,
    };
  }
}

class Holiday {
  final String localName;
  final DateTime date;
  final String countryCode;

  Holiday({
    required this.localName,
    required this.date,
    required this.countryCode,
  });

  factory Holiday.fromJsonCalendarific(Map<String, dynamic> json) {
    return Holiday(
      localName: json['name'] ?? '',
      date: DateTime.parse(json['date']['iso']),
      countryCode: json['country']['id'] ?? '',
    );
  }

  factory Holiday.fromJsonFestivo(Map<String, dynamic> json) {
    return Holiday(
      localName: json['name'] ?? '',
      date: DateTime.parse(json['date']),
      countryCode: json['country'] ?? '',
    );
  }

  factory Holiday.fromGoogleCalendar(Map<String, dynamic> json, String calendarId) {
    // Parse date from Google Calendar format
    final startDate = json['start'];
    DateTime date;
    
    if (startDate['date'] != null) {
      // All-day event
      date = DateTime.parse(startDate['date']);
    } else if (startDate['dateTime'] != null) {
      // Timed event
      date = DateTime.parse(startDate['dateTime']);
    } else {
      date = DateTime.now();
    }

    // Extract country code from calendar ID
    String countryCode = 'GLOBAL';
    if (calendarId.contains('#holiday@group.v.calendar.google.com')) {
      final parts = calendarId.split('#');
      if (parts.isNotEmpty) {
        countryCode = parts[0].toUpperCase();
      }
    }

    return Holiday(
      localName: json['summary'] ?? 'Holiday',
      date: date,
      countryCode: countryCode,
    );
  }

  /// Create from cached map data
  factory Holiday.fromMap(Map<String, dynamic> map) {
    return Holiday(
      localName: map['localName'] ?? '',
      date: map['date'] is Timestamp 
          ? (map['date'] as Timestamp).toDate()
          : DateTime.parse(map['date'].toString()),
      countryCode: map['countryCode'] ?? '',
    );
  }

  /// Convert to map for caching in Firestore
  Map<String, dynamic> toMap() {
    return {
      'localName': localName,
      'date': date.toIso8601String(),
      'countryCode': countryCode,
    };
  }
}

/// Notification types for proper icon display and categorization
enum NotificationType {
  joinRequest,      // 👤 Join request received
  joinApproved,     // ✅ Join request approved
  joinRejected,     // ❌ Join request rejected
  inheritanceRequest, // 🧬 Request to inherit placeholder
  inheritanceApproved,// ✅ Inheritance approved
  inheritanceRejected,// ❌ Inheritance rejected
  roleChange,         // 👑 Promoted/Demoted/Transferred
  removedFromGroup,   // 🚫 Removed from group
  eventCreated,       // 📅 New event created
  eventUpdated,       // 📅 Event updated
  eventDeleted,       // 📅 Event deleted
  rsvpReceived,       // 📋 Someone RSVP'd to your event
  locationChanged,    // 📍 Someone changed their location
  birthdayToday,      // 🎂 It's someone's birthday
  birthdayMonthly,    // 🎂 Monthly birthday summary
  general,          // 🔔 General notification
}

class AppNotification {
  final String id;
  final String userId;
  final String message;
  final DateTime timestamp;
  final bool read;
  final NotificationType type;
  final String? dedupeKey;  // For deduplication: location_{userId}_{date}, event_{eventId}, etc.
  final String? groupId;    // Optional group context
  final String? relatedId;  // Optional: eventId, userId, etc. for navigation

  AppNotification({
    required this.id,
    required this.userId,
    required this.message,
    required this.timestamp,
    required this.read,
    this.type = NotificationType.general,
    this.dedupeKey,
    this.groupId,
    this.relatedId,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data = (doc.data() as Map?)?.cast<String, dynamic>() ?? {};
    
    // Handle null timestamp (can happen with pending server timestamps)
    DateTime timestamp;
    final tsData = data['timestamp'];
    if (tsData != null && tsData is Timestamp) {
      timestamp = tsData.toDate();
    } else {
      timestamp = DateTime.now(); // Fallback for pending/null timestamps
    }
    
    return AppNotification(
      id: doc.id,
      userId: data['userId'] ?? '',
      message: data['message'] ?? '',
      timestamp: timestamp,
      read: data['read'] ?? false,
      type: _parseNotificationType(data['type']),
      dedupeKey: data['dedupeKey'],
      groupId: data['groupId'],
      relatedId: data['relatedId'],
    );
  }

  static NotificationType _parseNotificationType(String? typeStr) {
    if (typeStr == null) return NotificationType.general;
    try {
      return NotificationType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => NotificationType.general,
      );
    } catch (_) {
      return NotificationType.general;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'read': read,
      'type': type.name,
      if (dedupeKey != null) 'dedupeKey': dedupeKey,
      if (groupId != null) 'groupId': groupId,
      if (relatedId != null) 'relatedId': relatedId,
    };
  }

  /// Get icon for this notification type
  String get icon {
    switch (type) {
      case NotificationType.joinRequest:
      case NotificationType.joinApproved:
      case NotificationType.joinRejected:
        return '👤';
      case NotificationType.inheritanceRequest:
      case NotificationType.inheritanceApproved:
      case NotificationType.inheritanceRejected:
        return '🧬';
      case NotificationType.roleChange:
        return '👑';
      case NotificationType.removedFromGroup:
        return '🚫';
      case NotificationType.eventCreated:
      case NotificationType.eventUpdated:
      case NotificationType.eventDeleted:
        return '📅';
      case NotificationType.rsvpReceived:
        return '📋';
      case NotificationType.locationChanged:
        return '📍';
      case NotificationType.birthdayToday:
      case NotificationType.birthdayMonthly:
        return '🎂';
      case NotificationType.general:
        return '🔔';
    }
  }
}

class GroupEvent {
  final String id;
  final String groupId;
  final String creatorId;
  final String title;
  final String description;
  final String? venue; // Optional venue field
  final DateTime date;
  final bool hasTime;
  final Map<String, String> rsvps; // userId -> status ('Yes', 'No', 'Maybe')
  final String? lastEditedBy; // userId of last editor
  final DateTime? lastEditedAt; // Timestamp of last edit
  final List<Map<String, dynamic>>? editHistory; // Max 2 previous versions
  final String? timezone; // e.g. "Hong Kong" or "EST" (creator's context)

  GroupEvent({
    required this.id,
    required this.groupId,
    required this.creatorId,
    required this.title,
    required this.description,
    this.venue,
    required this.date,
    this.hasTime = false,
    required this.rsvps,
    this.lastEditedBy,
    this.lastEditedAt,
    this.editHistory,
    this.timezone,
  });

  factory GroupEvent.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data = (doc.data() as Map?)?.cast<String, dynamic>() ?? {};
    return GroupEvent(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      creatorId: data['creatorId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      venue: data['venue'],
      date: (data['date'] as Timestamp).toDate(),
      hasTime: data['hasTime'] ?? false,
      rsvps: Map<String, String>.from(data['rsvps'] ?? {}),
      lastEditedBy: data['lastEditedBy'],
      lastEditedAt: data['lastEditedAt'] != null 
          ? (data['lastEditedAt'] as Timestamp).toDate() 
          : null,
      editHistory: data['editHistory'] != null
          ? List<Map<String, dynamic>>.from(data['editHistory'])
          : null,
      timezone: data['timezone'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'groupId': groupId,
      'creatorId': creatorId,
      'title': title,
      'description': description,
      'venue': venue,
      'date': Timestamp.fromDate(date),
      'hasTime': hasTime,
      'rsvps': rsvps,
    };
    // Only include version history fields if they have values
    // (updateEvent sets these directly, we don't want toMap to overwrite with nulls)
    if (lastEditedBy != null) map['lastEditedBy'] = lastEditedBy;
    if (lastEditedAt != null) map['lastEditedAt'] = Timestamp.fromDate(lastEditedAt!);
    if (editHistory != null) map['editHistory'] = editHistory;
    if (timezone != null) map['timezone'] = timezone;
    return map;
  }

  // RSVP Helper Methods
  
  /// Get count of users with specific RSVP status
  int getRSVPCount(String status) {
    return rsvps.values.where((s) => s == status).length;
  }

  /// Get list of user IDs with specific RSVP status
  List<String> getUsersWithStatus(String status) {
    return rsvps.entries
        .where((entry) => entry.value == status)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get list of users who haven't responded yet
  List<String> getUsersWithNoResponse(List<String> allMembers) {
    return allMembers.where((userId) => !rsvps.containsKey(userId)).toList();
  }

  /// Get total number of responses (excluding no response)
  int getTotalResponses() {
    return rsvps.length;
  }

  /// Calculate response rate as percentage
  double getResponseRate(int totalMembers) {
    if (totalMembers == 0) return 0.0;
    return (rsvps.length / totalMembers) * 100;
  }

  /// Get accepted count
  int get acceptedCount => getRSVPCount('Yes');

  /// Get declined count
  int get declinedCount => getRSVPCount('No');

  /// Get maybe count
  int get maybeCount => getRSVPCount('Maybe');
}

class Birthday {
  final String userId;
  final String displayName;
  final DateTime birthDate; // Original birth date with year
  final DateTime occurrenceDate; // This year's occurrence
  final int age;
  final bool isLunar; // Whether this is a lunar calendar birthday

  Birthday({
    required this.userId,
    required this.displayName,
    required this.birthDate,
    required this.occurrenceDate,
    required this.age,
    this.isLunar = false,
  });

  // Get solar (Georgian) birthday - ignores isLunarBirthday flag (deprecated)
  static Birthday? getSolarBirthday(Map<String, dynamic> userData, int year) {
    final birthday = userData['birthday'];
    if (birthday == null) return null;

    final birthDate = (birthday as Timestamp).toDate();
    final userId = userData['uid'] ?? '';
    final displayName = userData['displayName'] ?? userData['email'] ?? 'User';

    // Regular solar calendar birthday
    final occurrenceDate = DateTime(year, birthDate.month, birthDate.day);
    int age = year - birthDate.year;

    return Birthday(
      userId: userId,
      displayName: displayName,
      birthDate: birthDate,
      occurrenceDate: occurrenceDate,
      age: age,
      isLunar: false,
    );
  }

  // Get lunar birthday (separate from solar) - checks if date's lunar month/day matches stored values
  static Birthday? getLunarBirthday(Map<String, dynamic> userData, int year, DateTime checkDate) {
    final hasLunarBirthday = userData['hasLunarBirthday'] ?? false;
    final lunarBirthdayMonth = userData['lunarBirthdayMonth'];
    final lunarBirthdayDay = userData['lunarBirthdayDay'];
    
    if (!hasLunarBirthday || lunarBirthdayMonth == null || lunarBirthdayDay == null) {
      return null;
    }

    final userId = userData['uid'] ?? '';
    final displayName = userData['displayName'] ?? userData['email'] ?? 'User';

    try {
      // Convert checkDate to lunar calendar and compare month/day
      final lunar = Lunar.fromDate(checkDate);
      final lunarMonth = lunar.getMonth();
      final lunarDay = lunar.getDay();

      // Check if this date's lunar month/day matches the stored lunar birthday
      if (lunarMonth == lunarBirthdayMonth && lunarDay == lunarBirthdayDay) {
        // Calculate approximate age (using current year minus birth year from solar birthday if available)
        int age = 0;
        final solarBirthday = userData['birthday'];
        if (solarBirthday != null) {
          final birthDate = (solarBirthday as Timestamp).toDate();
          age = year - birthDate.year;
        }

        return Birthday(
          userId: userId,
          displayName: displayName, // Keep display name clean
          birthDate: checkDate, // Use checkDate as placeholder
          occurrenceDate: checkDate,
          age: -1, // Use -1 to indicate age should not be shown for lunar birthday
          isLunar: true,
        );
      }
    } catch (e) {
      print('Error checking lunar birthday: $e');
    }

    return null;
  }

  // Get solar birthday from placeholder member
  static Birthday? fromPlaceholderMember(PlaceholderMember placeholder, int year) {
    if (placeholder.birthday == null) return null;

    final birthDate = placeholder.birthday!;
    final occurrenceDate = DateTime(year, birthDate.month, birthDate.day);
    int age = year - birthDate.year;

    return Birthday(
      userId: placeholder.id, // Use placeholder ID as user ID
      displayName: placeholder.displayName,
      birthDate: birthDate,
      occurrenceDate: occurrenceDate,
      age: age,
      isLunar: false,
    );
  }

  // Get lunar birthday from placeholder member
  static Birthday? fromPlaceholderLunar(PlaceholderMember placeholder, int year, DateTime checkDate) {
    if (!placeholder.hasLunarBirthday || 
        placeholder.lunarBirthdayMonth == null || 
        placeholder.lunarBirthdayDay == null) {
      return null;
    }

    try {
      // Convert checkDate to lunar calendar and compare month/day
      final lunar = Lunar.fromDate(checkDate);
      final lunarMonth = lunar.getMonth();
      final lunarDay = lunar.getDay();

      // Check if this date's lunar month/day matches the stored lunar birthday
      if (lunarMonth == placeholder.lunarBirthdayMonth && lunarDay == placeholder.lunarBirthdayDay) {
        // Calculate approximate age (using solar birthday if available)
        int age = 0;
        if (placeholder.birthday != null) {
          age = year - placeholder.birthday!.year;
        }

        return Birthday(
          userId: placeholder.id, // Use placeholder ID as user ID
          displayName: placeholder.displayName,
          birthDate: checkDate,
          occurrenceDate: checkDate,
          age: -1, // Use -1 to indicate age should not be shown for lunar birthday
          isLunar: true,
        );
      }
    } catch (e) {
      print('Error checking placeholder lunar birthday: $e');
    }

    return null;
  }

  // Legacy method - now just returns solar birthday (for backward compatibility)
  static Birthday? fromUserData(Map<String, dynamic> userData, int year) {
    return getSolarBirthday(userData, year);
  }
}

