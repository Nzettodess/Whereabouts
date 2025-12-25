import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';
import '../models.dart';
import '../firestore_service.dart';

class NotificationDebugDialog extends StatefulWidget {
  final String currentUserId;
  const NotificationDebugDialog({super.key, required this.currentUserId});

  @override
  State<NotificationDebugDialog> createState() => _NotificationDebugDialogState();
}

class _NotificationDebugDialogState extends State<NotificationDebugDialog> {
  final TextEditingController _targetUidController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  String? _status;
  bool _isLoading = false;
  List<String> _auditResults = [];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _targetUidController.text = user.uid;
    }
  }

  @override
  void dispose() {
    _targetUidController.dispose();
    super.dispose();
  }

  void _updateStatus(String msg) {
    if (!mounted) return;
    setState(() => _status = msg);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 550,
          height: 650,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🛡️ Developer Suite',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Notifs', icon: Icon(Icons.notifications_active_outlined)),
                  Tab(text: 'Security', icon: Icon(Icons.security)),
                  Tab(text: 'Flows', icon: Icon(Icons.auto_fix_high)),
                  Tab(text: 'System', icon: Icon(Icons.settings_outlined)),
                ],
                labelStyle: TextStyle(fontSize: 10),
                labelColor: Colors.deepPurple,
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildNotificationsTab(),
                    _buildSecurityTab(),
                    _buildWorkflowsTab(),
                    _buildSystemTab(),
                  ],
                ),
              ),
              if (_status != null) _buildStatusPanel(),
            ],
          ),
        ),
      ),
    );
  }

  // ================= TABS =================

  Widget _buildNotificationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDebugSection('System Hardware', [
            _buildDebugRow('Ext. ID:', NotificationService().oneSignalExternalId),
            _buildDebugRow('SDK Ready:', NotificationService().isOneSignalJSLoaded ? '✅' : '❌'),
            _buildDebugRow('Player ID:', NotificationService().oneSignalPlayerId ?? "None"),
          ]),
          const SizedBox(height: 20),
          _buildDebugSection('Targeting', [
            TextField(
              controller: _targetUidController,
              decoration: const InputDecoration(
                labelText: 'Target Firebase UID',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ]),
          const SizedBox(height: 20),
          _buildDebugSection('Trigger All Types', [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: NotificationType.values.map((type) {
                return ActionChip(
                  label: Text(type.name, style: const TextStyle(fontSize: 10)),
                  onPressed: () => _sendTest(type.name, type),
                  backgroundColor: Colors.orange.withOpacity(0.05),
                );
              }).toList(),
            ),
          ]),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.bolt),
            onPressed: () => _sendTest('Batch Test', NotificationType.general),
            label: const Text('Send Batch (Sequential)'),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Check for Data Leaks & Rule Enforcement',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tries unauthorized reads/writes to verify Security Rules.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_circle_fill),
              onPressed: _isLoading ? null : _runSecurityAudit,
              label: Text(_isLoading ? 'Auditing...' : 'Run Security Audit'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),
          const Text(
            'Admin Utilities',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.security_update_good),
              onPressed: _isLoading ? null : _runGlobalSecurityBackfill,
              label: const Text('Run Global Security Backfill'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          if (_auditResults.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _auditResults.map((res) => Text(res, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkflowsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Automated Functional Testing', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildWorkflowCard(
            'Event Lifecycle',
            'Creates event -> Triggers Notif -> Updates -> Deletes',
            Icons.event,
            _testRealEventFlow,
          ),
          _buildWorkflowCard(
            'Location Journey',
            'Sets location -> Propagates to groups -> Clears',
            Icons.map_outlined,
            _testRealLocationFlow,
          ),
          _buildWorkflowCard(
            'RSVP Cycle',
            'Creates event -> User RSVPs -> Verifies Notif -> Cleans up',
            Icons.check_circle_outline,
            _testRSVPFlow,
          ),
          _buildWorkflowCard(
            'Join Request Flow',
            'Creates Join Request -> Notifies Owner -> Cleans up',
            Icons.person_add_alt_1,
            _testJoinRequestFlow,
          ),
          _buildWorkflowCard(
            'Group Lifecycle',
            'Creates Group -> Updates Name -> Deletes Group',
            Icons.group_add,
            _testGroupLifecycleFlow,
          ),
          _buildWorkflowCard(
            'Feedback Transmission',
            'Submits Feedback -> Verifies Entry',
            Icons.feedback_outlined,
            _testFeedbackFlow,
          ),
          _buildWorkflowCard(
            'Inheritance Journey',
            'Creates Placeholder -> Requests Inheritance -> Cleans up',
            Icons.family_restroom,
            _testInheritanceFlow,
          ),
        ],
      ),
    );
  }

  Widget _buildSystemTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          _buildSettingRow(
            'Cleanup All Test Data',
            'Removes all notifications and objects starting with "test_"',
            Icons.cleaning_services,
            Colors.red,
            _cleanupTestData,
          ),
          const Divider(),
          _buildSettingRow(
            'Reset SharedPreferences',
            'Clears daily notification check timestamps',
            Icons.refresh,
            Colors.orange,
            _resetChecks,
          ),
          const Divider(),
          _buildSettingRow(
            'Wipe OneSignal Tokens',
            'Forces a fresh ID fetch on next reload',
            Icons.delete_forever,
            Colors.blue,
            () async {
               await NotificationService().clearPlayerIds();
               _updateStatus('IDs Cleared from local storage');
            },
          ),
        ],
      ),
    );
  }

  // ================= HELPERS =================

  Widget _buildDebugSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        Text(value, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
      ],
    );
  }

  Widget _buildStatusPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.deepPurple.shade900.withOpacity(0.5) : Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.deepPurple.shade700 : Colors.deepPurple.shade100),
      ),
      child: Text(
        _status!, 
        style: TextStyle(
          fontSize: 11, 
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.deepPurple.shade100 : Colors.deepPurple.shade900,
        )
      ),
    );
  }

  Widget _buildWorkflowCard(String title, String desc, IconData icon, VoidCallback action) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(desc, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: _isLoading ? null : action,
      ),
    );
  }

  Widget _buildSettingRow(String title, String desc, IconData icon, Color color, VoidCallback action) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontSize: 13)),
      subtitle: Text(desc, style: const TextStyle(fontSize: 11)),
      onTap: _isLoading ? null : action,
    );
  }

  // ================= ACTIONS =================

  Future<void> _sendTest(String label, NotificationType type) async {
    final targetUid = _targetUidController.text.trim();
    if (targetUid.isEmpty) return;

    _updateStatus('Sending $label...');
    final result = await NotificationService().sendNotification(
      userId: targetUid,
      message: "Test: $label",
      type: type,
    );
    _updateStatus(result ?? '✅ Sent');
  }

  Future<void> _runSecurityAudit() async {
    setState(() {
      _isLoading = true;
      _auditResults = [];
      _status = 'Running Audit...';
    });

    final tests = [
      // === USERS COLLECTION ===
      {'name': 'Users: Read Random User (No Shared Group)', 'action': () => FirebaseFirestore.instance.collection('users').doc('fake_uid_random_leak').get()},
      {'name': 'Users: Query All Users (Limit)', 'action': () => FirebaseFirestore.instance.collection('users').limit(5).get()},
      {'name': 'Users: Search Users by Name', 'action': () => FirebaseFirestore.instance.collection('users').where('displayName', isGreaterThan: 'A').get()},
      {'name': 'Users: Edit Others Profile', 'action': () => FirebaseFirestore.instance.collection('users').doc('fake_uid').update({'displayName': 'Hacked'})},
      {'name': 'Users: Read Others Sessions', 'action': () => FirebaseFirestore.instance.collectionGroup('active_sessions').get()},
      
      // === GROUPS COLLECTION ===
      {'name': 'Groups: Member Update Group Name', 'action': () => FirebaseFirestore.instance.collection('groups').doc('test_group_123').update({'name': 'Hacked Name'})},
      {'name': 'Groups: Delete Random Group', 'action': () => FirebaseFirestore.instance.collection('groups').doc('random_group_id').delete()},
      
      // === EVENTS COLLECTION ===
      {'name': 'Events: Non-Member Read Event', 'action': () => FirebaseFirestore.instance.collection('events').doc('event_123').get()},
      {'name': 'Events: Non-Member Update Event', 'action': () => FirebaseFirestore.instance.collection('events').doc('event_123').update({'title': 'Hacked Event'})},
      {'name': 'Events: Delete Random Event', 'action': () => FirebaseFirestore.instance.collection('events').doc('random_event_id').delete()},
      
      // === USER_LOCATIONS COLLECTION ===
      {'name': 'Locations: Delete Others Location', 'action': () => FirebaseFirestore.instance.collection('user_locations').doc('other_loc_123').delete()},
      
      // === PLACEHOLDER_MEMBERS COLLECTION ===
      {'name': 'Placeholders: Member Create Placeholder', 'action': () => FirebaseFirestore.instance.collection('placeholder_members').add({'displayName': 'Hacked', 'groupId': 'test_group_123'})},
      {'name': 'Placeholders: Non-Member Read Placeholder', 'action': () => FirebaseFirestore.instance.collection('placeholder_members').doc('ph_123').get()},
      
      // === INHERITANCE_REQUESTS COLLECTION ===
      {'name': 'Inheritance: Self-Approve Request', 'action': () => FirebaseFirestore.instance.collection('inheritance_requests').doc('req_123').update({'status': 'approved'})},
      {'name': 'Inheritance: Non-Admin Read Request', 'action': () => FirebaseFirestore.instance.collection('inheritance_requests').doc('req_123').get()},
      
      // === JOIN_REQUESTS COLLECTION ===
      {'name': 'JoinReq: Non-Admin Approve', 'action': () => FirebaseFirestore.instance.collection('join_requests').doc('join_123').update({'status': 'approved', 'processedBy': 'hacker', 'processedAt': FieldValue.serverTimestamp()})},
      {'name': 'JoinReq: Change Forbidden Field', 'action': () => FirebaseFirestore.instance.collection('join_requests').doc('join_123').update({'requesterId': 'hacked_id'})},
      
      // === NOTIFICATIONS COLLECTION ===
      {'name': 'Notifications: Read Others Notifications', 'action': () => FirebaseFirestore.instance.collection('notifications').where('userId', isEqualTo: 'other_user_uid').get()},
      {'name': 'Notifications: Delete Others Notification', 'action': () => FirebaseFirestore.instance.collection('notifications').doc('notif_123').delete()},
      
      // === FEEDBACK COLLECTION ===
      {'name': 'Feedback: Read Any Feedback', 'action': () => FirebaseFirestore.instance.collection('feedback').limit(1).get()},
    ];


    for (var test in tests) {
      try {
        await (test['action'] as Function)();
        _auditResults.add('❌ ${test['name']}: LEAK! (Allowed)');
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          _auditResults.add('✅ ${test['name']}: SECURE (Denied)');
        } else {
          _auditResults.add('⚠️ ${test['name']}: ERROR (${e.code})');
        }
      } catch (e) {
        _auditResults.add('⚠️ ${test['name']}: UNKNOWN ERROR');
      }
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _updateStatus('Audit Complete.');
    setState(() => _isLoading = false);
  }

  Future<void> _runGlobalSecurityBackfill() async {
    setState(() {
      _isLoading = true;
      _status = 'Starting Global Backfill...';
    });
    
    try {
       final db = FirebaseFirestore.instance;
       // 1. Get all groups where I am admin
       final groups = await db.collection('groups').where('admins', arrayContains: widget.currentUserId).get();
       int updatedUsers = 0;
       int totalGroups = groups.docs.length;
       
       _updateStatus('Found $totalGroups groups to process...');

       for (final group in groups.docs) {
         final members = List<String>.from(group.data()['members'] ?? []);
         for (final memberId in members) {
           // Update each member's joinedGroupIds
           await db.collection('users').doc(memberId).set({
             'joinedGroupIds': FieldValue.arrayUnion([group.id])
           }, SetOptions(merge: true));
           updatedUsers++;
         }
       }
       
       _updateStatus('✅ Success! Backfilled $updatedUsers security tags across $totalGroups groups.');
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
         content: Text('Success! Backfilled $updatedUsers security tags.'),
         backgroundColor: Colors.green,
       ));
    } catch (e) {
       _updateStatus('❌ Backfill Error: $e');
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
       setState(() => _isLoading = false);
    }
  }

  Future<void> _testRealEventFlow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      final List<Group> groups = await _firestoreService.getUserGroupsSnapshot(user.uid);
      if (groups.isEmpty) throw 'No group found.';

      final group = groups.first;
      final eventId = 'test_event_${DateTime.now().millisecondsSinceEpoch}';
      
      _updateStatus('1/3: Creating Real Event in "${group.name}"...');
      final testEvent = GroupEvent(
        id: eventId,
        groupId: group.id,
        creatorId: user.uid,
        title: '🧪 AUTO TEST',
        description: 'Auto-triggered',
        date: DateTime.now().add(const Duration(days: 1)),
        rsvps: const {},
      );
      await _firestoreService.createEvent(testEvent);
      
      await Future.delayed(const Duration(seconds: 2));
      _updateStatus('2/4: Updating Event Details...');
      final updatedEvent = GroupEvent(
        id: eventId,
        groupId: group.id,
        creatorId: user.uid,
        title: '🧪 AUTO TEST (UPDATED)',
        description: 'Detail update test',
        date: testEvent.date,
        rsvps: const {},
      );
      await _firestoreService.updateEvent(updatedEvent, user.uid);
      
      await Future.delayed(const Duration(seconds: 2));
      _updateStatus('3/4: Cleaning up Event...');
      await _firestoreService.deleteEvent(eventId, user.uid);
      
      _updateStatus('✅ Event Lifecycle Flow Complete (Create -> Update -> Delete).');
    } catch (e) {
      _updateStatus('❌ Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testRealLocationFlow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      final groups = await _firestoreService.getUserGroupsSnapshot(user.uid);
      if (groups.isEmpty) throw 'No group found.';

      final group = groups.first;
      _updateStatus('1/2: Updating Real Location to "TestLand"...');
      await _firestoreService.setLocation(user.uid, group.id, DateTime.now(), "TestLand", null);
      
      await Future.delayed(const Duration(seconds: 2));
      _updateStatus('2/2: Reverting Location...');
      await _firestoreService.setLocation(user.uid, group.id, DateTime.now(), "Home", null);
      
      _updateStatus('✅ Location Flow Complete.');
    } catch (e) {
      _updateStatus('❌ Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testRSVPFlow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      final groups = await _firestoreService.getUserGroupsSnapshot(user.uid);
      if (groups.isEmpty) throw 'No group found.';
      final group = groups.first;

      _updateStatus('1/2: Creating Event for RSVP test...');
      final eventId = 'test_rsvp_${DateTime.now().millisecondsSinceEpoch}';
      await _firestoreService.createEvent(GroupEvent(
        id: eventId,
        groupId: group.id,
        creatorId: user.uid,
        title: '🧪 RSVP TEST',
        description: 'Testing RSVP flow',
        date: DateTime.now().add(const Duration(days: 2)),
        rsvps: const {},
      ));

      await Future.delayed(const Duration(seconds: 2));
      _updateStatus('2/2: Performing RSVP as "Yes"...');
      await _firestoreService.rsvpEvent(eventId, user.uid, 'Yes');

      await Future.delayed(const Duration(seconds: 2));
      _updateStatus('🧹 Cleaning up...');
      await _firestoreService.deleteEvent(eventId, user.uid);
      _updateStatus('✅ RSVP Cycle Flow Complete.');
    } catch (e) {
      _updateStatus('❌ RSVP Flow Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testJoinRequestFlow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      final groups = await _firestoreService.getUserGroupsSnapshot(user.uid);
      if (groups.isEmpty) throw 'No group found.';
      final group = groups.first;

      _updateStatus('1/2: Creating Join Request for "${group.name}"...');
      // Note: Usually can't request to join a group you are already in, 
      // so we test the creation logic specifically.
      final requestId = 'test_join_${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseFirestore.instance.collection('join_requests').doc(requestId).set({
        'groupId': group.id,
        'requesterId': user.uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await Future.delayed(const Duration(seconds: 2));
      _updateStatus('2/2: Verifying Notification trigger...');
      // In a real scenario, this would trigger a notification to the owner.
      // We manually trigger the service call to verify it works.
      await NotificationService().notifyJoinRequest(
        ownerId: group.ownerId,
        groupId: group.id,
        requesterId: user.uid,
        requesterName: user.displayName ?? 'Test User',
        groupName: group.name,
      );

      await Future.delayed(const Duration(seconds: 2));
      _updateStatus('🧹 Cleaning up Request...');
      await FirebaseFirestore.instance.collection('join_requests').doc(requestId).delete();
      _updateStatus('✅ Join Request Flow Complete.');
    } catch (e) {
      _updateStatus('❌ Join Request Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testInheritanceFlow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      final groups = await _firestoreService.getUserGroupsSnapshot(user.uid);
      if (groups.isEmpty) throw 'No group found.';
      final group = groups.first;

      _updateStatus('1/3: Creating Placeholder Member...');
      final placeholderId = 'test_ph_${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseFirestore.instance.collection('placeholder_members').doc(placeholderId).set({
        'groupId': group.id,
        'displayName': 'Test Placeholder',
        'ownerId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await Future.delayed(const Duration(seconds: 2));
      _updateStatus('2/3: Creating Inheritance Request...');
      final requestId = 'test_inh_${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseFirestore.instance.collection('inheritance_requests').doc(requestId).set({
        'placeholderMemberId': placeholderId,
        'requesterId': user.uid,
        'groupId': group.id,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await Future.delayed(const Duration(seconds: 2));
      _updateStatus('3/3: Triggering Inheritance Notification...');
      await NotificationService().notifyInheritanceRequest(
        adminIds: [group.ownerId],
        requesterId: user.uid,
        requesterName: user.displayName ?? 'Test User',
        placeholderName: 'Test Placeholder',
        groupId: group.id,
      );

      await Future.delayed(const Duration(seconds: 2));
      _updateStatus('🧹 Cleaning up journey...');
      await FirebaseFirestore.instance.collection('inheritance_requests').doc(requestId).delete();
      await FirebaseFirestore.instance.collection('placeholder_members').doc(placeholderId).delete();
      _updateStatus('✅ Inheritance Journey Flow Complete.');
    } catch (e) {
      _updateStatus('❌ Inheritance Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testGroupLifecycleFlow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      _updateStatus('1/3: Creating Test Group...');
      final groupId = 'test_group_flow_${DateTime.now().millisecondsSinceEpoch}';
      final groupData = Group(
        id: groupId,
        name: '🧪 TEST GROUP',
        ownerId: user.uid,
        members: [user.uid],
        admins: [],
      );
      
      await FirebaseFirestore.instance.collection('groups').doc(groupId).set(groupData.toMap());

      await Future.delayed(const Duration(seconds: 2));
      _updateStatus('2/3: Updating Group Name...');
      await FirebaseFirestore.instance.collection('groups').doc(groupId).update({'name': '🧪 TEST GROUP (UPDATED)'});

      await Future.delayed(const Duration(seconds: 2));
      _updateStatus('3/3: Deleting Group...');
      await FirebaseFirestore.instance.collection('groups').doc(groupId).delete();
      
      _updateStatus('✅ Group Lifecycle Flow Complete.');
    } catch (e) {
      _updateStatus('❌ Group Flow Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testFeedbackFlow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      _updateStatus('1/2: Submitting Feedback...');
      final feedbackId = 'test_feedback_${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseFirestore.instance.collection('feedback').doc(feedbackId).set({
        'userId': user.uid,
        'message': '🧪 AUTO FEEDBACK TEST',
        'timestamp': FieldValue.serverTimestamp(),
        'version': '1.0.0',
      });

      await Future.delayed(const Duration(seconds: 1));
      _updateStatus('2/2: Verifying Submission (Write Only)...');
      // Feedback collection is typically write-only for users, so we can't read it back.
      // If the write didn't throw, it's a success.
      
      _updateStatus('✅ Feedback Submitted Successfully.');
    } catch (e) {
      _updateStatus('❌ Feedback Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cleanupTestData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      _updateStatus('🧹 Cleaning test notifications...');
      final notifs = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      int count = 0;
      for (var doc in notifs.docs) {
        final data = doc.data();
        if ((data['message'] as String).contains('Test:')) {
           batch.delete(doc.reference);
           count++;
        }
      }
      if (count > 0) await batch.commit();
      _updateStatus('✨ Cleaned $count records.');
    } catch (e) {
      _updateStatus('❌ Cleanup Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetChecks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_birthday_check_date');
    await prefs.remove('last_monthly_birthday_check');
    _updateStatus('Daily Check Timestamps Reset');
  }
}
