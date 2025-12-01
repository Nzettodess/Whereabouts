import 'package:flutter/material.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
import 'package:intl/intl.dart';
import 'widgets/syncfusion_date_picker.dart';

class LocationPicker extends StatefulWidget {
  final Function(String country, String? state, DateTime startDate, DateTime endDate) onLocationSelected;
  final String? defaultCountry;
  final String? defaultState;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const LocationPicker({
    super.key, 
    required this.onLocationSelected,
    this.defaultCountry,
    this.defaultState,
    this.initialStartDate,
    this.initialEndDate,
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

  @override
  void initState() {
    super.initState();
    // Initialize with default values
    countryValue = widget.defaultCountry;
    stateValue = widget.defaultState;
    
    // Initialize date range
    startDate = widget.initialStartDate ?? DateTime.now();
    endDate = widget.initialEndDate ?? DateTime.now();
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
    return Container(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Set Your Location",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Date Range Selection
            const Text(
              "Date Range",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
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
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Start Date",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "End Date",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    "$_dayCount day${_dayCount > 1 ? 's' : ''} selected",
                    style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Location Selection
            const Text(
              "Location",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            CSCPickerPlus(
              showCities: false,
              defaultCountry: _getCountryEnum(countryValue) ?? CscCountry.United_States,
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (countryValue != null) {
                    widget.onLocationSelected(countryValue!, stateValue, startDate, endDate);
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please select a country")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text("Save Location for $_dayCount day${_dayCount > 1 ? 's' : ''}"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
