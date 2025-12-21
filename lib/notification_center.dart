import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'firestore_service.dart';
import 'models.dart';
import 'widgets/skeleton_loading.dart';

class NotificationCenter extends StatefulWidget {
  final String currentUserId;
  final bool canWrite;

  const NotificationCenter({
    super.key, 
    required this.currentUserId,
    this.canWrite = true,
  });

  @override
  State<NotificationCenter> createState() => _NotificationCenterState();
}

class _NotificationCenterState extends State<NotificationCenter> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
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
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Notifications", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<AppNotification>>(
                stream: _firestoreService.getNotifications(widget.currentUserId),
                builder: (context, snapshot) {
                  // Show skeleton while loading
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const SkeletonDialogContent(itemCount: 3);
                  }
                  // Only show empty state when we've CONFIRMED data is loaded and empty
                  if (snapshot.hasData && snapshot.data!.isEmpty) {
                    return const Center(child: Text("No notifications"));
                  }
                  // Show skeleton if data is null but not waiting (transitional state)
                  if (!snapshot.hasData) {
                    return const SkeletonDialogContent(itemCount: 3);
                  }

                  final notifications = snapshot.data!;
                  return ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return ListTile(
                        leading: Icon(
                          Icons.notifications,
                          color: notification.read ? Colors.grey : Colors.blue,
                        ),
                        title: Text(
                          notification.message,
                          style: TextStyle(
                            fontWeight: notification.read ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(notification.timestamp),
                        ),
                        onTap: () {
                          if (widget.canWrite && !notification.read) {
                            _firestoreService.markNotificationRead(notification.id);
                          }
                        },
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
