import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';
import 'firestore_service.dart';
import 'edit_member_dialog.dart';

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

  Widget? _buildTrailingActions(String memberId, bool isThisOwner, bool isThisAdmin, bool isCurrentUser) {
    // Can't edit yourself
    if (isCurrentUser) return null;
    
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
      return const Icon(Icons.more_vert, color: Colors.grey);
    }
    
    // If user can't edit this target (e.g., admin looking at another admin)
    if (!canEditThis) {
      // Show greyed out icon
      return const Icon(Icons.more_vert, color: Colors.grey);
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
                    'Manage Members - ${_group.name}',
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
            Expanded(
              child: ListView.builder(
                itemCount: _group.members.length,
                itemBuilder: (context, index) {
                  final memberId = _group.members[index];
                  final member = _memberDetails[memberId];
                  final name = member?['displayName'] ?? member?['email'] ?? 'Loading...';
                  final email = member?['email'] ?? '';
                  final isThisOwner = memberId == _group.ownerId;
                  final isThisAdmin = _group.admins.contains(memberId);
                  final isCurrentUser = memberId == widget.currentUserId;

                  return ListTile(
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
