import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'models.dart';
import 'firestore_service.dart';
import 'widgets/user_avatar.dart';
import 'widgets/skeleton_loading.dart';
import 'services/notification_service.dart';

enum EventFilter { all, upcoming, past }

class RSVPManagementDialog extends StatefulWidget {
  final String currentUserId;

  const RSVPManagementDialog({
    super.key,
    required this.currentUserId,
  });

  @override
  State<RSVPManagementDialog> createState() => _RSVPManagementDialogState();
}
class _RSVPManagementDialogState extends State<RSVPManagementDialog> {
  final FirestoreService _firestoreService = FirestoreService();
  EventFilter _currentFilter = EventFilter.upcoming;
  Map<String, String> _userGroupRoles = {};
  late Stream<List<GroupEvent>> _eventsStream;

  @override
  void initState() {
    super.initState();
    _eventsStream = _firestoreService.getAllUserEvents(widget.currentUserId);
    _loadUserRoles();
  }

  Future<void> _loadUserRoles() async {
    try {
      final groups = await _firestoreService.getUserGroups(widget.currentUserId).first;
      final roles = <String, String>{};
      for (var g in groups) {
        if (g.ownerId == widget.currentUserId) {
          roles[g.id] = 'owner';
        } else if (g.admins.contains(widget.currentUserId)) {
          roles[g.id] = 'admin';
        } else {
          roles[g.id] = 'member';
        }
      }
      if (mounted) {
        setState(() {
          _userGroupRoles = roles;
        });
      }
    } catch (e) {
      debugPrint('Error loading user roles: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVeryNarrow = screenWidth < 390;
    final isNarrow = screenWidth < 450;
    
    // Use 95% of screen width on mobile, capped at 600 for larger screens
    final dialogWidth = screenWidth < 650 ? screenWidth * 0.95 : 600.0;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 8 : 24,
        vertical: 24,
      ),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          children: [
            // Header - responsive padding
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 12 : 16,
                vertical: isNarrow ? 8 : 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RSVP',
                    style: TextStyle(
                      fontSize: isNarrow ? 16 : 20,
                      fontWeight: FontWeight.bold,
                    ),
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
            const Divider(height: 1),

            // Filter Chips - compact on mobile
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 8 : 16,
                vertical: isNarrow ? 6 : 12,
              ),
              child: Row(
                children: [
                  _buildFilterChip('All', EventFilter.all),
                  SizedBox(width: isNarrow ? 4 : 8),
                  _buildFilterChip('Upcoming', EventFilter.upcoming),
                  SizedBox(width: isNarrow ? 4 : 8),
                  _buildFilterChip('Past', EventFilter.past),
                ],
              ),
            ),
            const Divider(height: 1),

            // Events List
            Expanded(
              child: StreamBuilder<List<GroupEvent>>(
                stream: _eventsStream,
                initialData: _firestoreService.getLastSeenEvents(widget.currentUserId),
                builder: (context, snapshot) {
                  // Show skeleton while loading
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const SkeletonDialogContent(itemCount: 3);
                  }
                  // Show skeleton if data is null but not waiting (transitional state)
                  if (!snapshot.hasData) {
                    return const SkeletonDialogContent(itemCount: 3);
                  }
                  // Only show empty state when we've CONFIRMED data is loaded and empty
                  if (snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No events found',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create an event to get started',
                            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    );
                  }

                  final allEvents = snapshot.data!;
                  final now = DateTime.now();
                  final startOfToday = DateTime(now.year, now.month, now.day);
                  final filteredEvents = allEvents.where((event) {
                    switch (_currentFilter) {
                      case EventFilter.upcoming:
                        // Include today and future events
                        return !event.date.isBefore(startOfToday);
                      case EventFilter.past:
                        return event.date.isBefore(startOfToday);
                      case EventFilter.all:
                        return true;
                    }
                  }).toList();

                  if (filteredEvents.isEmpty) {
                    return Center(
                      child: Text(
                        'No ${_currentFilter.name} events',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: isNarrow ? 8 : 16,
                      vertical: 12,
                    ),
                    itemCount: filteredEvents.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final event = filteredEvents[index];
                      return EventCard(
                        key: ValueKey(event.id),
                        event: event,
                        currentUserId: widget.currentUserId,
                        firestoreService: _firestoreService,
                        userGroupRoles: _userGroupRoles,
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

  Widget _buildFilterChip(String label, EventFilter filter) {
    final isSelected = _currentFilter == filter;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _currentFilter = filter;
        });
      },
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue[800],
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

class EventCard extends StatefulWidget {
  final GroupEvent event;
  final String currentUserId;
  final FirestoreService firestoreService;
  final Map<String, String> userGroupRoles;

  const EventCard({
    super.key,
    required this.event,
    required this.currentUserId,
    required this.firestoreService,
    required this.userGroupRoles,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  bool _isExpanded = false;
  late Future<Map<String, dynamic>> _statsFuture;
  Future<Map<String, Map<String, dynamic>>>? _attendeesFuture;
  
  // Cooldown tracking for reminder button
  String? _cooldownText;
  bool _onCooldown = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _statsFuture = widget.firestoreService.getEventRSVPStats(widget.event, widget.event.groupId);
    _checkReminderCooldown();
    _startTimer();
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _checkReminderCooldown();
      }
    });
  }

  @override
  void didUpdateWidget(EventCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh stats if the event object has changed (e.g. live update from firestore)
    if (oldWidget.event != widget.event) {
      _statsFuture = widget.firestoreService.getEventRSVPStats(widget.event, widget.event.groupId);
      // If expanded, we also need to refresh the attendees future next time it loads
      if (_isExpanded) {
        _attendeesFuture = widget.firestoreService.getEventAttendees(widget.event.id, widget.event.groupId);
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _checkReminderCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check bypass flag first
    final bypassEnabled = prefs.getBool('debug_bypass_reminder_limit') ?? false;
    if (bypassEnabled) {
      if (mounted) {
        setState(() {
          _onCooldown = false;
          _cooldownText = null;
        });
      }
      return;
    }
    
    final lastReminderKey = 'last_reminder_${widget.event.id}';
    final lastReminderMs = prefs.getInt(lastReminderKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final oneDayMs = 24 * 60 * 60 * 1000;
    
    if (now - lastReminderMs < oneDayMs) {
      final nextAllowed = DateTime.fromMillisecondsSinceEpoch(lastReminderMs + oneDayMs);
      final timeLeft = nextAllowed.difference(DateTime.now());
      final hoursLeft = timeLeft.inHours;
      final minsLeft = timeLeft.inMinutes % 60;
      if (mounted) {
        setState(() {
          _onCooldown = true;
          _cooldownText = hoursLeft > 0 ? '${hoursLeft}h ${minsLeft}m' : '${minsLeft}m';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _onCooldown = false;
          _cooldownText = null;
        });
      }
    }
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded && _attendeesFuture == null) {
        _attendeesFuture = widget.firestoreService.getEventAttendees(widget.event.id, widget.event.groupId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVeryNarrow = screenWidth < 390;
    final isNarrow = screenWidth < 450;
    final role = widget.userGroupRoles[widget.event.groupId] ?? 'member';
    final isCreator = widget.event.creatorId == widget.currentUserId;
    final isAdminOrOwner = role == 'owner' || role == 'admin';
    final canManage = isCreator || isAdminOrOwner;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    // If event has time, it's past if it's before now.
    // If no time, it's past if the day is before today.
    final isPastEvent = widget.event.hasTime 
        ? widget.event.date.isBefore(now)
        : widget.event.date.isBefore(startOfToday);

    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, statsSnapshot) {
        if (!statsSnapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: SkeletonBox(width: double.infinity, height: 100, borderRadius: 8),
            ),
          );
        }

        final stats = statsSnapshot.data!;
        final totalMembers = stats['totalMembers'] as int;
        final accepted = stats['accepted'] as int;
        final declined = stats['declined'] as int;
        final maybe = stats['maybe'] as int;
        final noResponse = stats['noResponse'] as int;
        final responseRate = stats['responseRate'] as double;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isNarrow ? 10 : 12),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: _toggleExpand,
                borderRadius: BorderRadius.circular(isVeryNarrow ? 8 : isNarrow ? 10 : 12),
                child: Padding(
                  padding: EdgeInsets.all(isVeryNarrow ? 8 : isNarrow ? 10 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event Title & Date
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.event.title,
                                  style: TextStyle(
                                    fontSize: isVeryNarrow ? 12 : isNarrow ? 14 : 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: isNarrow ? 2 : 4),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: isVeryNarrow ? 10 : isNarrow ? 11 : 14, color: Colors.grey[600]),
                                    SizedBox(width: isVeryNarrow ? 2 : isNarrow ? 3 : 4),
                                    Flexible(
                                      child: Text(
                                        widget.event.hasTime
                                            ? DateFormat('MMM dd, yyyy • hh:mm a').format(widget.event.date)
                                            : DateFormat('MMM dd, yyyy').format(widget.event.date),
                                        style: TextStyle(color: Colors.grey[600], fontSize: isVeryNarrow ? 10 : isNarrow ? 11 : 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (widget.event.venue != null && widget.event.venue!.isNotEmpty) ...[
                                  SizedBox(height: isVeryNarrow ? 1 : isNarrow ? 2 : 4),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, size: isVeryNarrow ? 10 : isNarrow ? 11 : 14, color: Colors.grey[600]),
                                      SizedBox(width: isVeryNarrow ? 2 : isNarrow ? 3 : 4),
                                      Expanded(
                                        child: Text(
                                          widget.event.venue!,
                                          style: TextStyle(color: Colors.grey[600], fontSize: isVeryNarrow ? 10 : isNarrow ? 11 : 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                            _isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: Colors.grey[600],
                            size: isVeryNarrow ? 18 : isNarrow ? 20 : 24,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // RSVP Stats Summary
                      Row(
                        children: [
                          _buildStatChip(
                            icon: Icons.check_circle,
                            color: Colors.green,
                            label: 'Yes',
                            count: accepted,
                            isNarrow: isNarrow,
                          ),
                          SizedBox(width: isNarrow ? 4 : 8),
                          _buildStatChip(
                            icon: Icons.cancel,
                            color: Colors.red,
                            label: 'No',
                            count: declined,
                            isNarrow: isNarrow,
                          ),
                          SizedBox(width: isNarrow ? 4 : 8),
                          _buildStatChip(
                            icon: Icons.help_outline,
                            color: Colors.orange,
                            label: 'Maybe',
                            count: maybe,
                            isNarrow: isNarrow,
                          ),
                          SizedBox(width: isNarrow ? 4 : 8),
                          _buildStatChip(
                            icon: Icons.circle_outlined,
                            color: Colors.grey,
                            label: 'Pending',
                            count: noResponse,
                            isNarrow: isNarrow,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Response Rate Progress Bar
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Response Rate',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              Text(
                                '${responseRate.toStringAsFixed(0)}% (${stats['accepted'] + stats['declined'] + stats['maybe']}/$totalMembers)',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: responseRate / 100,
                              minHeight: 8,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                responseRate > 75 ? Colors.green : responseRate > 50 ? Colors.blue : Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Action buttons for creator/owner/admin (always show, disable if no pending)
                      if (canManage && !isPastEvent) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        
                        // Your RSVP section
                        Text(
                          'YOUR RSVP',
                          style: TextStyle(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.grey[600],
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildRSVPToggleButton('Yes', Colors.green, widget.event.rsvps[widget.currentUserId] == 'Yes'),
                            const SizedBox(width: 8),
                            _buildRSVPToggleButton('Maybe', Colors.orange, widget.event.rsvps[widget.currentUserId] == 'Maybe'),
                            const SizedBox(width: 8),
                            _buildRSVPToggleButton('No', Colors.red, widget.event.rsvps[widget.currentUserId] == 'No'),
                          ],
                        ),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            // Disabled if: no pending responses OR on cooldown
                            onPressed: (noResponse > 0 && !_onCooldown)
                                ? () => _sendReminders(widget.event, stats['noResponseUserIds'])
                                : null,
                            icon: Icon(
                              _onCooldown ? Icons.timer : Icons.notifications_active, 
                              size: isVeryNarrow ? 14 : 18,
                            ),
                            label: Text(
                              _onCooldown
                                  ? 'Try again in $_cooldownText'
                                  : noResponse > 0
                                      ? (isVeryNarrow 
                                          ? 'Remind $noResponse' 
                                          : 'Send Reminder to $noResponse ${noResponse == 1 ? 'Person' : 'People'}')
                                      : 'All Responded ✓',
                              style: TextStyle(fontSize: isVeryNarrow ? 11 : 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _onCooldown 
                                  ? Colors.orange 
                                  : noResponse > 0 
                                      ? Colors.blue 
                                      : Colors.green,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade600,
                              disabledForegroundColor: Colors.white70,
                              padding: EdgeInsets.symmetric(vertical: isVeryNarrow ? 10 : 14),
                            ),
                          ),
                        ),
                      ] else if (!isPastEvent) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        
                        // User's own RSVP toggle for regular participants
                        Text(
                          'YOUR RSVP',
                          style: TextStyle(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.grey[600],
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildRSVPToggleButton('Yes', Colors.green, widget.event.rsvps[widget.currentUserId] == 'Yes'),
                            const SizedBox(width: 8),
                            _buildRSVPToggleButton('Maybe', Colors.orange, widget.event.rsvps[widget.currentUserId] == 'Maybe'),
                            const SizedBox(width: 8),
                            _buildRSVPToggleButton('No', Colors.red, widget.event.rsvps[widget.currentUserId] == 'No'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Expanded Attendee List
              if (_isExpanded) ...[
                const Divider(height: 1),
                _buildAttendeesList(widget.event, stats),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRSVPToggleButton(String status, Color color, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        onTap: isSelected ? null : () => _updateRSVP(status),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            // Solid color when selected, grey when not
            color: isSelected 
                ? color 
                : (isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected) 
                const Icon(Icons.check, size: 16, color: Colors.white),
              if (isSelected) const SizedBox(width: 4),
              Text(
                status,
                style: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade700),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateRSVP(String status) async {
    try {
      // Optimistic UI update - though the stream will handle real state
      await widget.firestoreService.rsvpEvent(widget.event.id, widget.currentUserId, status);
      
      // Refresh local stats if necessary (though the stream should trigger a rebuild)
      if (mounted) {
        setState(() {
          _statsFuture = widget.firestoreService.getEventRSVPStats(widget.event, widget.event.groupId);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating RSVP: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildStatChip({
    required IconData icon,
    required Color color,
    required String label,
    required int count,
    bool isNarrow = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isNarrow ? 6 : 10,
          horizontal: isNarrow ? 4 : 6,
        ),
        decoration: BoxDecoration(
          // More vibrant background
          color: color.withOpacity(isDark ? 0.25 : 0.15),
          borderRadius: BorderRadius.circular(isNarrow ? 8 : 10),
          border: Border.all(
            color: color.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: isNarrow ? 18 : 22),
            SizedBox(height: isNarrow ? 2 : 4),
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isNarrow ? 16 : 20,
                color: isDark ? Colors.white : color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: isNarrow ? 9 : 11, 
                color: isDark ? Colors.white70 : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendeesList(GroupEvent event, Map<String, dynamic> stats) {
    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: _attendeesFuture,
      builder: (context, attendeesSnapshot) {
        if (!attendeesSnapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: SkeletonDialogContent(itemCount: 2),
          );
        }

        final attendees = attendeesSnapshot.data!;
        final accepted = event.getUsersWithStatus('Yes');
        final declined = event.getUsersWithStatus('No');
        final maybe = event.getUsersWithStatus('Maybe');
        final noResponse = stats['noResponseUserIds'] as List<String>;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (accepted.isNotEmpty) ...[
                _buildAttendeeCategory(
                  title: '✓ Accepted (${accepted.length})',
                  color: Colors.green,
                  userIds: accepted,
                  attendees: attendees,
                ),
                const SizedBox(height: 12),
              ],
              if (maybe.isNotEmpty) ...[
                _buildAttendeeCategory(
                  title: '? Maybe (${maybe.length})',
                  color: Colors.orange,
                  userIds: maybe,
                  attendees: attendees,
                ),
                const SizedBox(height: 12),
              ],
              if (declined.isNotEmpty) ...[
                _buildAttendeeCategory(
                  title: '✗ Declined (${declined.length})',
                  color: Colors.red,
                  userIds: declined,
                  attendees: attendees,
                ),
                const SizedBox(height: 12),
              ],
              if (noResponse.isNotEmpty) ...[
                _buildAttendeeCategory(
                  title: '○ No Response (${noResponse.length})',
                  color: Colors.grey,
                  userIds: noResponse,
                  attendees: attendees,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttendeeCategory({
    required String title,
    required Color color,
    required List<String> userIds,
    required Map<String, Map<String, dynamic>> attendees,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: userIds.map((userId) {
            final user = attendees[userId];
            final name = user?['displayName'] ?? user?['email'] ?? 'Unknown';
            final photoUrl = user?['photoURL'];

            return Chip(
              avatar: UserAvatar(
                photoUrl: photoUrl,
                name: name,
                radius: 16,
              ),
              label: Text(name, style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _sendReminders(GroupEvent event, List<String> userIds) async {
    try {
      // Check 1-day limit per event
      final prefs = await SharedPreferences.getInstance();
      final lastReminderKey = 'last_reminder_${event.id}';
      final lastReminderMs = prefs.getInt(lastReminderKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final oneDayMs = 24 * 60 * 60 * 1000;
      
      // DEBUG: Set 'debug_bypass_reminder_limit' to true in SharedPreferences to bypass
      final bypassLimit = prefs.getBool('debug_bypass_reminder_limit') ?? false;
      
      if (!bypassLimit && now - lastReminderMs < oneDayMs) {
        // Too soon - show when they can send next
        final nextAllowed = DateTime.fromMillisecondsSinceEpoch(lastReminderMs + oneDayMs);
        final timeLeft = nextAllowed.difference(DateTime.now());
        final hoursLeft = timeLeft.inHours;
        final minsLeft = timeLeft.inMinutes % 60;
        final timeStr = hoursLeft > 0 ? '${hoursLeft}h ${minsLeft}m' : '${minsLeft}m';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reminder limit: Try again in $timeStr'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      await NotificationService().notifyRSVPReminder(
        memberIds: userIds,
        senderId: widget.currentUserId,
        eventId: event.id,
        eventTitle: event.title,
        groupId: event.groupId,
      );
      
      // Save timestamp
      await prefs.setInt(lastReminderKey, now);
      
      // Refresh cooldown state to update button
      _checkReminderCooldown();

      if (mounted) {
        final bypassText = bypassLimit ? ' [DEBUG: Bypass enabled]' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminders sent to ${userIds.length} ${userIds.length == 1 ? 'person' : 'people'}$bypassText'),
            backgroundColor: bypassLimit ? Colors.purple : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending reminders: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
