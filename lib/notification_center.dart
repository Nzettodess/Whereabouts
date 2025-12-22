import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'firestore_service.dart';
import 'models.dart';
import 'widgets/skeleton_loading.dart';
import 'group_management.dart';

class NotificationCenter extends StatefulWidget {
  final String currentUserId;
  final bool canWrite;
  final VoidCallback? onNavigateToGroups; // Optional callback to navigate to group management
  final void Function(DateTime date)? onNavigateToDate; // Callback to navigate to a specific date

  const NotificationCenter({
    super.key, 
    required this.currentUserId,
    this.canWrite = true,
    this.onNavigateToGroups,
    this.onNavigateToDate,
  });

  @override
  State<NotificationCenter> createState() => _NotificationCenterState();
}

class _NotificationCenterState extends State<NotificationCenter> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isMarkingAllRead = false;

  /// Get icon data based on notification type
  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.joinRequest:
      case NotificationType.joinApproved:
      case NotificationType.joinRejected:
        return Icons.person_add;
      case NotificationType.eventCreated:
      case NotificationType.eventUpdated:
        return Icons.event;
      case NotificationType.rsvpReceived:
        return Icons.how_to_reg;
      case NotificationType.locationChanged:
        return Icons.location_on;
      case NotificationType.birthdayToday:
      case NotificationType.birthdayMonthly:
        return Icons.cake;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  /// Get color based on notification type
  Color _getColorForType(NotificationType type, bool read) {
    if (read) return Colors.grey;
    switch (type) {
      case NotificationType.joinRequest:
        return Colors.blue;
      case NotificationType.joinApproved:
        return Colors.green;
      case NotificationType.joinRejected:
        return Colors.red;
      case NotificationType.eventCreated:
      case NotificationType.eventUpdated:
        return Colors.purple;
      case NotificationType.rsvpReceived:
        return Colors.teal;
      case NotificationType.locationChanged:
        return Colors.orange;
      case NotificationType.birthdayToday:
      case NotificationType.birthdayMonthly:
        return Colors.pink;
      case NotificationType.general:
        return Colors.blue;
    }
  }

  /// Mark all notifications as read
  Future<void> _markAllAsRead() async {
    if (_isMarkingAllRead) return; // Prevent double-tap
    
    setState(() => _isMarkingAllRead = true);
    
    try {
      final snapshot = await _firestoreService.getNotifications(widget.currentUserId).first;
      for (final notification in snapshot) {
        if (!notification.read) {
          await _firestoreService.markNotificationRead(notification.id);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isMarkingAllRead = false);
      }
    }
  }

  /// Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  /// Handle notification tap - navigate based on type
  void _handleNotificationTap(AppNotification notification) {
    // Close the notification dialog first
    Navigator.pop(context);
    
    // Navigate based on notification type
    switch (notification.type) {
      case NotificationType.joinRequest:
      case NotificationType.joinApproved:
      case NotificationType.joinRejected:
        // Navigate to group management to handle the join request
        showDialog(
          context: context,
          builder: (context) => const GroupManagementDialog(),
        );
        break;
        
      case NotificationType.eventCreated:
      case NotificationType.eventUpdated:
      case NotificationType.rsvpReceived:
        // Navigate to the date of the event/RSVP
        // Try to parse date from notification timestamp or use today
        if (widget.onNavigateToDate != null) {
          widget.onNavigateToDate!(notification.timestamp);
        }
        break;
        
      case NotificationType.locationChanged:
        // Navigate to today's date to see location changes
        if (widget.onNavigateToDate != null) {
          widget.onNavigateToDate!(DateTime.now());
        }
        break;
        
      case NotificationType.birthdayToday:
        // Navigate to today to see birthday
        if (widget.onNavigateToDate != null) {
          widget.onNavigateToDate!(DateTime.now());
        }
        break;
        
      case NotificationType.birthdayMonthly:
        // Navigate to today (monthly summary)
        if (widget.onNavigateToDate != null) {
          widget.onNavigateToDate!(DateTime.now());
        }
        break;
        
      case NotificationType.general:
        // No specific navigation for general notifications
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Notifications", 
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      // Mark all as read button
                      if (widget.canWrite)
                        _isMarkingAllRead
                            ? const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : TextButton.icon(
                                onPressed: _markAllAsRead,
                                icon: const Icon(Icons.done_all, size: 18),
                                label: const Text('Mark All Read'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close), 
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            // Notifications List
            Expanded(
              child: StreamBuilder<List<AppNotification>>(
                stream: _firestoreService.getNotifications(widget.currentUserId),
                builder: (context, snapshot) {
                  // Show skeleton while loading
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return ListView.separated(
                      itemCount: 8,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Row(
                          children: [
                            // Icon container skeleton (40+10*2 padding = actual ~44px)
                            const SkeletonCircle(size: 44),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SkeletonBox(width: double.infinity, height: 16),
                                  const SizedBox(height: 8),
                                  SkeletonBox(width: 80, height: 14),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Mark as read button skeleton
                            const SkeletonCircle(size: 28),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  // Only show empty state when we've CONFIRMED data is loaded and empty
                  if (snapshot.hasData && snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: Colors.grey.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No notifications",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "You're all caught up! 🎉",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  // Transitional state (rare with Firestore cache) - show simple loading
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final notifications = snapshot.data!;
                  return ListView.separated(
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final iconColor = _getColorForType(notification.type, notification.read);
                      
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getIconForType(notification.type),
                            color: iconColor,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          notification.message,
                          style: TextStyle(
                            fontWeight: notification.read ? FontWeight.normal : FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _formatTimestamp(notification.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                        // Show mark as read button for unread notifications
                        trailing: notification.read 
                            ? null 
                            : widget.canWrite 
                                ? IconButton(
                                    icon: Icon(
                                      Icons.check_circle_outline,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 22,
                                    ),
                                    tooltip: 'Mark as read',
                                    onPressed: () {
                                      _firestoreService.markNotificationRead(notification.id);
                                    },
                                  )
                                : Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                        onTap: () => _handleNotificationTap(notification),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
