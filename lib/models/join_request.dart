import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a request to join a group.
/// Similar pattern to InheritanceRequest.
class JoinRequest {
  final String id;
  final String groupId;
  final String requesterId;
  final String requesterName;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final String? processedBy;
  final DateTime? processedAt;

  JoinRequest({
    required this.id,
    required this.groupId,
    required this.requesterId,
    required this.requesterName,
    required this.status,
    required this.createdAt,
    this.processedBy,
    this.processedAt,
  });

  factory JoinRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JoinRequest(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      requesterId: data['requesterId'] ?? '',
      requesterName: data['requesterName'] ?? 'Unknown User',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      processedBy: data['processedBy'],
      processedAt: (data['processedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'requesterId': requesterId,
      'requesterName': requesterName,
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
