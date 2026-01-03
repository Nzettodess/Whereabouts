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
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 400;
    final isVeryNarrow = screenWidth < 375;
    
    // Responsive width: 95% on very narrow, 90% on narrow, 420 max on larger
    final dialogWidth = isVeryNarrow 
        ? screenWidth * 0.95 
        : (isNarrow ? screenWidth * 0.92 : 420.0);
    final dialogPadding = isVeryNarrow ? 10.0 : (isNarrow ? 14.0 : 20.0);
    
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isVeryNarrow ? 8 : (isNarrow ? 12 : 24),
        vertical: 24,
      ),
      child: Container(
        width: dialogWidth,
        padding: EdgeInsets.all(dialogPadding),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.helpText,
                      style: TextStyle(
                        fontSize: isVeryNarrow ? 16 : (isNarrow ? 18 : 20), 
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: isVeryNarrow ? 32 : 48,
                      minHeight: isVeryNarrow ? 32 : 48,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              SizedBox(height: isVeryNarrow ? 6 : 12),
              
              // View mode buttons with clear labels - responsive
              Builder(builder: (context) {
                final screenWidth = MediaQuery.of(context).size.width;
                final isVeryNarrow = screenWidth < 390;
                return Container(
                  padding: EdgeInsets.symmetric(vertical: isVeryNarrow ? 4 : 8),
                  child: Column(
                    children: [
                      if (!isVeryNarrow)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            const Text(
                              'Switch view:',
                              style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      SizedBox(height: isVeryNarrow ? 0 : 6),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: isVeryNarrow ? 4 : 8,
                        runSpacing: 4,
                        children: [
                          _buildViewButton('Years', DateRangePickerView.decade, Icons.calendar_view_month, isVeryNarrow),
                          _buildViewButton('Months', DateRangePickerView.year, Icons.grid_view, isVeryNarrow),
                          _buildViewButton('Days', DateRangePickerView.month, Icons.calendar_today, isVeryNarrow),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              SizedBox(height: isVeryNarrow ? 6 : 12),
              
              // Date picker - reduced height on narrow screens
              Container(
                height: isVeryNarrow ? 250 : 280,
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
            SizedBox(height: isVeryNarrow ? 6 : 10),
            
            // Helper text based on current view
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isVeryNarrow ? 8 : 12, 
                vertical: isVeryNarrow ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, size: isVeryNarrow ? 14 : 16, color: Colors.blue.shade700),
                  SizedBox(width: isVeryNarrow ? 4 : 8),
                  Expanded(
                    child: Text(
                      isVeryNarrow ? _getShortHelperText() : _getHelperText(),
                      style: TextStyle(fontSize: isVeryNarrow ? 10 : 12, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isVeryNarrow ? 6 : 10),
            
            // Selected date display
            Container(
              padding: EdgeInsets.all(isVeryNarrow ? 8 : 12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event, size: isVeryNarrow ? 16 : 20, color: Colors.deepPurple),
                  SizedBox(width: isVeryNarrow ? 4 : 8),
                  Text(
                    'Selected: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                    style: TextStyle(
                      fontSize: isVeryNarrow ? 13 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isVeryNarrow ? 8 : 12),
            
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

  String _getShortHelperText() {
    switch (currentView) {
      case DateRangePickerView.decade:
        return 'Select a year. Swipe to scroll.';
      case DateRangePickerView.year:
        return 'Select a month.';
      case DateRangePickerView.month:
        return 'Select a day. Use arrows to navigate months.';
      default:
        return 'Select a date.';
    }
  }

  Widget _buildViewButton(String label, DateRangePickerView view, IconData icon, [bool isVeryNarrow = false]) {
    final isActive = currentView == view;
    return ElevatedButton.icon(
      onPressed: () => _changeView(view),
      icon: Icon(icon, size: isVeryNarrow ? 14 : 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.deepPurple : Colors.grey.shade200,
        foregroundColor: isActive ? Colors.white : Colors.black87,
        elevation: isActive ? 2 : 0,
        padding: EdgeInsets.symmetric(
          horizontal: isVeryNarrow ? 8 : 12,
          vertical: isVeryNarrow ? 6 : 8,
        ),
        textStyle: TextStyle(fontSize: isVeryNarrow ? 11 : 13, fontWeight: FontWeight.w500),
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
