import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';
import 'models.dart';

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
    await _firestoreService.joinGroup(_joinCodeController.text, _user!.uid);
    _joinCodeController.clear();
    if (mounted) Navigator.pop(context); // Close join dialog
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
        title: const Text("Join Group"),
        content: TextField(
          controller: _joinCodeController,
          decoration: const InputDecoration(labelText: "Group ID"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: _joinGroup, child: const Text("Join")),
        ],
      ),
    );
  }

  void _leaveGroup(Group group) async {
    if (_user == null) return;
    
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Leave Group?"),
        content: Text("Are you sure you want to leave ${group.name}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Leave", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await _firestoreService.leaveGroup(group.id, _user!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const SizedBox.shrink();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: 400, // Max width constraint
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
                        trailing: IconButton(
                          icon: const Icon(Icons.exit_to_app, color: Colors.red),
                          onPressed: () => _leaveGroup(group),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _showJoinDialog,
                  icon: const Icon(Icons.group_add),
                  label: const Text("Join Group"),
                ),
                ElevatedButton.icon(
                  onPressed: _showCreateDialog,
                  icon: const Icon(Icons.add),
                  label: const Text("Create Group"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
