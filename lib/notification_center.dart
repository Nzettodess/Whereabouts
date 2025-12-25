import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'firestore_service.dart';
import 'models.dart';
import 'widgets/skeleton_loading.dart';
import 'group_management.dart';
import 'services/notification_service.dart';

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
  // removed _isMarkingAllRead to rely on stream updates for snappier feel

  /// Get icon data based on notification type
  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.joinRequest:
      case NotificationType.joinApproved:
      case NotificationType.joinRejected:
      case NotificationType.roleChange:
      case NotificationType.removedFromGroup:
        return Icons.person;
      case NotificationType.inheritanceRequest:
      case NotificationType.inheritanceApproved:
      case NotificationType.inheritanceRejected:
        return Icons.person_add;
      case NotificationType.eventCreated:
      case NotificationType.eventUpdated:
      case NotificationType.eventDeleted:
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
      case NotificationType.inheritanceRejected:
      case NotificationType.removedFromGroup:
        return Colors.red;
      case NotificationType.inheritanceRequest:
      case NotificationType.roleChange:
        return Colors.blue;
      case NotificationType.inheritanceApproved:
        return Colors.green;
      case NotificationType.eventCreated:
      case NotificationType.eventUpdated:
        return Colors.purple;
      case NotificationType.eventDeleted:
        return Colors.red;
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
    // Optimistic / Fire-and-forget for better perceived performance
    // The stream will update the UI when the backend writes complete
    try {
      await NotificationService().markAllAsRead(widget.currentUserId);
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  /// Mark all notifications as unread
  Future<void> _markAllAsUnread() async {
     try {
      await _firestoreService.markAllAsUnread(widget.currentUserId);
    } catch (e) {
      print('Error marking all as unread: $e');
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
    // Mark as read if unread
    if (!notification.read && widget.canWrite) {
      _firestoreService.markNotificationRead(notification.id);
    }

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
        
      case NotificationType.inheritanceRequest:
        // Navigate to placeholder management logic - for now open group management
         showDialog(
          context: context,
          builder: (context) => const GroupManagementDialog(),
        );
        break;

      case NotificationType.roleChange:
      case NotificationType.removedFromGroup:
      case NotificationType.inheritanceApproved:
      case NotificationType.inheritanceRejected:
        // No specific action, maybe show dialog or just open group management
         showDialog(
          context: context,
          builder: (context) => const GroupManagementDialog(),
        );
        break;
        
      case NotificationType.eventCreated:
      case NotificationType.eventUpdated:
      case NotificationType.eventDeleted:
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

  Future<void> _confirmDeleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete All?"),
        content: const Text("Are you sure you want to delete ALL notifications? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete All", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Clear list immediately for UI responsiveness (optional, but stream will handle it)
      // Call service
      await _firestoreService.deleteAllNotifications(widget.currentUserId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final isNarrow = MediaQuery.of(context).size.width < 400;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 600, // Widened for PC per request
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          minWidth: 0, 
        ),
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
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
                      // Mark all as read button (Icon Only)
                      if (widget.canWrite)
                        IconButton(
                          onPressed: _markAllAsRead,
                          icon: const Icon(Icons.done_all),
                          tooltip: 'Mark All Read',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      if (!isNarrow) const SizedBox(width: 8),
                      // Mark All Unread Button (New)
                      IconButton(
                        onPressed: _markAllAsUnread,
                        icon: const Icon(Icons.undo), // Or another suitable icon
                        tooltip: 'Mark All Unread',
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      // Delete All Button (Trash Sweep)
                      if (widget.canWrite)
                        IconButton(
                           icon: const Icon(Icons.delete_sweep),
                           tooltip: 'Delete All',
                           onPressed: _confirmDeleteAll,
                           color: Colors.red,
                        ),
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
                  // Show skeleton while loading - DISABLED per user request
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          "Error: ${snapshot.error}",
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  // Show empty state if no notifications
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                        // Trailing: Mark as Read (Check) OR Delete (Trash)
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                             // Mark as read/unread toggle
                             if (widget.canWrite)
                                IconButton(
                                  icon: Icon(
                                    notification.read ? Icons.circle_outlined : Icons.check_circle,
                                    color: notification.read ? Colors.grey : Theme.of(context).colorScheme.primary,
                                    size: 22,
                                  ),
                                  tooltip: notification.read ? 'Mark as Unread' : 'Mark as Read',
                                  onPressed: () {
                                    if (notification.read) {
                                      _firestoreService.markNotificationUnread(notification.id);
                                    } else {
                                      _firestoreService.markNotificationRead(notification.id);
                                    }
                                  },
                                ),
                             // Dot indicator (only if unread and not writable?) - Logic from before was weird, keeping it simple
                             if (!notification.read && !widget.canWrite)
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                             // Delete button (always visible)
                             if (widget.canWrite)
                               IconButton(
                                 icon: Icon(
                                   Icons.delete_outline,
                                    color: Colors.grey.withOpacity(0.6),
                                   size: 20,
                                 ),
                                 tooltip: 'Delete',
                                 onPressed: () {
                                   _firestoreService.deleteNotification(notification.id);
                                 },
                               ),
                          ],
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
