import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../services/pwa_service.dart';
import '../models.dart';
import '../notification_center.dart';
import 'credits_feedback_dialog.dart';
import '../profile.dart';
import '../detail_modal.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final User? user;
  final bool canWrite;
  final String? photoUrl;
  final String? displayName;
  final List<Map<String, dynamic>> allUsers;
  
  final VoidCallback onUpcomingTap;
  final VoidCallback onBirthdayTap;
  final VoidCallback onProfileTap;
  
  // Helpers for DetailModal (within NotificationCenter navigation)
  final List<UserLocation> Function(DateTime) getLocationsForDate;
  final List<GroupEvent> Function(DateTime) getEventsForDate;
  final List<Holiday> Function(DateTime) getHolidaysForDate;
  final List<Birthday> Function(DateTime) getBirthdaysForDate;

  const HomeAppBar({
    super.key,
    required this.user,
    required this.canWrite,
    this.photoUrl,
    this.displayName,
    required this.allUsers,
    required this.onUpcomingTap,
    required this.onBirthdayTap,
    required this.onProfileTap,
    required this.getLocationsForDate,
    required this.getEventsForDate,
    required this.getHolidaysForDate,
    required this.getBirthdaysForDate,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);
    // Calculate effective width - at larger text scales, we need more space
    final effectiveWidth = screenWidth / textScale;
    
    // Check both effective width (for text scaling) AND raw screen width (for small screens)
    // This ensures good layout on both small screens and scaled text
    final showLogo = effectiveWidth >= 230 && screenWidth >= 300;
    final showOrbitText = effectiveWidth >= 280 && screenWidth >= 400;
    
    return AppBar(
      backgroundColor: Colors.transparent, // Glassmorphism base
      elevation: 0,
      titleSpacing: (effectiveWidth < 350 || screenWidth < 400) ? 0 : NavigationToolbar.kMiddleSpacing,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Theme.of(context).colorScheme.surface.withValues(
              alpha: 0.7,
            ), // Translucent using theme surface
          ),
        ),
      ),
      title: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => const CreditsAndFeedbackDialog(),
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hide logo only when effective width is very small OR screen is tiny
            if (showLogo)
              SvgPicture.asset("assets/orbit_logo.svg", height: 40),
            // Hide "Orbit" text when effective width is small OR screen is narrow
            if (showOrbitText) ...[
              const SizedBox(width: 8),
              Text(
                "Orbit",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (kIsWeb)
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blueAccent),
            tooltip: 'Refresh',
            onPressed: () => PWAService().reloadPage(),
          ),
        IconButton(
          icon: const Icon(Icons.event_note, color: Colors.deepPurple),
          tooltip: 'Upcoming',
          onPressed: onUpcomingTap,
        ),
        IconButton(
          icon: const Icon(Icons.cake, color: Colors.pink),
          tooltip: 'Birthday Baby',
          onPressed: onBirthdayTap,
        ),

        // Notification bell with unread badge
        StreamBuilder<int>(
          stream: NotificationService().getUnreadCount(user!.uid),
          builder: (context, snapshot) {
            final unreadCount = snapshot.data ?? 0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications,
                    color: Colors.orange,
                  ),
                  tooltip: 'Notifications',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (dialogContext) => NotificationCenter(
                        currentUserId: user!.uid,
                        canWrite: canWrite,
                        onNavigateToDate: (date) {
                          // Close the notification dialog first (already handled in NotificationCenter)
                          // Open detail modal for the specified date
                          final normalizedDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                          );
                          final locations = getLocationsForDate(
                            normalizedDate,
                          );
                          final events = getEventsForDate(normalizedDate);
                          final holidays = getHolidaysForDate(
                            normalizedDate,
                          );
                          final birthdays = getBirthdaysForDate(
                            normalizedDate,
                          );

                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            builder: (sheetContext) => DetailModal(
                              date: normalizedDate,
                              locations: locations,
                              events: events,
                              holidays: holidays,
                              birthdays: birthdays,
                              currentUserId: user!.uid,
                              canWrite: canWrite,
                              allUsers: allUsers,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 1.5,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        Padding(
          padding: const EdgeInsets.only(right: 16.0, left: 8.0),
          child: GestureDetector(
            onTap: onProfileTap,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[200],
              child: ClipOval(
                child: Image.network(
                  photoUrl ??
                      user?.photoURL ??
                      "https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayName ?? user?.displayName ?? 'User')}",
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.network(
                      "https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayName ?? user?.displayName ?? 'User')}",
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
