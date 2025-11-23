import 'package:hijri/hijri_calendar.dart';
import 'package:lunar/lunar.dart';

class ReligiousCalendarHelper {
  // Convert Gregorian date to Hijri (Islamic) date
  static String getHijriDate(DateTime gregorianDate) {
    try {
      final hijri = HijriCalendar.fromDate(gregorianDate);
      return '${hijri.hDay}/${hijri.hMonth}';
    } catch (e) {
      return '';
    }
  }

  static String _getHijriMonthName(int month) {
    const months = [
      'Muharram', 'Safar', 'Rabi\' al-Awwal', 'Rabi\' al-Thani',
      'Jumada al-Awwal', 'Jumada al-Thani', 'Rajab', 'Sha\'ban',
      'Ramadan', 'Shawwal', 'Dhu al-Qi\'dah', 'Dhu al-Hijjah'
    ];
    return month > 0 && month <= 12 ? months[month - 1] : '';
  }

  // Chinese Lunar Calendar using lunar package
  static String getChineseLunarDate(DateTime gregorianDate) {
    try {
      final lunar = Lunar.fromDate(gregorianDate);
      return '🏮 ${lunar.getMonthInChinese()}${lunar.getDayInChinese()}';
    } catch (e) {
      return '';
    }
  }

  // Get all enabled religious calendar dates for a given Gregorian date
  static List<String> getReligiousDates(DateTime date, List<String> enabledCalendars) {
    final dates = <String>[];
    
    if (enabledCalendars.contains('chinese')) {
      final lunar = getChineseLunarDate(date);
      if (lunar.isNotEmpty) dates.add(lunar);
    }
    
    if (enabledCalendars.contains('islamic')) {
      final hijri = getHijriDate(date);
      if (hijri.isNotEmpty) dates.add('☪️ $hijri');
    }
    
    // Add more calendars as needed
    // Jewish, Hindu, etc. would require additional libraries
    
    return dates;
  }
}
