import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'firestore_service.dart';
import 'models.dart';
import 'models/placeholder_member.dart';
import 'widgets/default_location_picker.dart';
import 'widgets/lunar_date_picker.dart';
import 'widgets/syncfusion_date_picker.dart';
import 'widgets/user_profile_dialog.dart';
import 'widgets/skeleton_loading.dart';
import 'edit_member_dialog.dart';
import 'theme.dart';

class PlaceholderMemberManagement extends StatefulWidget {
  final Group group;
  final String currentUserId;

  const PlaceholderMemberManagement({
    super.key,
    required this.group,
    required this.currentUserId,
  });

  @override
  State<PlaceholderMemberManagement> createState() => _PlaceholderMemberManagementState();
}

class _PlaceholderMemberManagementState extends State<PlaceholderMemberManagement> {
  final FirestoreService _firestoreService = FirestoreService();
  final Uuid _uuid = const Uuid();

  bool get isOwner => widget.group.ownerId == widget.currentUserId;
  bool get isAdmin => widget.group.admins.contains(widget.currentUserId);
  bool get canEdit => isOwner || isAdmin;
  bool get canCreate => canEdit; // Owner or Admin can create (matches rule)
  bool get canDelete => isOwner;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 400;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isNarrow ? 12 : 20)),
      child: Container(
        padding: EdgeInsets.all(isNarrow ? 12 : 20),
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          minWidth: 0,
        ),
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          children: [
            // Header - compact on mobile
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Placeholder Members",
                        style: TextStyle(fontSize: isNarrow ? 16 : 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.group.name,
                        style: TextStyle(fontSize: isNarrow ? 12 : 14, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  iconSize: isNarrow ? 20 : 24,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            
            // Inheritance Requests Section (at the top, collapsible)
            _buildPendingRequestsSection(),
            
            // Placeholder Members List
            Expanded(
              child: StreamBuilder<List<PlaceholderMember>>(
                stream: _firestoreService.getGroupPlaceholderMembers(widget.group.id),
                builder: (context, snapshot) {
                  // Show skeleton - DISABLED per user request
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final placeholders = snapshot.data ?? [];
                  
                  if (placeholders.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add_disabled, size: isNarrow ? 48 : 64, color: Colors.grey[400]),
                          SizedBox(height: isNarrow ? 12 : 16),
                          Text(
                            "No placeholder members yet",
                            style: TextStyle(color: Colors.grey[600], fontSize: isNarrow ? 13 : 14),
                          ),
                          if (canCreate) ...[
                            const SizedBox(height: 8),
                            Text(
                              "Create one to represent a member who hasn't joined",
                              style: TextStyle(fontSize: isNarrow ? 11 : 12, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    itemCount: placeholders.length,
                    itemBuilder: (context, index) {
                      final placeholder = placeholders[index];
                      return _buildPlaceholderTile(placeholder);
                    },
                  );
                },
              ),
            ),
            
            // Create Button (Owner or Admin) - Solid color for dark mode
            if (canCreate) ...[
              SizedBox(height: isNarrow ? 12 : 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showCreateDialog,
                  icon: Icon(Icons.person_add, size: isNarrow ? 18 : 20),
                  label: Text(
                    "Create Placeholder",
                    style: TextStyle(fontSize: isNarrow ? 13 : 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isNarrow ? 10 : 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showUserProfile(PlaceholderMember placeholder) {
    showDialog(
      context: context,
      builder: (context) => UserProfileDialog(
        displayName: placeholder.displayName,
        photoUrl: null,
        defaultLocation: placeholder.defaultLocation,
        birthday: placeholder.birthday, // Assuming it's DateTime
        hasLunarBirthday: placeholder.hasLunarBirthday,
        lunarBirthdayMonth: placeholder.lunarBirthdayMonth,
        lunarBirthdayDay: placeholder.lunarBirthdayDay,
        isPlaceholder: true,
        canEdit: canEdit,
        onEdit: () {
          _showEditDialog(placeholder);
        },
      ),
    );
  }

  Widget _buildPlaceholderTile(PlaceholderMember placeholder) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0, // Flatter look
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        visualDensity: const VisualDensity(horizontal: 0, vertical: -2), // Compact
        contentPadding: const EdgeInsets.fromLTRB(12, 4, 8, 4), // Compact padding
        onTap: () => _showUserProfile(placeholder),
        leading: CircleAvatar(
          radius: 18, // Slightly smaller
          backgroundColor: Colors.grey[200],
          child: const Icon(Icons.person_outline, color: Colors.grey, size: 20),
        ),
        title: Text(
          placeholder.displayName, 
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)
        ),
        subtitle: (placeholder.defaultLocation == null && placeholder.birthday == null && !placeholder.hasLunarBirthday) 
            ? null 
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (placeholder.defaultLocation != null)
                    Text(
                      placeholder.defaultLocation!,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  if (placeholder.birthday != null || (placeholder.hasLunarBirthday && placeholder.lunarBirthdayMonth != null))
                    Text(
                      [
                        if (placeholder.birthday != null) "🎂 ${placeholder.birthday!.month}/${placeholder.birthday!.day}",
                        if (placeholder.hasLunarBirthday && placeholder.lunarBirthdayMonth != null) "🏮 ${placeholder.lunarBirthdayMonth}/${placeholder.lunarBirthdayDay}",
                      ].join(' • '),
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                ],
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Edit button
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _showEditDialog(placeholder),
                tooltip: 'Edit',
                color: Colors.blueGrey,
              ),
            // Delete button
            if (canDelete)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => _confirmDelete(placeholder),
                tooltip: 'Delete',
                color: Colors.red,
              ),
            // Request Inheritance button
            if (!isOwner)
              IconButton(
                icon: const Icon(Icons.download, size: 20),
                onPressed: () => _requestInheritance(placeholder),
                tooltip: 'Request to Inherit',
                color: Colors.blue,
              ),
          ],
        ),
      ),
    );
  }

  // Helper removed as we returned to standard IconButton for better clickability on mobile
  // The solid "Container" style was reported as hard to click.

  Widget _buildPendingRequestsSection() {
    // Use different queries based on role:
    // - Owners/Admins: query all pending requests for the group
    // - Regular members: query only their own requests (required by Firestore security rules)
    final stream = canEdit
        ? _firestoreService.getPendingInheritanceRequests(widget.group.id)
        : _firestoreService.getMyPendingInheritanceRequests(widget.group.id, widget.currentUserId);
    
    return StreamBuilder<List<InheritanceRequest>>(
      stream: stream,
      builder: (context, snapshot) {
        final requests = snapshot.data ?? [];
        
        if (requests.isEmpty) {
          return const SizedBox.shrink();
        }
        
        final title = canEdit ? "Inheritance Requests" : "Your Requests";
        
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
            leading: Icon(Icons.download, color: AppColors.getPendingAccent(context), size: 20),
            title: Text(
              '$title (${requests.length})',
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
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: requests.length,
                  itemBuilder: (context, index) => _buildRequestTile(requests[index]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestTile(InheritanceRequest request) {
    // Check if this is the current user's own request
    final isOwnRequest = request.requesterId == widget.currentUserId;
    
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        FirebaseFirestore.instance.collection('users').doc(request.requesterId).get(),
        _firestoreService.getPlaceholderMember(request.placeholderMemberId),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final userDoc = snapshot.data![0] as DocumentSnapshot;
        final placeholder = snapshot.data![1] as PlaceholderMember?;
        
        final userData = userDoc.data() as Map<String, dynamic>?;
        final requesterName = userData?['displayName'] ?? userData?['email'] ?? 'Unknown';
        final placeholderName = placeholder?.displayName ?? 'Unknown';
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isOwnRequest 
                      ? "Your request to inherit $placeholderName"
                      : "$requesterName wants to inherit $placeholderName",
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              if (isOwnRequest)
                // Own request - show cancel button
                TextButton(
                  onPressed: () => _cancelRequest(request, placeholderName),
                  child: const Text("Cancel", style: TextStyle(color: Colors.red, fontSize: 12)),
                )
              else
                // Other's request - show approve/reject buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green, size: 24),
                      onPressed: () => _processRequest(request, true),
                      tooltip: 'Approve',
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red, size: 24),
                      onPressed: () => _processRequest(request, false),
                      tooltip: 'Reject',
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }


  Future<void> _cancelRequest(InheritanceRequest request, String placeholderName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Request?"),
        content: Text("Are you sure you want to cancel your request to inherit $placeholderName?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes, Cancel", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('inheritance_requests')
            .doc(request.id)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Request cancelled")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to cancel: ${e.toString()}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showCreateDialog() {
    final nameController = TextEditingController();
    String? selectedLocation;
    DateTime? selectedBirthday;
    bool hasLunarBirthday = false;
    int? lunarMonth;
    int? lunarDay;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text("Create Placeholder Member"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Display Name *",
                    hintText: "e.g., Dad, Mom, Grandpa",
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(selectedLocation ?? "Set Default Location"),
                  trailing: const Icon(Icons.location_on),
                  onTap: () async {
                    // DefaultLocationPicker already calls Navigator.pop, so we don't need to pop again
                    await showDialog(
                      context: dialogContext,
                      builder: (pickerContext) => Dialog(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 500),
                          child: DefaultLocationPicker(
                            onLocationSelected: (country, state) {
                              final location = state != null && state.isNotEmpty 
                                  ? "$country, $state" 
                                  : country;
                              setDialogState(() => selectedLocation = location);
                              // DefaultLocationPicker pops itself, so don't pop again
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(selectedBirthday != null 
                    ? "Birthday: ${selectedBirthday!.month}/${selectedBirthday!.day}/${selectedBirthday!.year}"
                    : "Set Birthday"),
                  trailing: const Icon(Icons.cake),
                  onTap: () async {
                    final result = await showDialog<DateTime>(
                      context: dialogContext,
                      builder: (_) => SyncfusionDatePickerDialog(
                        initialDate: selectedBirthday ?? DateTime(2000, 1, 1),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      ),
                    );
                    if (result != null) {
                      setDialogState(() => selectedBirthday = result);
                    }
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(hasLunarBirthday && lunarMonth != null
                    ? "Lunar Birthday: Month $lunarMonth, Day $lunarDay"
                    : "Set Lunar Birthday (Optional)"),
                  trailing: Icon(
                    Icons.nights_stay,
                    color: hasLunarBirthday ? Colors.orange : Colors.grey,
                  ),
                  onTap: () async {
                    // LunarDatePickerDialog returns (int, int) tuple
                    final result = await showDialog<(int, int)>(
                      context: dialogContext,
                      builder: (_) => const LunarDatePickerDialog(),
                    );
                    if (result != null) {
                      setDialogState(() {
                        hasLunarBirthday = true;
                        lunarMonth = result.$1;  // Access tuple's first element
                        lunarDay = result.$2;    // Access tuple's second element
                      });
                    }
                  },
                ),
                if (hasLunarBirthday)
                  TextButton(
                    onPressed: () {
                      setDialogState(() {
                        hasLunarBirthday = false;
                        lunarMonth = null;
                        lunarDay = null;
                      });
                    },
                    child: const Text("Clear Lunar Birthday", style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text("Please enter a name")),
                  );
                  return;
                }
                
                final placeholder = PlaceholderMember(
                  id: 'placeholder_${_uuid.v4()}',
                  groupId: widget.group.id,
                  displayName: nameController.text,
                  createdBy: widget.currentUserId,
                  createdAt: DateTime.now(),
                  defaultLocation: selectedLocation,
                  birthday: selectedBirthday,
                  hasLunarBirthday: hasLunarBirthday,
                  lunarBirthdayMonth: hasLunarBirthday ? lunarMonth : null,
                  lunarBirthdayDay: hasLunarBirthday ? lunarDay : null,
                );
                
                await _firestoreService.createPlaceholderMember(placeholder);
                if (mounted) Navigator.pop(dialogContext);
              },
              child: const Text("Create"),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(PlaceholderMember placeholder) {
    // EditMemberDialog will fetch fresh data, so we can pass basic details
    final details = {
      'displayName': placeholder.displayName,
      'defaultLocation': placeholder.defaultLocation,
      'birthday': placeholder.birthday != null ? Timestamp.fromDate(placeholder.birthday!) : null,
      'hasLunarBirthday': placeholder.hasLunarBirthday,
      'lunarBirthdayMonth': placeholder.lunarBirthdayMonth,
      'lunarBirthdayDay': placeholder.lunarBirthdayDay,
    };

    showDialog(
      context: context,
      builder: (_) => EditMemberDialog(
        memberId: placeholder.id,
        memberDetails: details,
        groupId: widget.group.id,
        isPlaceholder: true,
        onSaved: () {
          // StreamBuilder will auto-update the list
        },
      ),
    );
  }

  Future<void> _confirmDelete(PlaceholderMember placeholder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("⚠️ Delete Placeholder?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will permanently delete "${placeholder.displayName}" and:'),
            const SizedBox(height: 12),
            const Text("• All location history"),
            const Text("• All pending inheritance requests"),
            const SizedBox(height: 12),
            const Text(
              "This action cannot be undone!",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestoreService.deletePlaceholderMember(placeholder.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Placeholder deleted")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to delete: ${e.toString()}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _requestInheritance(PlaceholderMember placeholder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Request Inheritance?"),
        content: Text(
          'Request to inherit all data from "${placeholder.displayName}"?\n\n'
          'This includes their default location, birthday, and location history. '
          'The request needs to be approved by the group owner or admin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Request"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestoreService.requestInheritance(
          placeholder.id,
          widget.currentUserId,
          widget.group.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Inheritance request sent!")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${e.toString()}")),
          );
        }
      }
    }
  }

  Future<void> _processRequest(InheritanceRequest request, bool approve) async {
    // First confirmation
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? "Approve Request?" : "Reject Request?"),
        content: Text(
          approve
            ? "This will transfer all placeholder data to the requester and delete the placeholder."
            : "This will reject the inheritance request.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? Colors.green : Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              approve ? "Continue" : "Reject",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (firstConfirm != true) return;

    // Second confirmation for safety
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? "⚠️ Final Confirmation" : "⚠️ Confirm Rejection"),
        content: Text(
          approve
            ? "Are you absolutely sure? The placeholder member will be permanently deleted after data transfer."
            : "Are you sure you want to reject this request?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? Colors.orange : Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              approve ? "Yes, Approve" : "Yes, Reject",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (secondConfirm == true) {
      try {
        await _firestoreService.processInheritanceRequest(
          request.id,
          approve,
          widget.currentUserId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(approve 
                ? "Inheritance approved! Data transferred successfully."
                : "Request rejected."),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${e.toString()}")),
          );
        }
      }
    }
  }
}
