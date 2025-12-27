import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a placeholder member in a group that can be inherited by a real user.
class PlaceholderMember {
  final String id;
  final String groupId;
  final String displayName;
  final String createdBy;
  final DateTime createdAt;
  final String? defaultLocation;
  final DateTime? birthday;
  final bool hasLunarBirthday;
  final int? lunarBirthdayMonth;
  final int? lunarBirthdayDay;

  PlaceholderMember({
    required this.id,
    required this.groupId,
    required this.displayName,
    required this.createdBy,
    required this.createdAt,
    this.defaultLocation,
    this.birthday,
    this.hasLunarBirthday = false,
    this.lunarBirthdayMonth,
    this.lunarBirthdayDay,
  });

  factory PlaceholderMember.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data = (doc.data() as Map?)?.cast<String, dynamic>() ?? {};
    return PlaceholderMember(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      displayName: data['displayName'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      defaultLocation: data['defaultLocation'],
      birthday: (data['birthday'] as Timestamp?)?.toDate(),
      hasLunarBirthday: data['hasLunarBirthday'] ?? false,
      lunarBirthdayMonth: data['lunarBirthdayMonth'],
      lunarBirthdayDay: data['lunarBirthdayDay'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'displayName': displayName,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'defaultLocation': defaultLocation,
      'birthday': birthday != null ? Timestamp.fromDate(birthday!) : null,
      'hasLunarBirthday': hasLunarBirthday,
      'lunarBirthdayMonth': lunarBirthdayMonth,
      'lunarBirthdayDay': lunarBirthdayDay,
    };
  }

  /// Create a copy with updated fields
  PlaceholderMember copyWith({
    String? displayName,
    String? defaultLocation,
    DateTime? birthday,
    bool? hasLunarBirthday,
    int? lunarBirthdayMonth,
    int? lunarBirthdayDay,
  }) {
    return PlaceholderMember(
      id: id,
      groupId: groupId,
      displayName: displayName ?? this.displayName,
      createdBy: createdBy,
      createdAt: createdAt,
      defaultLocation: defaultLocation ?? this.defaultLocation,
      birthday: birthday ?? this.birthday,
      hasLunarBirthday: hasLunarBirthday ?? this.hasLunarBirthday,
      lunarBirthdayMonth: lunarBirthdayMonth ?? this.lunarBirthdayMonth,
      lunarBirthdayDay: lunarBirthdayDay ?? this.lunarBirthdayDay,
    );
  }
}

/// Represents a request to inherit a placeholder member's data.
class InheritanceRequest {
  final String id;
  final String placeholderMemberId;
  final String requesterId;
  final String groupId;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final String? processedBy;
  final DateTime? processedAt;

  InheritanceRequest({
    required this.id,
    required this.placeholderMemberId,
    required this.requesterId,
    required this.groupId,
    required this.status,
    required this.createdAt,
    this.processedBy,
    this.processedAt,
  });

  factory InheritanceRequest.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data = (doc.data() as Map?)?.cast<String, dynamic>() ?? {};
    return InheritanceRequest(
      id: doc.id,
      placeholderMemberId: data['placeholderMemberId'] ?? '',
      requesterId: data['requesterId'] ?? '',
      groupId: data['groupId'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      processedBy: data['processedBy'],
      processedAt: (data['processedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'placeholderMemberId': placeholderMemberId,
      'requesterId': requesterId,
      'groupId': groupId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'processedBy': processedBy,
      'processedAt': processedAt != null ? Timestamp.fromDate(processedAt!) : null,
    };
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}

/// Location entry for a placeholder member.
class PlaceholderLocation {
  final String placeholderMemberId;
  final String groupId;
  final DateTime date;
  final String nation;
  final String? state;

  PlaceholderLocation({
    required this.placeholderMemberId,
    required this.groupId,
    required this.date,
    required this.nation,
    this.state,
  });

  factory PlaceholderLocation.fromFirestore(Map<String, dynamic> data) {
    DateTime parsedDate;
    final dynamic dateData = data['date'];
    if (dateData is Timestamp) {
      parsedDate = dateData.toDate();
    } else if (dateData is String) {
      parsedDate = DateTime.tryParse(dateData) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return PlaceholderLocation(
      placeholderMemberId: data['placeholderMemberId'] ?? '',
      groupId: data['groupId'] ?? '',
      date: parsedDate,
      nation: data['nation'] ?? '',
      state: data['state'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'placeholderMemberId': placeholderMemberId,
      'groupId': groupId,
      'date': Timestamp.fromDate(date),
      'nation': nation,
      'state': state,
    };
  }
}
