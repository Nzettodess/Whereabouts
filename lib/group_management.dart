import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';
import 'models.dart';
import 'models/join_request.dart';
import 'models/placeholder_member.dart';
import 'placeholder_member_management.dart';
import 'member_management.dart';
import 'theme.dart';
import 'models/placeholder_member.dart';
import 'placeholder_member_management.dart';
import 'member_management.dart';

class GroupManagementDialog extends StatefulWidget {
  const GroupManagementDialog({super.key});

  @override
  State<GroupManagementDialog> createState() => _GroupManagementDialogState();
}

class _GroupManagementDialogState extends State<GroupManagementDialog> {
  final FirestoreService _firestoreService = FirestoreService();
  final User? _user = FirebaseAuth.instance.currentUser;
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _joinCodeController = TextEditingController();

  void _createGroup() async {
    if (_groupNameController.text.isEmpty || _user == null) return;
    try {
      await _firestoreService.createGroup(_groupNameController.text, _user!.uid);
      _groupNameController.clear();
      if (mounted) {
        Navigator.pop(context); // Close create dialog
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Group Created!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _joinGroup() async {
    if (_joinCodeController.text.isEmpty || _user == null) return;
    
    try {
      await _firestoreService.requestToJoinGroup(_joinCodeController.text, _user!.uid);
      _joinCodeController.clear();
      if (mounted) {
        Navigator.pop(context); // Close join dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Join request sent! Waiting for admin approval."),
            duration: Duration(seconds: 3),
          )
        );
      }
    } catch (e) {
      _joinCodeController.clear();
      if (mounted) {
        Navigator.pop(context); // Close join dialog
        
        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Unable to Join"),
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    }
  }


  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Create Group"),
        content: TextField(
          controller: _groupNameController,
          decoration: const InputDecoration(labelText: "Group Name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: _createGroup, child: const Text("Create")),
        ],
      ),
    );
  }

  void _showJoinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Request to Join Group"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _joinCodeController,
              decoration: const InputDecoration(labelText: "Group ID"),
            ),
            const SizedBox(height: 8),
            Text(
              "Your request will be sent to the group admin for approval.",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: _joinGroup, child: const Text("Request to Join")),
        ],
      ),
    );
  }


  void _leaveGroup(Group group) async {
    if (_user == null) return;
    
    // Check if user is the last member
    final isLastMember = group.members.length == 1;
    
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isLastMember ? "⚠️ Delete Group?" : "Leave Group?",
          style: TextStyle(color: isLastMember ? Colors.red : null),
        ),
        content: isLastMember
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You are the last member of ${group.name}.",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text("Leaving will permanently delete:"),
                const SizedBox(height: 8),
                const Text("• The group"),
                const Text("• All group events"),
                const Text("• All group location entries"),
                const SizedBox(height: 12),
                const Text(
                  "⚠️ This action cannot be undone!",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          : Text("Are you sure you want to leave ${group.name}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isLastMember ? "Delete Group" : "Leave"),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await _firestoreService.leaveGroup(group.id, _user!.uid);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isLastMember 
              ? "Group and all related data deleted" 
              : "Left group successfully"
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 450;
    final isVeryNarrow = screenWidth < 380;
    
    // Use 95% of screen width on mobile, capped at 400 for larger screens
    final dialogWidth = screenWidth < 450 ? screenWidth * 0.95 : 400.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isVeryNarrow ? 8 : (isNarrow ? 12 : 24),
        vertical: 24,
      ),
      child: Container(
        padding: EdgeInsets.all(isNarrow ? 12 : 20),
        width: dialogWidth,
        height: 500,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Groups", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<List<Group>>(
                stream: _firestoreService.getUserGroups(_user!.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("You haven't joined any groups yet."));
                  }

                  final groups = snapshot.data!;
                  return ListView.builder(
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return ListTile(
                        title: Text(group.name),
                        subtitle: Row(
                          children: [
                            Expanded(
                              child: Text('ID: ${group.id}', overflow: TextOverflow.ellipsis),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: group.id));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Group ID copied!'),
                                    duration: const Duration(seconds: 2),
                                  )
                                );
                              },
                              tooltip: 'Copy Group ID',
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Placeholder members button with inheritance request badge
                            StreamBuilder<List<InheritanceRequest>>(
                              stream: _firestoreService.getPendingInheritanceRequests(group.id),
                              builder: (context, inheritSnapshot) {
                                final inheritPendingCount = inheritSnapshot.data?.length ?? 0;
                                final isAdminOrOwner = group.ownerId == _user!.uid || 
                                                       group.admins.contains(_user!.uid);
                                
                                return Stack(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.person_outline, color: Colors.blue),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => PlaceholderMemberManagement(
                                            group: group,
                                            currentUserId: _user!.uid,
                                          ),
                                        );
                                      },
                                      tooltip: 'Placeholder Members',
                                    ),
                                    // Show badge if admin/owner and there are pending inheritance requests
                                    if (isAdminOrOwner && inheritPendingCount > 0)
                                      Positioned(
                                        right: 4,
                                        top: 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 16,
                                            minHeight: 16,
                                          ),
                                          child: Text(
                                            '$inheritPendingCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                            // Members button with pending request badge
                            StreamBuilder<List<JoinRequest>>(
                              stream: _firestoreService.getPendingJoinRequests(group.id),
                              builder: (context, requestSnapshot) {
                                final pendingCount = requestSnapshot.data?.length ?? 0;
                                final isAdminOrOwner = group.ownerId == _user!.uid || 
                                                       group.admins.contains(_user!.uid);
                                
                                return Stack(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.group, color: Colors.green),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => MemberManagement(
                                            group: group,
                                            currentUserId: _user!.uid,
                                          ),
                                        );
                                      },
                                      tooltip: 'Members',
                                    ),
                                    // Show badge if admin/owner and there are pending requests
                                    if (isAdminOrOwner && pendingCount > 0)
                                      Positioned(
                                        right: 4,
                                        top: 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 16,
                                            minHeight: 16,
                                          ),
                                          child: Text(
                                            '$pendingCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.exit_to_app, color: Colors.red),
                              onPressed: () => _leaveGroup(group),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            
            // Pending Join Requests Section (collapsible, scrollable)
            StreamBuilder<List<JoinRequest>>(
              stream: _firestoreService.getMyPendingJoinRequests(_user!.uid),
              builder: (context, pendingSnapshot) {
                if (!pendingSnapshot.hasData || pendingSnapshot.data!.isEmpty) {
                  return const SizedBox.shrink();
                }
                
                final pendingRequests = pendingSnapshot.data!;
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
                    leading: Icon(Icons.hourglass_empty, size: 18, color: AppColors.getPendingAccent(context)),
                    title: Text(
                      "Pending Requests (${pendingRequests.length})",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.getPendingAccent(context)),
                    ),
                    children: [

                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(right: 12),
                        itemCount: pendingRequests.length,
                        itemBuilder: (context, index) {
                          final request = pendingRequests[index];
                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance.collection('groups').doc(request.groupId).get(),
                            builder: (context, groupSnapshot) {
                              final groupName = groupSnapshot.data?.get('name') ?? 'Loading...';
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.getPendingBg(context),
                                  child: Icon(Icons.hourglass_empty, size: 16, color: AppColors.getPendingAccent(context)),
                                ),
                                title: Text(groupName, style: const TextStyle(fontSize: 14)),
                                subtitle: Text(
                                  "Waiting for approval",
                                  style: TextStyle(fontSize: 11, color: AppColors.getPendingAccent(context), fontStyle: FontStyle.italic),
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text("Cancel Request?"),
                                        content: const Text("Are you sure you want to cancel this join request?"),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text("No"),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.error,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text("Cancel Request"),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _firestoreService.cancelJoinRequest(request.id);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Join request cancelled")),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text("Cancel", style: TextStyle(fontSize: 12)),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    ],
                  ),
                );
              },
            ),

            
            const SizedBox(height: 16),
            // Responsive buttons - stack vertically on very narrow screens
            if (isVeryNarrow)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showJoinDialog,
                      icon: const Icon(Icons.group_add, size: 18),
                      label: const Text("Join Group"),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showCreateDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Create Group"),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showJoinDialog,
                      icon: Icon(Icons.group_add, size: isNarrow ? 16 : 20),
                      label: Text("Join", style: TextStyle(fontSize: isNarrow ? 12 : 14)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showCreateDialog,
                      icon: Icon(Icons.add, size: isNarrow ? 16 : 20),
                      label: Text("Create", style: TextStyle(fontSize: isNarrow ? 12 : 14)),
                    ),
                  ),
                ],
              ),

          ],
        ),
      ),
    );
  }
}
