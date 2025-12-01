import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:intl/intl.dart';

/// Custom date picker dialog using Syncfusion with better navigation
/// Supports year → month → day selection flow
class SyncfusionDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String helpText;

  const SyncfusionDatePickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.helpText = 'Select Date',
  });

  @override
  State<SyncfusionDatePickerDialog> createState() => _SyncfusionDatePickerDialogState();
}

class _SyncfusionDatePickerDialogState extends State<SyncfusionDatePickerDialog> {
  late DateTime selectedDate;
  late DateRangePickerView currentView;
  final DateRangePickerController _controller = DateRangePickerController();

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate;
    // Start with month view (day calendar) for familiarity
    currentView = DateRangePickerView.month;
    _controller.selectedDate = selectedDate;
    _controller.displayDate = selectedDate;
    _controller.view = currentView;
  }

  void _changeView(DateRangePickerView newView) {
    setState(() {
      currentView = newView;
      _controller.view = newView;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.helpText,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),
              
              // View mode buttons with clear labels
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text(
                      'Switch view:',
                      style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 12),
                    _buildViewButton('Years', DateRangePickerView.decade, Icons.calendar_view_month),
                    const SizedBox(width: 8),
                    _buildViewButton('Months', DateRangePickerView.year, Icons.grid_view),
                    const SizedBox(width: 8),
                    _buildViewButton('Days', DateRangePickerView.month, Icons.calendar_today),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Date picker - reduced height
              Container(
                height: 280,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
              child: SfDateRangePicker(
                controller: _controller,
                view: currentView,
                initialSelectedDate: selectedDate,
                minDate: widget.firstDate,
                maxDate: widget.lastDate,
                onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                  if (args.value is DateTime) {
                    setState(() {
                      selectedDate = args.value;
                    });
                  }
                },
                selectionMode: DateRangePickerSelectionMode.single,
                showNavigationArrow: true, // Show arrows for navigation
                navigationDirection: DateRangePickerNavigationDirection.vertical,
                headerStyle: const DateRangePickerHeaderStyle(
                  textAlign: TextAlign.center,
                  textStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                monthViewSettings: const DateRangePickerMonthViewSettings(
                  viewHeaderStyle: DateRangePickerViewHeaderStyle(
                    textStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                yearCellStyle: const DateRangePickerYearCellStyle(
                  textStyle: TextStyle(fontSize: 14),
                  todayTextStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                selectionColor: Colors.deepPurple,
                todayHighlightColor: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 10),
            
            // Helper text based on current view
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getHelperText(),
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            
            // Selected date display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event, size: 20, color: Colors.deepPurple),
                  const SizedBox(width: 8),
                  Text(
                    'Selected: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, selectedDate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('OK'),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  String _getHelperText() {
    switch (currentView) {
      case DateRangePickerView.decade:
        return 'Select a year. Use arrows to scroll through decades (swipe up/down).';
      case DateRangePickerView.year:
        return 'Select a month from the grid below.';
      case DateRangePickerView.month:
        return 'Select a day. Use arrows to navigate months.';
      default:
        return 'Select a date from the calendar.';
    }
  }

  Widget _buildViewButton(String label, DateRangePickerView view, IconData icon) {
    final isActive = currentView == view;
    return ElevatedButton.icon(
      onPressed: () => _changeView(view),
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.deepPurple : Colors.grey.shade200,
        foregroundColor: isActive ? Colors.white : Colors.black87,
        elevation: isActive ? 2 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Helper function to show the Syncfusion date picker
Future<DateTime?> showSyncfusionDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String helpText = 'Select Date',
}) async {
  return await showDialog<DateTime>(
    context: context,
    builder: (context) => SyncfusionDatePickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
    ),
  );
}
