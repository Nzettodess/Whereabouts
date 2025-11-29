import 'package:http/http.dart' as http;
import 'dart:convert';
import 'models.dart';
import 'environment.dart';

class HolidayService {
  static const String _calendarificBaseUrl = 'https://calendarific.com/api/v2/holidays';
  static String get _calendarificApiKey => Environment.calendarificApiKey;
  
  static const String _festivoBaseUrl = 'https://api.getfestivo.com/v2/holidays';
  static String get _festivoApiKey => Environment.festivoApiKey;

  Future<List<Holiday>> fetchHolidays(String countryCode, int year, {String provider = 'Calendarific'}) async {
    if (provider == 'Festivo') {
      return _fetchFestivo(countryCode, year);
    } else {
      return _fetchCalendarific(countryCode, year);
    }
  }

  Future<List<Holiday>> _fetchCalendarific(String countryCode, int year) async {
    try {
      final response = await http.get(Uri.parse('$_calendarificBaseUrl?api_key=$_calendarificApiKey&country=$countryCode&year=$year'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final holidays = data['response']['holidays'] as List<dynamic>;
        return holidays.map((json) => Holiday.fromJsonCalendarific(json)).toList();
      } else {
        print('Calendarific Failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching Calendarific: $e');
      return [];
    }
  }

  Future<List<Holiday>> _fetchFestivo(String countryCode, int year) async {
    // Festivo API requires a paid plan (returns 402 Payment Required)
    // Keeping code for reference but returning empty list
    print('Festivo API requires a paid subscription plan. Please use Calendarific instead.');
    return [];
    
    /* Original Festivo code - requires paid plan
    try {
      final response = await http.get(
        Uri.parse('$_festivoBaseUrl?country=$countryCode&year=$year'),
        headers: {
          'Authorization': 'Bearer $_festivoApiKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final holidays = data['holidays'] as List<dynamic>;
        return holidays.map((json) => Holiday.fromJsonFestivo(json)).toList();
      } else {
        print('Festivo Failed: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching Festivo: $e');
      return [];
    }
    */
  }
}
