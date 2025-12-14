import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'models/join_request.dart';
import 'firestore_service.dart';
import 'edit_member_dialog.dart';
import 'widgets/user_profile_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _loadMemberDetails();
  }

  Future<void> _loadMemberDetails() async {
    for (final memberId in _group.members) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(memberId).get();
      if (doc.exists) {
        setState(() {
          _memberDetails[memberId] = doc.data() as Map<String, dynamic>;
        });
      }
    }
  }

  Future<void> _refreshGroup() async {
    final doc = await FirebaseFirestore.instance.collection('groups').doc(_group.id).get();
    if (doc.exists) {
      setState(() {
        _group = Group.fromFirestore(doc);
      });
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
    
    // Members see greyed out icon for higher roles
    if (!canManage) {
      // Show greyed out icon to indicate they can view but not manage
      return const SizedBox(
        width: trailingWidth,
        child: Icon(Icons.more_vert, color: Colors.grey),
      );
    }
    
    // If user can't edit this target (e.g., admin looking at another admin)
    if (!canEditThis) {
      // Show greyed out icon
      return const SizedBox(
        width: trailingWidth,
        child: Icon(Icons.more_vert, color: Colors.grey),
      );
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
          _loadMemberDetails();
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ownership transferred')),
      );
      Navigator.pop(context); // Close dialog after transfer
    }
  }

  Widget _buildJoinRequestTile(JoinRequest request) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(request.requesterId).get(),
      builder: (context, snapshot) {
        String requesterName = 'Loading...';
        String requesterEmail = '';
        
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          requesterName = data['displayName'] ?? data['email'] ?? 'Unknown User';
          requesterEmail = data['email'] ?? '';
        }
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.orange[100],
                child: Icon(Icons.person_outline, size: 18, color: Colors.orange[700]),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requesterName,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (requesterEmail.isNotEmpty)
                      Text(
                        requesterEmail,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      'Requested ${DateFormat('MMM d').format(request.createdAt)}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              // Approve button
              IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                tooltip: 'Approve',
                onPressed: () => _processJoinRequest(request, true),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
              // Reject button
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red),
                tooltip: 'Reject',
                onPressed: () => _processJoinRequest(request, false),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processJoinRequest(JoinRequest request, bool approve) async {
    
    // Get requester name for confirmation
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(request.requesterId)
        .get();
    final requesterName = userDoc.data()?['displayName'] ?? 'this user';
    
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
          await _loadMemberDetails();
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

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.group, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Members - ${_group.name}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_group.members.length} member${_group.members.length != 1 ? 's' : ''}',
              style: TextStyle(color: Colors.grey[600]),
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
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      leading: Icon(Icons.person_add, color: Colors.orange[700], size: 20),
                      title: Text(
                        'Join Requests (${requests.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
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
                          children: [
                            Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
                            if (isCurrentUser)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('You', style: TextStyle(fontSize: 10, color: Colors.green)),
                              ),
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
