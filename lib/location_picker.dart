import 'package:flutter/material.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
import 'package:intl/intl.dart';
import 'widgets/syncfusion_date_picker.dart';
import 'models/placeholder_member.dart';
import 'theme.dart';

class LocationPicker extends StatefulWidget {
  final Function(String country, String? state, DateTime startDate, DateTime endDate, List<String> selectedMemberIds) onLocationSelected;
  final String? defaultCountry;
  final String? defaultState;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final String currentUserId;
  final List<PlaceholderMember> placeholderMembers;
  // Group members who allow location editing (filtered by privacy settings)
  final List<Map<String, dynamic>> groupMembers;
  // Is current user owner or admin (can set location for others)
  final bool isOwnerOrAdmin;

  const LocationPicker({
    super.key, 
    required this.onLocationSelected,
    this.defaultCountry,
    this.defaultState,
    this.initialStartDate,
    this.initialEndDate,
    required this.currentUserId,
    this.placeholderMembers = const [],
    this.groupMembers = const [],
    this.isOwnerOrAdmin = false,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  String? countryValue;
  String? stateValue;
  String? cityValue;
  late DateTime startDate;
  late DateTime endDate;
  
  // Track selected members (current user always selected by default)
  late Set<String> selectedMemberIds;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize with default values
    countryValue = widget.defaultCountry;
    stateValue = widget.defaultState;
    
    // Initialize date range
    startDate = widget.initialStartDate ?? DateTime.now();
    endDate = widget.initialEndDate ?? DateTime.now();
    
    // Current user selected by default
    selectedMemberIds = {widget.currentUserId};
  }

  Future<void> _selectStartDate() async {
    final picked = await showSyncfusionDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Select Start Date',
    );
    if (picked != null) {
      setState(() {
        startDate = picked;
        // Ensure end date is not before start date
        if (endDate.isBefore(startDate)) {
          endDate = startDate;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showSyncfusionDatePicker(
      context: context,
      initialDate: endDate.isBefore(startDate) ? startDate : endDate,
      firstDate: startDate, // Can't select before start date
      lastDate: DateTime(2030),
      helpText: 'Select End Date',
    );
    if (picked != null) {
      setState(() {
        endDate = picked;
      });
    }
  }

  int get _dayCount => endDate.difference(startDate).inDays + 1;

  String _getSelectedMembersSummary() {
    final names = <String>[];
    if (selectedMemberIds.contains(widget.currentUserId)) {
      names.add("Myself");
    }
    for (final p in widget.placeholderMembers) {
      if (selectedMemberIds.contains(p.id)) {
        names.add(p.displayName);
      }
    }
    return names.join(", ");
  }

  // Map country names to CscCountry enum values
  CscCountry? _getCountryEnum(String? countryName) {
    if (countryName == null) {
      return null;
    }
    
    // Map of country names to enum values
    final countryMap = {
      'United States': CscCountry.United_States,
      'United Kingdom': CscCountry.United_Kingdom,
      'Canada': CscCountry.Canada,
      'Australia': CscCountry.Australia,
      'New Zealand': CscCountry.New_Zealand,
      'Singapore': CscCountry.Singapore,
      'Malaysia': CscCountry.Malaysia,
      'Indonesia': CscCountry.Indonesia,
      'Thailand': CscCountry.Thailand,
      'Philippines': CscCountry.Philippines,
      'Vietnam': CscCountry.Vietnam,
      'Japan': CscCountry.Japan,
      // Note: South Korea not available in CscCountry enum
      'China': CscCountry.China,
      'Hong Kong': CscCountry.China,  // Hong Kong falls under China in this package
      'Taiwan': CscCountry.Taiwan,
      'India': CscCountry.India,
      'Germany': CscCountry.Germany,
      'France': CscCountry.France,
      'Italy': CscCountry.Italy,
      'Spain': CscCountry.Spain,
      'Netherlands': CscCountry.Belgium,  // Use Belgium as fallback for Netherlands
      'Belgium': CscCountry.Belgium,
      'Switzerland': CscCountry.Switzerland,
      'Austria': CscCountry.Austria,
      'Sweden': CscCountry.Sweden,
      'Norway': CscCountry.Norway,
      'Denmark': CscCountry.Denmark,
      'Finland': CscCountry.Finland,
      'Poland': CscCountry.Poland,
      'Ireland': CscCountry.Ireland,
      'Portugal': CscCountry.Portugal,
      'Greece': CscCountry.Greece,
      'Brazil': CscCountry.Brazil,
      'Mexico': CscCountry.Mexico,
      'Argentina': CscCountry.Argentina,
      'Chile': CscCountry.Chile,
      'Colombia': CscCountry.Colombia,
      'South Africa': CscCountry.South_Africa,
      'Egypt': CscCountry.Egypt,
      'Nigeria': CscCountry.Nigeria,
      'Russia': CscCountry.Russia,
      'Turkey': CscCountry.Turkey,
      'Saudi Arabia': CscCountry.Saudi_Arabia,
      'United Arab Emirates': CscCountry.United_Arab_Emirates,
      'Israel': CscCountry.Israel,
    };
    
    return countryMap[countryName];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // SCROLLABLE CONTENT
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Set Location",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
            
            // Member Selection (if owner/admin with members to manage, or placeholder members exist)
            if (widget.placeholderMembers.isNotEmpty || 
                (widget.isOwnerOrAdmin && widget.groupMembers.isNotEmpty)) ...[
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ExpansionTile(
                  initiallyExpanded: false,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: Row(
                    children: [
                      const Icon(Icons.people, size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        "Apply to ${selectedMemberIds.length} member${selectedMemberIds.length > 1 ? 's' : ''}",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    _getSelectedMembersSummary(),
                    style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  children: [
                    const Divider(height: 1),
                    // Current user
                    CheckboxListTile(
                      dense: true,
                      title: const Row(
                        children: [
                          Icon(Icons.person, size: 20, color: Colors.blue),
                          SizedBox(width: 8),
                          Text("Myself"),
                        ],
                      ),
                      value: selectedMemberIds.contains(widget.currentUserId),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            selectedMemberIds.add(widget.currentUserId);
                          } else {
                            if (selectedMemberIds.length > 1) {
                              selectedMemberIds.remove(widget.currentUserId);
                            }
                          }
                        });
                      },
                    ),
                    // Group members (who allow location editing)
                    if (widget.isOwnerOrAdmin && widget.groupMembers.isNotEmpty) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Text("Group Members", style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor, fontWeight: FontWeight.bold)),
                      ),
                      ...widget.groupMembers.map((member) {
                        final memberId = member['uid'] as String;
                        final displayName = member['displayName'] ?? member['email'] ?? 'Unknown';
                        return CheckboxListTile(
                          dense: true,
                          title: Row(
                            children: [
                              const Icon(Icons.person, size: 20, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  displayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          value: selectedMemberIds.contains(memberId),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                selectedMemberIds.add(memberId);
                              } else {
                                if (selectedMemberIds.length > 1) {
                                  selectedMemberIds.remove(memberId);
                                }
                              }
                            });
                          },
                        );
                      }),
                    ],
                    // Placeholder members
                    if (widget.placeholderMembers.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Text("Placeholder Members", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      ),
                      ...widget.placeholderMembers.map((placeholder) => CheckboxListTile(
                        dense: true,
                        title: Row(
                          children: [
                            const Icon(Icons.person_outline, size: 20, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "👻 ${placeholder.displayName}",
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        value: selectedMemberIds.contains(placeholder.id),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              selectedMemberIds.add(placeholder.id);
                            } else {
                              if (selectedMemberIds.length > 1) {
                                selectedMemberIds.remove(placeholder.id);
                              }
                            }
                          });
                        },
                      )),
                    ],
                    // Quick actions
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                selectedMemberIds = {widget.currentUserId};
                                for (var p in widget.placeholderMembers) {
                                  selectedMemberIds.add(p.id);
                                }
                                for (var m in widget.groupMembers) {
                                  selectedMemberIds.add(m['uid'] as String);
                                }
                              });
                            },
                            child: const Text("Select All", style: TextStyle(fontSize: 12)),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                selectedMemberIds = {widget.currentUserId};
                              });
                            },
                            child: const Text("Only Me", style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Date Range Selection
            Text(
              "Date Range",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectStartDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Start Date",
                            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM dd, yyyy').format(startDate),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _selectEndDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "End Date",
                            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM dd, yyyy').format(endDate),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    "$_dayCount day${_dayCount > 1 ? 's' : ''} selected",
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Location Selection
            Text(
              "Location",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 10),
            CSCPickerPlus(
              showCities: false,
              defaultCountry: _getCountryEnum(countryValue) ?? CscCountry.United_States,
              dropdownDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              disabledDropdownDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              selectedItemStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
              ),
              dropdownHeadingStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              dropdownItemStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
              ),
              dropdownDialogRadius: 12,
              searchBarRadius: 12,
              onCountryChanged: (value) {
                // CSCPickerPlus returns values with emojis like "🇲🇾    Malaysia"
                // We need to strip them to match our mapping
                final cleaned = value?.replaceAll(RegExp(r'[\u{1F1E6}-\u{1F1FF}]|\p{Emoji_Presentation}|\p{Emoji}\uFE0F', unicode: true), '').trim();
                setState(() {
                  countryValue = cleaned;
                });
              },
              onStateChanged: (value) {
                // Also clean state values
                final cleaned = value?.replaceAll(RegExp(r'[\u{1F1E6}-\u{1F1FF}]|\p{Emoji_Presentation}|\p{Emoji}\uFE0F', unicode: true), '').trim();
                setState(() {
                  stateValue = cleaned;
                });
              },
              onCityChanged: (value) {
                setState(() {
                  cityValue = value;
                });
              },
            ),
              ],
            ),
          ),
        ),
        
        // FIXED FOOTER - Save button stays at bottom
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : () async {
                if (countryValue != null && selectedMemberIds.isNotEmpty) {
                  setState(() => _isSaving = true);
                  try {
                    await widget.onLocationSelected(
                      countryValue!, 
                      stateValue, 
                      startDate, 
                      endDate,
                      selectedMemberIds.toList(),
                    );
                    if (mounted) {
                      Navigator.pop(context, true);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _isSaving = false);
                    }
                  }
                } else if (countryValue == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please select a country")),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please select at least one member")),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.getButtonBackground(context),
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving 
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    "Save Location for ${selectedMemberIds.length} member${selectedMemberIds.length > 1 ? 's' : ''} " 
                    "($_dayCount day${_dayCount > 1 ? 's' : ''})"
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

