import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/default_location_picker.dart';
import 'widgets/lunar_date_picker.dart';
import 'widgets/syncfusion_date_picker.dart';

class EditMemberDialog extends StatefulWidget {
  final String memberId;
  final Map<String, dynamic> memberDetails;
  final String groupId;
  final VoidCallback onSaved;

  const EditMemberDialog({
    super.key,
    required this.memberId,
    required this.memberDetails,
    required this.groupId,
    required this.onSaved,
  });

  @override
  State<EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends State<EditMemberDialog> {
  String? _defaultLocation;
  DateTime? _birthday;
  bool _hasLunarBirthday = false;
  int? _lunarBirthdayMonth;
  int? _lunarBirthdayDay;
  bool _isLoading = false;
  
  // Per-field privacy settings
  bool _blockDefaultLocation = false;
  bool _blockBirthday = false;
  bool _blockLunarBirthday = false;

  @override
  void initState() {
    super.initState();
    _loadMemberData();
  }

  Future<void> _loadMemberData() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.memberId)
        .get();
    
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _defaultLocation = data['defaultLocation'];
        _birthday = data['birthday'] != null 
            ? (data['birthday'] as Timestamp).toDate() 
            : null;
        _hasLunarBirthday = data['hasLunarBirthday'] ?? false;
        _lunarBirthdayMonth = data['lunarBirthdayMonth'];
        _lunarBirthdayDay = data['lunarBirthdayDay'];
        
        // Check per-field privacy settings
        final privacySettings = data['privacySettings'] as Map<String, dynamic>?;
        if (privacySettings != null) {
          _blockDefaultLocation = privacySettings['blockDefaultLocation'] == true;
          _blockBirthday = privacySettings['blockBirthday'] == true;
          _blockLunarBirthday = privacySettings['blockLunarBirthday'] == true;
        }
      });
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    
    try {
      final updateData = <String, dynamic>{
        'defaultLocation': _defaultLocation,
        'birthday': _birthday != null ? Timestamp.fromDate(_birthday!) : null,
        'hasLunarBirthday': _hasLunarBirthday,
        'lunarBirthdayMonth': _lunarBirthdayMonth,
        'lunarBirthdayDay': _lunarBirthdayDay,
      };
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.memberId)
          .update(updateData);
      
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member details updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _pickDefaultLocation() {
    // Parse existing location if set
    String? existingCountry;
    String? existingState;
    if (_defaultLocation != null && _defaultLocation!.contains(', ')) {
      final parts = _defaultLocation!.split(', ');
      existingCountry = parts[0];
      if (parts.length > 1) existingState = parts[1];
    } else if (_defaultLocation != null) {
      existingCountry = _defaultLocation;
    }
    
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          child: DefaultLocationPicker(
            defaultCountry: existingCountry,
            defaultState: existingState,
            onLocationSelected: (country, state) {
              setState(() {
                _defaultLocation = state != null ? '$country, $state' : country;
              });
            },
          ),
        ),
      ),
    );
  }

  Future<void> _pickBirthday() async {
    DateTime initialDate;
    if (_birthday != null) {
      initialDate = _birthday!;
    } else {
      final now = DateTime.now();
      initialDate = DateTime(now.year - 25, now.month, now.day);
    }
    
    final picked = await showSyncfusionDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select Birthday',
    );
    if (picked != null) {
      setState(() {
        _birthday = picked;
      });
    }
  }

  Future<void> _pickLunarBirthday() async {
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (_) => LunarDatePickerDialog(
        initialMonth: _lunarBirthdayMonth ?? 1,
        initialDay: _lunarBirthdayDay ?? 1,
      ),
    );
    if (result != null) {
      setState(() {
        _hasLunarBirthday = true;
        _lunarBirthdayMonth = result.$1;
        _lunarBirthdayDay = result.$2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.memberDetails['displayName'] ?? 
                 widget.memberDetails['email'] ?? 
                 'Unknown User';
    
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450, maxHeight: 550),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.edit, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Edit Details - $name',
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
            const Divider(),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Default Location
                    ListTile(
                      leading: Icon(Icons.location_on, 
                        color: _blockDefaultLocation ? Colors.grey : Colors.blue),
                      title: Text('Default Location${_blockDefaultLocation ? " 🔒" : ""}'),
                      subtitle: Text(_defaultLocation ?? 'Not set',
                        style: TextStyle(color: _blockDefaultLocation ? Colors.grey : null)),
                      trailing: _blockDefaultLocation ? null : IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: _pickDefaultLocation,
                      ),
                    ),
                    
                    const Divider(),
                    
                    // Birthday
                    ListTile(
                      leading: Icon(Icons.cake, 
                        color: _blockBirthday ? Colors.grey : Colors.pink),
                      title: Text('Birthday${_blockBirthday ? " 🔒" : ""}'),
                      subtitle: Text(_birthday != null 
                          ? '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}'
                          : 'Not set',
                        style: TextStyle(color: _blockBirthday ? Colors.grey : null)),
                      trailing: _blockBirthday ? null : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: _pickBirthday,
                          ),
                          if (_birthday != null)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.red),
                              onPressed: () => setState(() => _birthday = null),
                            ),
                        ],
                      ),
                    ),
                    
                    const Divider(),
                    
                    // Lunar Birthday
                    ListTile(
                      leading: Icon(Icons.nightlight_round, 
                        color: _blockLunarBirthday ? Colors.grey : Colors.amber),
                      title: Text('Lunar Birthday (农历生日)${_blockLunarBirthday ? " 🔒" : ""}'),
                      subtitle: Text(_hasLunarBirthday && _lunarBirthdayMonth != null
                          ? LunarDatePickerDialog.formatLunarDate(_lunarBirthdayMonth!, _lunarBirthdayDay!)
                          : 'Not set',
                        style: TextStyle(color: _blockLunarBirthday ? Colors.grey : null)),
                      trailing: _blockLunarBirthday ? null : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: _pickLunarBirthday,
                          ),
                          if (_hasLunarBirthday)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.red),
                              onPressed: () => setState(() {
                                _hasLunarBirthday = false;
                                _lunarBirthdayMonth = null;
                                _lunarBirthdayDay = null;
                              }),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  child: _isLoading 
                      ? const SizedBox(
                          width: 20, 
                          height: 20, 
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
