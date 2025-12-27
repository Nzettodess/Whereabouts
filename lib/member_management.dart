import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'models/join_request.dart';
import 'firestore_service.dart';
import 'edit_member_dialog.dart';
import 'widgets/user_profile_dialog.dart';
import 'theme.dart';
import 'services/notification_service.dart';

class MemberManagement extends StatefulWidget {
  final Group group;
  final String currentUserId;

  const MemberManagement({
    super.key,
    required this.group,
    required this.currentUserId,
  });

  @override
  State<MemberManagement> createState() => _MemberManagementState();
}

class _MemberManagementState extends State<MemberManagement> {
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, Map<String, dynamic>> _memberDetails = {};
  late Group _group;
  StreamSubscription<List<Map<String, dynamic>>>? _usersSubscription;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _subscribeToMembers();
  }

  @override
  void dispose() {
    _usersSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToMembers() {
    _usersSubscription?.cancel();
    if (_group.members.isEmpty) return;

    // Use batched stream for efficient loading
    _usersSubscription = _firestoreService.getUsersByIdsStream(_group.members).listen((usersData) {
      if (mounted) {
        setState(() {
          for (final user in usersData) {
            final uid = user['uid'] as String?;
            if (uid != null) {
              _memberDetails[uid] = user;
            }
          }
        });
      }
    });
  }

  Future<void> _refreshGroup() async {
    final doc = await FirebaseFirestore.instance.collection('groups').doc(_group.id).get();
    if (doc.exists) {
      setState(() {
        _group = Group.fromFirestore(doc);
      });
      // Re-subscribe to fetch new members if any
      _subscribeToMembers();
    }
  }

  bool get isOwner => _group.ownerId == widget.currentUserId;
  bool get isAdmin => _group.admins.contains(widget.currentUserId);
  bool get canManage => isOwner || isAdmin;

  /// Returns sorted member list: Owner first, then Admins, then Members.
  /// Within each tier, sorted alphabetically by display name.
  List<String> _getSortedMembers() {
    final members = List<String>.from(_group.members);
    
    members.sort((a, b) {
      final aIsOwner = a == _group.ownerId;
      final bIsOwner = b == _group.ownerId;
      final aIsAdmin = _group.admins.contains(a);
      final bIsAdmin = _group.admins.contains(b);
      
      // Priority: Owner (0) > Admin (1) > Member (2)
      int aPriority = aIsOwner ? 0 : (aIsAdmin ? 1 : 2);
      int bPriority = bIsOwner ? 0 : (bIsAdmin ? 1 : 2);
      
      if (aPriority != bPriority) {
        return aPriority - bPriority;
      }
      
      // Same role: sort alphabetically by display name
      final aName = (_memberDetails[a]?['displayName'] ?? _memberDetails[a]?['email'] ?? '').toString().toLowerCase();
      final bName = (_memberDetails[b]?['displayName'] ?? _memberDetails[b]?['email'] ?? '').toString().toLowerCase();
      return aName.compareTo(bName);
    });
    
    return members;
  }

  void _showUserProfile(String memberId, Map<String, dynamic>? userData) {
    if (userData == null) return;
    
    final name = userData['displayName'] ?? userData['email'] ?? 'Unknown User';
    final photoUrl = userData['photoURL'];
    final isThisOwner = memberId == _group.ownerId;
    final isThisAdmin = _group.admins.contains(memberId);
    
    // Determine edit permission (same logic as _buildTrailingActions)
    bool canEdit = false;
    if (isOwner) {
      canEdit = !isThisOwner; // Owner can edit everyone but self (self edit via profile)
    } else if (isAdmin) {
      canEdit = !isThisOwner && !isThisAdmin; // Admin can edit members only
    }
    
    showDialog(
      context: context,
      builder: (context) => UserProfileDialog(
        displayName: name,
        photoUrl: photoUrl,
        defaultLocation: userData['defaultLocation'],
        birthday: userData['birthday'] != null ? (userData['birthday'] as Timestamp).toDate() : null,
        hasLunarBirthday: userData['hasLunarBirthday'] ?? false,
        lunarBirthdayMonth: userData['lunarBirthdayMonth'],
        lunarBirthdayDay: userData['lunarBirthdayDay'],
        canEdit: canEdit,
        onEdit: () {
          _showEditMemberDialog(memberId);
        },
      ),
    );
  }

  Widget _buildTrailingActions(String memberId, bool isThisOwner, bool isThisAdmin, bool isCurrentUser) {
    // Always return a fixed-width widget to ensure consistent alignment
    const double trailingWidth = 40.0;
    
    // Can't edit yourself - return empty placeholder for alignment
    if (isCurrentUser) {
      return const SizedBox(width: trailingWidth);
    }
    
    // Determine hierarchy: Owner > Admin > Member
    // canEditThis = true if current user has higher rank than target
    bool canEditThis = false;
    
    if (isOwner) {
      // Owner can edit everyone except themselves
      canEditThis = !isThisOwner;
    } else if (isAdmin) {
      // Admin can only edit Members (not Owner, not other Admins)
      canEditThis = !isThisOwner && !isThisAdmin;
    } else {
      // Regular member can't edit anyone
      canEditThis = false;
    }
    
    // Members don't see any options button
    if (!canManage) {
      // Return empty space to maintain alignment
      return const SizedBox(width: trailingWidth);
    }
    
    // If user can't edit this target (e.g., admin looking at owner or other admin)
    if (!canEditThis) {
      // Hide button completely to avoid confusion
      return const SizedBox(width: trailingWidth);
    }
    
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _showEditMemberDialog(memberId);
            break;
          case 'promote':
            _promoteToAdmin(memberId);
            break;
          case 'demote':
            _demoteAdmin(memberId);
            break;
          case 'remove':
            _removeMember(memberId);
            break;
          case 'transfer':
            _transferOwnership(memberId);
            break;
        }
      },
      itemBuilder: (_) => [
        // Edit Details - can edit if hierarchy allows
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, color: Colors.teal),
              SizedBox(width: 8),
              Text('Edit Details'),
            ],
          ),
        ),
        // Promote - only show for non-admins
        if (!isThisAdmin)
          const PopupMenuItem(
            value: 'promote',
            child: Row(
              children: [
                Icon(Icons.arrow_upward, color: Colors.blue),
                SizedBox(width: 8),
                Text('Promote to Admin'),
              ],
            ),
          ),
        // Demote - only show for admins (Owner only can demote)
        if (isThisAdmin && !isThisOwner && isOwner)
          const PopupMenuItem(
            value: 'demote',
            child: Row(
              children: [
                Icon(Icons.arrow_downward, color: Colors.orange),
                SizedBox(width: 8),
                Text('Remove Admin'),
              ],
            ),
          ),
        // Remove from group
        const PopupMenuItem(
          value: 'remove',
          child: Row(
            children: [
              Icon(Icons.person_remove, color: Colors.red),
              SizedBox(width: 8),
              Text('Remove from Group'),
            ],
          ),
        ),
        // Transfer - only owner can transfer
        if (isOwner)
          const PopupMenuItem(
            value: 'transfer',
            child: Row(
              children: [
                Icon(Icons.swap_horiz, color: Colors.purple),
                SizedBox(width: 8),
                Text('Transfer Ownership'),
              ],
            ),
          ),
      ],
    );
  }

  void _showEditMemberDialog(String memberId) {
    showDialog(
      context: context,
      builder: (_) => EditMemberDialog(
        memberId: memberId,
        memberDetails: _memberDetails[memberId] ?? {},
        groupId: _group.id,
        onSaved: () {
          // Stream updates automatically
        },
      ),
    );
  }

  Future<void> _promoteToAdmin(String memberId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Promote to Admin?'),
        content: Text('Make ${_memberDetails[memberId]?['displayName'] ?? 'this user'} an admin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Promote')),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('groups').doc(_group.id).update({
        'admins': FieldValue.arrayUnion([memberId]),
      });
      await _refreshGroup();
      
      // Notify user
      await NotificationService().notifyRoleChange(
        userId: memberId,
        groupName: _group.name,
        roleAction: 'promoted to admin of',
        groupId: _group.id,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User promoted to admin')),
        );
      }
    }
  }

  Future<void> _demoteAdmin(String memberId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Admin?'),
        content: Text('Remove admin rights from ${_memberDetails[memberId]?['displayName'] ?? 'this user'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('groups').doc(_group.id).update({
        'admins': FieldValue.arrayRemove([memberId]),
      });
      await _refreshGroup();
      
      // Notify user
      await NotificationService().notifyRoleChange(
        userId: memberId,
        groupName: _group.name,
        roleAction: 'removed as admin from',
        groupId: _group.id,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin rights removed')),
        );
      }
    }
  }

  Future<void> _removeMember(String memberId) async {
    // Double confirmation
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text('Remove ${_memberDetails[memberId]?['displayName'] ?? 'this user'} from the group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm1 != true) return;

    // Second confirmation
    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('This action cannot be undone. The user will lose access to this group.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Yes, Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm2 != true) return;

    // Clean up user's data from this group (RSVPs, locations)
    final firestoreService = FirestoreService();
    await firestoreService.cleanupUserFromGroup(memberId, _group.id);

    // Remove from members and admins
    await FirebaseFirestore.instance.collection('groups').doc(_group.id).update({
      'members': FieldValue.arrayRemove([memberId]),
      'admins': FieldValue.arrayRemove([memberId]),
    });
    await _refreshGroup();
    _memberDetails.remove(memberId);
    
    // Notify user
    await NotificationService().notifyMemberRemoved(
      userId: memberId,
      groupName: _group.name,
      groupId: _group.id,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member removed from group')),
      );
    }
  }

  Future<void> _transferOwnership(String memberId) async {
    // Double confirmation for ownership transfer
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Transfer Ownership?'),
        content: Text('Transfer group ownership to ${_memberDetails[memberId]?['displayName'] ?? 'this user'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Transfer', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    if (confirm1 != true) return;

    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Are you absolutely sure?'),
        content: const Text('You will lose owner privileges and become a regular admin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Yes, Transfer', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    if (confirm2 != true) return;

    // Transfer ownership
    await FirebaseFirestore.instance.collection('groups').doc(_group.id).update({
      'ownerId': memberId,
      'admins': FieldValue.arrayUnion([widget.currentUserId, memberId]),
    });
    await _refreshGroup();
    
    // Notify new owner
    await NotificationService().notifyRoleChange(
      userId: memberId,
      groupName: _group.name,
      roleAction: 'made the owner of',
      groupId: _group.id,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ownership transferred')),
      );
      Navigator.pop(context); // Close dialog after transfer
    }
  }

  Widget _buildJoinRequestTile(JoinRequest request) {
    // If name is generic 'Someone' or 'Unknown User', try to fetch the real name
    // (This requires read permission on the user profile, which public profiles allow)
    Widget buildName(String cachedName) {
      if (cachedName != 'Someone' && cachedName != 'Unknown User') {
        return Text(
          cachedName,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        );
      }

      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(request.requesterId).get(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final name = data['displayName'] ?? data['email'] ?? 'Someone';
            return Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            );
          }
          return Text(
            cachedName,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          );
        },
      );
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.getPendingBg(context),
            child: Icon(Icons.person_outline, size: 18, color: AppColors.getPendingAccent(context)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildName(request.requesterName),
                Text(
                  'Requested ${DateFormat('MMM d').format(request.createdAt)}',
                  style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
          // Approve button
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
            tooltip: 'Approve',
            onPressed: () => _processJoinRequest(request, true),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          // Reject button
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red, size: 28),
            tooltip: 'Reject',
            onPressed: () => _processJoinRequest(request, false),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }

  Future<void> _processJoinRequest(JoinRequest request, bool approve) async {
    
    // Use requesterName already stored in the join request document
    // (Fetching the user doc would fail because admin doesn't share groups with requester yet)
    final requesterName = request.requesterName;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(approve ? 'Approve Join Request?' : 'Reject Join Request?'),
        content: Text(approve 
          ? '$requesterName will be added to the group and can access group data.'
          : '$requesterName will be notified that their request was declined.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await _firestoreService.processJoinRequest(
          request.id, 
          approve, 
          widget.currentUserId,
        );
        
        if (approve) {
          await _refreshGroup();

        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(approve 
                ? '$requesterName has been added to the group!' 
                : 'Join request rejected.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 450;
    final isVeryNarrow = screenWidth < 380;
    
    // Use 95% of screen width on mobile, capped at 500 for larger screens
    final dialogWidth = screenWidth < 550 ? screenWidth * 0.95 : 500.0;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isVeryNarrow ? 8 : (isNarrow ? 12 : 24),
        vertical: 24,
      ),
      child: Container(
        width: dialogWidth,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: EdgeInsets.all(isVeryNarrow ? 8 : (isNarrow ? 12 : 16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - responsive
            Row(
              children: [
                Icon(Icons.group, color: Colors.blue, size: isNarrow ? 18 : 24),
                SizedBox(width: isNarrow ? 6 : 8),
                Expanded(
                  child: Text(
                    'Members - ${_group.name}',
                    style: TextStyle(
                      fontSize: isNarrow ? 14 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  iconSize: isNarrow ? 20 : 24,
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: isNarrow ? 32 : 40,
                    minHeight: isNarrow ? 32 : 40,
                  ),
                ),
              ],
            ),
            SizedBox(height: isNarrow ? 4 : 8),
            Text(
              '${_group.members.length} member${_group.members.length != 1 ? 's' : ''}',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: isNarrow ? 11 : 14,
              ),
            ),
            const Divider(),
            
            // Join Requests Section (collapsible, only for owner/admin)
            if (canManage)
              StreamBuilder<List<JoinRequest>>(
                stream: _firestoreService.getPendingJoinRequests(_group.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  
                  final requests = snapshot.data!;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.getPendingBg(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.getPendingBorder(context)),
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      leading: Icon(Icons.person_add, color: AppColors.getPendingAccent(context), size: 20),
                      title: Text(
                        'Join Requests (${requests.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.getPendingAccent(context),
                          fontSize: 14,
                        ),
                      ),
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 150),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: requests.length,
                            itemBuilder: (context, index) => _buildJoinRequestTile(requests[index]),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            
            Expanded(
              child: Builder(
                builder: (context) {
                  final sortedMembers = _getSortedMembers();
                  return ListView.builder(
                    itemCount: sortedMembers.length,
                    itemBuilder: (context, index) {
                      final memberId = sortedMembers[index];
                      final member = _memberDetails[memberId];
                      final name = member?['displayName'] ?? member?['email'] ?? 'Loading...';
                      final email = member?['email'] ?? '';
                      final isThisOwner = memberId == _group.ownerId;
                      final isThisAdmin = _group.admins.contains(memberId);
                      final isCurrentUser = memberId == widget.currentUserId;

                      return ListTile(
                        onTap: () => _showUserProfile(memberId, member),
                        leading: CircleAvatar(
                          backgroundColor: isThisOwner 
                            ? Colors.amber[100] 
                            : isThisAdmin 
                              ? Colors.blue[100] 
                              : Colors.grey[200],
                          child: Icon(
                            isThisOwner 
                              ? Icons.star 
                              : isThisAdmin 
                                ? Icons.admin_panel_settings 
                                : Icons.person,
                            color: isThisOwner 
                              ? Colors.amber[700] 
                              : isThisAdmin 
                                ? Colors.blue[700] 
                                : Colors.grey[600],
                          ),
                        ),
                        title: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                name, 
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            if (isCurrentUser) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text('You', style: TextStyle(fontSize: 8, color: Colors.green[700], fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (email.isNotEmpty) 
                              Text(email, style: const TextStyle(fontSize: 12)),
                            Text(
                              isThisOwner ? 'Owner' : isThisAdmin ? 'Admin' : 'Member',
                              style: TextStyle(
                                fontSize: 11,
                                color: isThisOwner ? Colors.amber[700] : isThisAdmin ? Colors.blue : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        trailing: _buildTrailingActions(memberId, isThisOwner, isThisAdmin, isCurrentUser),
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
