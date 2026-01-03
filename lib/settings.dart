import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'firestore_service.dart';
import 'services/notification_service.dart';

class SettingsDialog extends StatefulWidget {
  final String currentUserId;

  const SettingsDialog({super.key, required this.currentUserId});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final FirestoreService _firestoreService = FirestoreService();
  List<String> _holidayCountries = [];
  List<String> _religiousCalendars = [];
  String _tileCalendarDisplay = 'none'; // none, chinese, islamic
  String _themeMode = 'system'; // system, light, dark
  double _textScaleFactor = 1.0; // Text/font size scale (0.8 to 1.5)
  
  // Privacy settings - who can edit my data
  bool _blockAllAdminEdits = false;
  bool _blockDefaultLocation = false;
  bool _blockLocationDate = false;  // Block location for certain date
  bool _blockBirthday = false;
  bool _blockLunarBirthday = false;
  
  // Push notification settings
  bool _pushNotificationsEnabled = true;

  final Map<String, String> _countryMap = {
    "US": "United States",
    "GB": "United Kingdom",
    "CA": "Canada",
    "AU": "Australia",
    "NZ": "New Zealand",
    "SG": "Singapore",
    "MY": "Malaysia",
    "ID": "Indonesia",
    "TH": "Thailand",
    "PH": "Philippines",
    "VN": "Vietnam",
    "JP": "Japan",
    "KR": "South Korea",
    "CN": "China",
    "HK": "Hong Kong",
    "TW": "Taiwan",
    "IN": "India",
    "DE": "Germany",
    "FR": "France",
    "IT": "Italy",
    "ES": "Spain",
    "NL": "Netherlands",
    "BE": "Belgium",
    "CH": "Switzerland",
    "AT": "Austria",
    "SE": "Sweden",
    "NO": "Norway",
    "DK": "Denmark",
    "FI": "Finland",
    "PL": "Poland",
    "IE": "Ireland",
    "PT": "Portugal",
    "GR": "Greece",
    "BR": "Brazil",
    "MX": "Mexico",
    "AR": "Argentina",
    "CL": "Chile",
    "CO": "Colombia",
    "ZA": "South Africa",
    "EG": "Egypt",
    "NG": "Nigeria",
    "RU": "Russia",
    "TR": "Turkey",
    "SA": "Saudi Arabia",
    "AE": "United Arab Emirates",
    "IL": "Israel",
  };

  final Map<String, String> _religiousCalendarMap = {
    'chinese': '🏮 Chinese Lunar Calendar (农历)',
    'islamic': '☪️ Islamic Calendar (Hijri)',
    'jewish': '✡️ Jewish Calendar',
    'hindu': '🕉️ Hindu Calendar',
    'christian': '✝️ Christian Calendar',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.currentUserId).get();
    
    // Load push notification preference from local storage (outside setState)
    final prefs = await SharedPreferences.getInstance();
    final pushEnabled = prefs.getBool('push_notifications_enabled') ?? true;
    
    if (doc.exists) {
      setState(() {
        final data = doc.data();
        final additional = data?['additionalHolidayCountry'];
        if (additional != null && additional is String && additional.isNotEmpty) {
          _holidayCountries = [additional];
        } else {
          _holidayCountries = [];
        }
        
        // Load religious calendars (for public holiday API)
        final religious = data?['religiousCalendars'];
        if (religious != null && religious is List) {
          _religiousCalendars = List<String>.from(religious);
        } else {
          _religiousCalendars = [];
        }
        
        // Load tile calendar display preference
        final tileDisplay = data?['tileCalendarDisplay'];
        if (tileDisplay != null && tileDisplay is String) {
          _tileCalendarDisplay = tileDisplay;
        } else {
          _tileCalendarDisplay = 'none';
        }

        // Load theme mode
        final theme = data?['themeMode'];
        if (theme != null && theme is String) {
          _themeMode = theme;
        } else {
          _themeMode = 'system';
        }

        // Load text scale factor
        final textScale = data?['textScaleFactor'];
        if (textScale != null && textScale is num) {
          _textScaleFactor = textScale.toDouble().clamp(0.8, 1.5);
        } else {
          _textScaleFactor = 1.0;
        }

        // Load privacy settings
        final privacy = data?['privacySettings'] as Map<String, dynamic>?;
        if (privacy != null) {
          _blockDefaultLocation = privacy['blockDefaultLocation'] ?? false;
          _blockLocationDate = privacy['blockLocationDate'] ?? false;
          _blockBirthday = privacy['blockBirthday'] ?? false;
          _blockLunarBirthday = privacy['blockLunarBirthday'] ?? false;
          _blockAllAdminEdits = _blockDefaultLocation && _blockLocationDate && _blockBirthday && _blockLunarBirthday;
        }
        
        // Apply push notification preference (loaded above, outside setState)
        _pushNotificationsEnabled = pushEnabled;
      });
    }
  }

  Future<void> _saveSettings() async {
    print('[Settings] Saving themeMode: $_themeMode');
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.currentUserId).set({
        'additionalHolidayCountry': _holidayCountries.isNotEmpty ? _holidayCountries[0] : null,
        'religiousCalendars': _religiousCalendars,
        'tileCalendarDisplay': _tileCalendarDisplay,
        'themeMode': _themeMode,
        'textScaleFactor': _textScaleFactor,
        'privacySettings': {
          'blockDefaultLocation': _blockDefaultLocation,
          'blockLocationDate': _blockLocationDate,
          'blockBirthday': _blockBirthday,
          'blockLunarBirthday': _blockLunarBirthday,
        },
      }, SetOptions(merge: true));
      
      print('[Settings] Save successful');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Settings Saved")));
        Navigator.pop(context);
      }
    } catch (e) {
      print('[Settings] Save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving settings: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final isNarrow = screenWidth < 450;
        final isVeryNarrow = screenWidth < 380;
        
        // Use 95% of screen width on mobile, capped at 500 for larger screens
        final dialogWidth = screenWidth < 550 ? screenWidth * 0.95 : 500.0;
        
        // Responsive text styles
        final sectionTitleStyle = TextStyle(
          fontSize: isVeryNarrow ? 14 : (isNarrow ? 15 : 16),
          fontWeight: FontWeight.bold,
        );
        final bodyTextStyle = TextStyle(
          fontSize: isVeryNarrow ? 12 : (isNarrow ? 13 : 14),
        );
        final smallTextStyle = TextStyle(
          fontSize: isVeryNarrow ? 11 : (isNarrow ? 12 : 13),
        );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isVeryNarrow ? 8 : (isNarrow ? 12 : 24),
        vertical: 24,
      ),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // FIXED HEADER
            Padding(
              padding: EdgeInsets.fromLTRB(
                isNarrow ? 12 : 20, 
                isNarrow ? 12 : 20, 
                isNarrow ? 8 : 20, 
                isNarrow ? 8 : 10
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Settings", style: TextStyle(
                    fontSize: isNarrow ? 18 : 20, 
                    fontWeight: FontWeight.bold
                  )),
                  IconButton(
                    icon: const Icon(Icons.close),
                    iconSize: isNarrow ? 20 : 24,
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: isNarrow ? 32 : 48,
                      minHeight: isNarrow ? 32 : 48,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            // SCROLLABLE CONTENT
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isVeryNarrow ? 12 : (isNarrow ? 16 : 20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Holiday Countries Section
                    Text("Public Holidays", style: sectionTitleStyle),
                    SizedBox(height: isNarrow ? 4 : 5),
                    Text(
                      "Your default location country will be used automatically. You can add one additional country.",
                      style: bodyTextStyle,
                    ),
                    SizedBox(height: isNarrow ? 8 : 10),
                    
                    // Show what will be used
                    StreamBuilder<Map<String, dynamic>>(
                      stream: _firestoreService.getUserProfileStream(widget.currentUserId),
                      initialData: _firestoreService.getLastSeenProfile(widget.currentUserId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final data = snapshot.data;
                        String? defaultLocation;
                        if (data != null) {
                          defaultLocation = data['defaultLocation'];
                        }
                        
                        String? primaryCountry;
                        if (defaultLocation != null && defaultLocation.isNotEmpty) {
                          final parts = defaultLocation.split(',');
                          
                          for (var part in parts) {
                            var cleanPart = part.trim();
                            // Check exact match
                            final entry = _countryMap.entries.firstWhere(
                              (e) => e.value == cleanPart, 
                              orElse: () => MapEntry('', '')
                            );
                            
                            if (entry.key.isNotEmpty) {
                              primaryCountry = entry.key;
                              break;
                            }
                            
                            // Check if part contains country name
                            final matchEntry = _countryMap.entries.firstWhere(
                              (e) => cleanPart.contains(e.value), 
                              orElse: () => MapEntry('', '')
                            );
                            
                            if (matchEntry.key.isNotEmpty) {
                              primaryCountry = matchEntry.key;
                              break;
                            }
                          }
                        }
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (primaryCountry != null) ...[
                              Text(
                                "Primary: ${_countryMap[primaryCountry] ?? primaryCountry} (from your default location)", 
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: isVeryNarrow ? 12 : (isNarrow ? 13 : 14),
                                ),
                              ),
                              SizedBox(height: isNarrow ? 8 : 10),
                            ] else ...[
                              Text(
                                "⚠️ Set your default location in Profile to enable holidays", 
                                style: TextStyle(
                                  color: Colors.orange, 
                                  fontWeight: FontWeight.w500,
                                  fontSize: isVeryNarrow ? 12 : (isNarrow ? 13 : 14),
                                ),
                              ),
                              SizedBox(height: isNarrow ? 8 : 10),
                            ],
                          ],
                        );
                      },
                    ),
                    
                    // Additional country selection
                    if (_holidayCountries.isNotEmpty) ...[
                      Chip(
                        label: Text(
                          "Additional: ${_countryMap[_holidayCountries[0]] ?? _holidayCountries[0]}",
                          style: smallTextStyle,
                        ),
                        onDeleted: () {
                          setState(() {
                            _holidayCountries.clear();
                          });
                        },
                      ),
                      SizedBox(height: isNarrow ? 8 : 10),
                    ],
                    
                    // Add additional country button
                    if (_holidayCountries.isEmpty)
                      DropdownButtonFormField<String>(
                        value: null,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: "Add Additional Country",
                          labelStyle: smallTextStyle,
                          filled: true,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.grey.shade600 
                                  : Colors.grey.shade300,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isNarrow ? 10 : 12,
                            vertical: isNarrow ? 12 : 16,
                          ),
                        ),
                        hint: Text(
                          isVeryNarrow ? "Add (Optional)" : "Add Additional Country (Optional)",
                          style: smallTextStyle,
                        ),
                        isExpanded: true,
                        style: bodyTextStyle.copyWith(color: Theme.of(context).colorScheme.onSurface),
                        items: _countryMap.entries
                            .map((entry) => DropdownMenuItem(
                              value: entry.key, 
                              child: Text(entry.value, style: bodyTextStyle)
                            )).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _holidayCountries = [value];
                            });
                          }
                        },
                      ),

                    SizedBox(height: isNarrow ? 16 : 20),
                    
                    DropdownButtonFormField<String>(
                      value: _themeMode,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: "App Theme",
                        labelStyle: smallTextStyle,
                        prefixIcon: Icon(Icons.brightness_6, size: isNarrow ? 20 : 24),
                        filled: true,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.grey.shade600 
                                : Colors.grey.shade300,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 10 : 12,
                          vertical: isNarrow ? 12 : 16,
                        ),
                      ),
                      isExpanded: true,
                      style: bodyTextStyle.copyWith(color: Theme.of(context).colorScheme.onSurface),
                      items: [
                        DropdownMenuItem(value: 'system', child: Text('System Default', style: bodyTextStyle)),
                        DropdownMenuItem(value: 'light', child: Text('Light Mode', style: bodyTextStyle)),
                        DropdownMenuItem(value: 'dark', child: Text('Dark Mode', style: bodyTextStyle)),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _themeMode = value;
                          });
                        }
                      },
                    ),

                    SizedBox(height: isNarrow ? 16 : 20),

                    // Calendar Tile Display Setting
                    Text("Calendar Tile Display", style: sectionTitleStyle),
                    SizedBox(height: isNarrow ? 4 : 5),
                    Text("Choose which calendar system to show on calendar tiles:", style: bodyTextStyle),
                    SizedBox(height: isNarrow ? 8 : 10),
                    
                    DropdownButtonFormField<String>(
                      value: _tileCalendarDisplay,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: "Tile Calendar Display",
                        labelStyle: smallTextStyle,
                        filled: true,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.grey.shade600 
                                : Colors.grey.shade300,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 10 : 12,
                          vertical: isNarrow ? 12 : 16,
                        ),
                      ),
                      isExpanded: true,
                      style: bodyTextStyle.copyWith(color: Theme.of(context).colorScheme.onSurface),
                      items: [
                        DropdownMenuItem(value: 'none', child: Text('None - Gregorian only', style: bodyTextStyle)),
                        DropdownMenuItem(value: 'chinese', child: Text('🏮 Chinese Lunar (农历)', style: bodyTextStyle)),
                        DropdownMenuItem(value: 'islamic', child: Text('☪️ Islamic Hijri', style: bodyTextStyle)),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _tileCalendarDisplay = value;
                          });
                        }
                      },
                    ),

                    SizedBox(height: isNarrow ? 16 : 20),

                    // Text Size / Font Scale Setting (Accessibility)
                    Text("Text Size", style: sectionTitleStyle),
                    SizedBox(height: isNarrow ? 4 : 5),
                    Text("Adjust text size for easier reading:", style: bodyTextStyle),
                    SizedBox(height: isNarrow ? 8 : 10),
                    
                    DropdownButtonFormField<double>(
                      value: _textScaleFactor,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: "Font Size",
                        labelStyle: smallTextStyle,
                        prefixIcon: Icon(Icons.text_fields, size: isNarrow ? 20 : 24),
                        filled: true,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.grey.shade600 
                                : Colors.grey.shade300,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 10 : 12,
                          vertical: isNarrow ? 12 : 16,
                        ),
                      ),
                      isExpanded: true,
                      style: bodyTextStyle.copyWith(color: Theme.of(context).colorScheme.onSurface),
                      items: [
                        DropdownMenuItem(value: 0.8, child: Text('Small (80%)', style: bodyTextStyle)),
                        DropdownMenuItem(value: 0.9, child: Text('Slightly Small (90%)', style: bodyTextStyle)),
                        DropdownMenuItem(value: 1.0, child: Text('Default (100%)', style: bodyTextStyle)),
                        DropdownMenuItem(value: 1.1, child: Text('Slightly Large (110%)', style: bodyTextStyle)),
                        DropdownMenuItem(value: 1.2, child: Text('Large (120%)', style: bodyTextStyle)),
                        DropdownMenuItem(value: 1.3, child: Text('Extra Large (130%)', style: bodyTextStyle)),
                        DropdownMenuItem(value: 1.5, child: Text('Maximum (150%)', style: bodyTextStyle)),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _textScaleFactor = value;
                          });
                        }
                      },
                    ),

                    SizedBox(height: isNarrow ? 16 : 20),
                    
                    // Religious Calendars for Public Holidays
                    Text("Religious Public Holidays", style: sectionTitleStyle),
                    SizedBox(height: isNarrow ? 4 : 5),
                    Text("Select religious calendars to fetch public holidays (Ramadan, Eid, Chinese New Year, etc.):", style: bodyTextStyle),
                    SizedBox(height: isNarrow ? 8 : 10),
                    
                    // Religious calendar checkboxes
                    ..._religiousCalendarMap.entries.map((entry) {
                      final isSelected = _religiousCalendars.contains(entry.key);
                      return CheckboxListTile(
                        title: Text(entry.value, style: bodyTextStyle),
                        value: isSelected,
                        dense: isNarrow,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _religiousCalendars.add(entry.key);
                            } else {
                              _religiousCalendars.remove(entry.key);
                            }
                          });
                        },
                      );
                    }),

                    SizedBox(height: isNarrow ? 16 : 20),
                    
                    // Privacy Settings Section
                    Text("Privacy Settings", style: sectionTitleStyle),
                    SizedBox(height: isNarrow ? 4 : 5),
                    Text("Control what group admins/owners can edit on your behalf:", style: bodyTextStyle),
                    SizedBox(height: isNarrow ? 8 : 10),
                    
                    // Select All toggle
                    CheckboxListTile(
                      title: Text("Block All Admin Edits", style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isVeryNarrow ? 13 : (isNarrow ? 14 : 15),
                      )),
                      subtitle: Text("Prevent admins/owners from editing any of your data", style: smallTextStyle),
                      value: _blockAllAdminEdits,
                      dense: isNarrow,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (bool? value) {
                        setState(() {
                          _blockAllAdminEdits = value ?? false;
                          _blockDefaultLocation = value ?? false;
                          _blockLocationDate = value ?? false;
                          _blockBirthday = value ?? false;
                          _blockLunarBirthday = value ?? false;
                        });
                      },
                    ),
                    
                    const Divider(),
                    
                    // Per-field toggles
                    CheckboxListTile(
                      title: Text("Block Default Location", style: bodyTextStyle),
                      subtitle: Text("Prevent editing your default location in profile", style: smallTextStyle),
                      value: _blockDefaultLocation,
                      dense: isNarrow,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (bool? value) {
                        setState(() {
                          _blockDefaultLocation = value ?? false;
                          _blockAllAdminEdits = _blockDefaultLocation && _blockLocationDate && _blockBirthday && _blockLunarBirthday;
                        });
                      },
                    ),
                    
                    CheckboxListTile(
                      title: Text("Block Location for Date", style: bodyTextStyle),
                      subtitle: Text("Prevent setting your location for specific dates", style: smallTextStyle),
                      value: _blockLocationDate,
                      dense: isNarrow,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (bool? value) {
                        setState(() {
                          _blockLocationDate = value ?? false;
                          _blockAllAdminEdits = _blockDefaultLocation && _blockLocationDate && _blockBirthday && _blockLunarBirthday;
                        });
                      },
                    ),
                    
                    CheckboxListTile(
                      title: Text("Block Birthday", style: bodyTextStyle),
                      subtitle: Text("Prevent editing your birthday", style: smallTextStyle),
                      value: _blockBirthday,
                      dense: isNarrow,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (bool? value) {
                        setState(() {
                          _blockBirthday = value ?? false;
                          _blockAllAdminEdits = _blockDefaultLocation && _blockLocationDate && _blockBirthday && _blockLunarBirthday;
                        });
                      },
                    ),
                    
                    CheckboxListTile(
                      title: Text("Block Lunar Birthday", style: bodyTextStyle),
                      subtitle: Text("Prevent editing your lunar birthday", style: smallTextStyle),
                      value: _blockLunarBirthday,
                      dense: isNarrow,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (bool? value) {
                        setState(() {
                          _blockLunarBirthday = value ?? false;
                          _blockAllAdminEdits = _blockDefaultLocation && _blockLocationDate && _blockBirthday && _blockLunarBirthday;
                        });
                      },
                    ),

                    SizedBox(height: isNarrow ? 16 : 20),
                    
                    // Push Notifications Section
                    Text("Push Notifications", style: sectionTitleStyle),
                    SizedBox(height: isNarrow ? 4 : 5),
                    Text("Control mobile push notifications for this device:", style: bodyTextStyle),
                    SizedBox(height: isNarrow ? 8 : 10),
                    
                    SwitchListTile(
                      title: Text("Enable Push Notifications", style: bodyTextStyle),
                      subtitle: Text(
                        _pushNotificationsEnabled 
                            ? "You'll receive push notifications on this device"
                            : "Push notifications are disabled (in-app still work)",
                        style: smallTextStyle,
                      ),
                      value: _pushNotificationsEnabled,
                      dense: isNarrow,
                      contentPadding: EdgeInsets.zero,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (bool value) async {
                        setState(() {
                          _pushNotificationsEnabled = value;
                        });
                        // Save immediately to local storage
                        await NotificationService().setPushEnabled(value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            // FIXED FOOTER - Save button stays at bottom
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(isNarrow ? 12 : 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.getButtonBackground(context),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isNarrow ? 12 : 14),
                  ),
                  child: Text("Save Settings", style: TextStyle(fontSize: isNarrow ? 14 : 16)),
                ),
              ),
            ),
          ],
        ),
      ),
        );
      },
    );
  }
}
