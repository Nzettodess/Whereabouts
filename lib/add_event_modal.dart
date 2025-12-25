import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'firestore_service.dart';
import 'widgets/syncfusion_date_picker.dart';
import 'services/notification_service.dart';

class AddEventModal extends StatefulWidget {
  final String currentUserId;
  final DateTime initialDate;
  final GroupEvent? eventToEdit;

  const AddEventModal({
    super.key,
    required this.currentUserId,
    required this.initialDate,
    this.eventToEdit,
  });

  @override
  State<AddEventModal> createState() => _AddEventModalState();
}

class _AddEventModalState extends State<AddEventModal> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _hasTime = false;
  String? _selectedGroupId;
  List<Group> _userGroups = [];

  @override
  void initState() {
    super.initState();
    if (widget.eventToEdit != null) {
      // Editing mode
      final event = widget.eventToEdit!;
      _titleController.text = event.title;
      _descController.text = event.description;
      _venueController.text = event.venue ?? '';
      _selectedDate = event.date;
      _selectedTime = TimeOfDay.fromDateTime(event.date);
      _hasTime = event.hasTime;
      _selectedGroupId = event.groupId;
    } else {
      // Create mode
      _selectedDate = widget.initialDate;
    }
    _loadUserGroups();
  }

  void _loadUserGroups() {
    _firestoreService.getUserGroups(widget.currentUserId).listen((groups) {
      if (mounted) {
        setState(() {
          _userGroups = groups;
          if (widget.eventToEdit == null && groups.isNotEmpty && _selectedGroupId == null) {
            _selectedGroupId = groups.first.id;
          }
        });
      }
    });
  }

  void _saveEvent() async {
    if (_formKey.currentState!.validate() && _selectedGroupId != null) {
      // Combine date and time if hasTime is true
      DateTime finalDate = _selectedDate;
      if (_hasTime) {
        finalDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
      }

      if (widget.eventToEdit != null) {
        // Update existing event
        final updatedEvent = GroupEvent(
          id: widget.eventToEdit!.id,
          groupId: _selectedGroupId!,
          creatorId: widget.eventToEdit!.creatorId,
          title: _titleController.text,
          description: _descController.text,
          venue: _venueController.text.isEmpty ? null : _venueController.text,
          date: finalDate,
          hasTime: _hasTime,
          rsvps: widget.eventToEdit!.rsvps,
        );
        await _firestoreService.updateEvent(updatedEvent, widget.currentUserId);
        
        // --- Trigger Notification ---
        try {
          final selectedGroup = _userGroups.firstWhere((g) => g.id == _selectedGroupId!);
          
          debugPrint('DEBUG: Update Target Group: ${selectedGroup.name}');

          // Calculate changes for notification
          final changes = _generateChangeSummary(widget.eventToEdit!, updatedEvent);
          
          await NotificationService().notifyEventUpdated(
            memberIds: selectedGroup.members,
            editorId: widget.currentUserId,
            eventId: updatedEvent.id,
            eventTitle: updatedEvent.title,
            groupId: selectedGroup.id,
            changeSummary: changes,
          );
          
        } catch (e) {
            debugPrint('Error sending update notification: $e');
            if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Update Push Failed: $e'), backgroundColor: Colors.red),
                );
            }
        }
      } else {
        // Create new event
        final event = GroupEvent(
          id: const Uuid().v4(),
          groupId: _selectedGroupId!,
          creatorId: widget.currentUserId,
          title: _titleController.text,
          description: _descController.text,
          venue: _venueController.text.isEmpty ? null : _venueController.text,
          date: finalDate,
          hasTime: _hasTime,
          rsvps: {widget.currentUserId: 'Yes'},
        );
        await _firestoreService.createEvent(event);
        
        // --- Trigger Notification ---
        try {
          // Get group details to send notifications
          final selectedGroup = _userGroups.firstWhere((g) => g.id == _selectedGroupId!);
          
          debugPrint('DEBUG: Target Group: ${selectedGroup.name}');
          debugPrint('DEBUG: Raw Members: ${selectedGroup.members}');
          
          debugPrint('DEBUG: Raw Members: ${selectedGroup.members}');

          await NotificationService().notifyEventCreated(
            memberIds: selectedGroup.members,
            creatorId: widget.currentUserId,
            eventId: event.id,
            eventTitle: event.title,
            groupId: selectedGroup.id,
            groupName: selectedGroup.name,
          );
          
          debugPrint('DEBUG: notifyEventCreated completed successfully');
        } catch (e) {
          debugPrint('Error sending event notification: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Push Failed: $e'), backgroundColor: Colors.red),
            );
          }
        }
      }
      
      // Small delay to let SnackBar be seen (optional, but helpful for debug)
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showSyncfusionDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'Select Event Date',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.eventToEdit != null;
    
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.only(
          top: 16, left: 16, right: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Text(
                isEditing ? "Edit Event" : "Schedule Event", 
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Event Title"),
                validator: (value) => value!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: "Description"),
                minLines: 1,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
              ),
              TextFormField(
                controller: _venueController,
                decoration: const InputDecoration(
                  labelText: "Venue (Optional)",
                  hintText: "Enter event location",
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text("Date: "),
                  TextButton(
                    onPressed: _pickDate,
                    child: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text("Include Time"),
                value: _hasTime,
                onChanged: (value) {
                  setState(() {
                    _hasTime = value;
                  });
                },
              ),
              if (_hasTime)
                Row(
                  children: [
                    const Text("Time: "),
                    TextButton(
                      onPressed: _pickTime,
                      child: Text(_selectedTime.format(context)),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedGroupId,
                decoration: const InputDecoration(labelText: "Group"),
                items: _userGroups.map((g) => DropdownMenuItem(
                  value: g.id,
                  child: Text(g.name),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGroupId = value;
                  });
                },
                validator: (value) => value == null ? "Select a group" : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveEvent,
                child: Text(isEditing ? "Save Changes" : "Create Event"),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  // Helper to calculate changes between two event versions
  String? _generateChangeSummary(GroupEvent oldEvent, GroupEvent newEvent) {
    if (oldEvent == newEvent) return null;
    
    final changes = <String>[];
    
    if (oldEvent.title != newEvent.title) {
      changes.add("Title Updated");
    }
    
    if (oldEvent.venue != newEvent.venue) {
      final oldV = oldEvent.venue != null && oldEvent.venue!.isNotEmpty ? oldEvent.venue! : '';
      final newV = newEvent.venue != null && newEvent.venue!.isNotEmpty ? newEvent.venue! : '';
      if (oldV != newV) {
        changes.add("Venue Updated");
      }
    }
    
    // Compare dates
    final oldDateStr = DateFormat('yyyy-MM-dd').format(oldEvent.date);
    final newDateStr = DateFormat('yyyy-MM-dd').format(newEvent.date);
    
    if (oldDateStr != newDateStr) {
       changes.add("Date Updated");
    }
    
    // Compare times
    if (oldEvent.hasTime != newEvent.hasTime || 
       (oldEvent.hasTime && newEvent.hasTime && oldEvent.date != newEvent.date)) {
        if (newEvent.hasTime) {
           final oldTime = oldEvent.hasTime ? DateFormat('HH:mm').format(oldEvent.date) : '';
           final newTime = DateFormat('HH:mm').format(newEvent.date);
           if (oldTime != newTime) {
             changes.add("Time Updated");
           }
        } else {
           changes.add("Time Removed");
        }
    }
    
    if (oldEvent.description != newEvent.description) {
      changes.add("Description Updated");
    }

    if (changes.isEmpty) return null;
    return changes.join(", ");
  }
}
