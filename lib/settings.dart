import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsDialog extends StatefulWidget {
  final String currentUserId;

  const SettingsDialog({super.key, required this.currentUserId});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  List<String> _holidayCountries = [];
  List<String> _religiousCalendars = [];
  String _tileCalendarDisplay = 'none'; // none, chinese, islamic

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
      });
    }
  }

  Future<void> _saveSettings() async {
    await FirebaseFirestore.instance.collection('users').doc(widget.currentUserId).update({
      'additionalHolidayCountry': _holidayCountries.isNotEmpty ? _holidayCountries[0] : null,
      'religiousCalendars': _religiousCalendars,
      'tileCalendarDisplay': _tileCalendarDisplay,
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Settings Saved")));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // FIXED HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Settings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1),
            
            // SCROLLABLE CONTENT
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Holiday Countries Section
                    const Text("Public Holidays", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    const Text("Your default location country will be used automatically. You can add one additional country."),
                    const SizedBox(height: 10),
                    
                    // Show what will be used
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').doc(widget.currentUserId).snapshots(),
                      builder: (context, snapshot) {
                        String? defaultLocation;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data = snapshot.data!.data() as Map<String, dynamic>?;
                          defaultLocation = data?['defaultLocation'];
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
                            if (primaryCountry != null) ...[ Text("Primary: ${_countryMap[primaryCountry] ?? primaryCountry} (from your default location)", 
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 10),
                            ] else ...[
                              const Text("⚠️ Set your default location in Profile to enable holidays", 
                                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 10),
                            ],
                          ],
                        );
                      },
                    ),
                    
                    // Additional country selection
                    if (_holidayCountries.isNotEmpty) ...[
                      Chip(
                        label: Text("Additional: ${_countryMap[_holidayCountries[0]] ?? _holidayCountries[0]}"),
                        onDeleted: () {
                          setState(() {
                            _holidayCountries.clear();
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    
                    // Add additional country button
                    if (_holidayCountries.isEmpty)
                      DropdownButtonFormField<String>(
                        value: null,
                        hint: const Text("Add Additional Country (Optional)"),
                        items: _countryMap.entries
                            .map((entry) => DropdownMenuItem(
                              value: entry.key, 
                              child: Text(entry.value)
                            )).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _holidayCountries = [value];
                            });
                          }
                        },
                      ),

                    const SizedBox(height: 20),
                    
                    // Calendar Tile Display Setting
                    const Text("Calendar Tile Display", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    const Text("Choose which calendar system to show on calendar tiles:"),
                    const SizedBox(height: 10),
                    
                    DropdownButtonFormField<String>(
                      value: _tileCalendarDisplay,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "Tile Calendar Display",
                      ),
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('None - Gregorian only')),
                        DropdownMenuItem(value: 'chinese', child: Text('🏮 Chinese Lunar (农历)')),
                        DropdownMenuItem(value: 'islamic', child: Text('☪️ Islamic Hijri')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _tileCalendarDisplay = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 20),
                    
                    // Religious Calendars for Public Holidays
                    const Text("Religious Public Holidays (API)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    const Text("Select religious calendars to fetch public holidays (Ramadan, Eid, Chinese New Year, etc.):"),
                    const SizedBox(height: 10),
                    
                    // Religious calendar checkboxes
                    ..._religiousCalendarMap.entries.map((entry) {
                      final isSelected = _religiousCalendars.contains(entry.key);
                      return CheckboxListTile(
                        title: Text(entry.value),
                        value: isSelected,
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
                    }).toList(),

                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveSettings,
                        child: const Text("Save Settings"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
