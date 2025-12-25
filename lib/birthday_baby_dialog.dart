import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'models/placeholder_member.dart';
import 'widgets/user_avatar.dart';

class BirthdayBabyDialog extends StatelessWidget {
  final String currentUserId;
  final List<Map<String, dynamic>> allUsers;
  final List<PlaceholderMember> placeholderMembers;
  final Map<String, String> groupNames;

  const BirthdayBabyDialog({
    super.key,
    required this.currentUserId,
    required this.allUsers,
    required this.placeholderMembers,
    required this.groupNames,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final birthdays = _getBirthdaysForMonth(now);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.cake, color: Colors.pink, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Birthday Babies - ${DateFormat('MMMM').format(now)}",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            
            if (birthdays.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  "No birthdays this month 🎂",
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              )
            else
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.only(top: 10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: birthdays.length,
                  itemBuilder: (context, index) {
                    final b = birthdays[index];
                    final isLunar = b.isLunar;
                    
                    // Retrieve user photo if available (for regular users)
                    String? photoUrl;
                    if (!b.userId.startsWith('placeholder_')) {
                      final user = allUsers.firstWhere(
                        (u) => u['uid'] == b.userId,
                        orElse: () => {},
                      );
                      photoUrl = user['photoURL'];
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              Center(
                                child: b.userId.startsWith('placeholder_')
                                  ? CircleAvatar(
                                      radius: 30,
                                      backgroundColor: Colors.grey[200],
                                      child: const Icon(Icons.person_outline, size: 30, color: Colors.grey),
                                    )
                                  : UserAvatar(
                                      name: b.displayName,
                                      photoUrl: photoUrl,
                                      radius: 30,
                                    ),
                              ),
                              if (isLunar)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.indigo,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Text('🏮', style: TextStyle(fontSize: 10)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          b.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          DateFormat('MMM d').format(b.occurrenceDate),
                          style: TextStyle(
                            fontSize: 11,
                            color: isLunar ? Colors.indigo : Colors.grey[700],
                            fontWeight: isLunar ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Birthday> _getBirthdaysForMonth(DateTime now) {
    final items = <Birthday>[];
    final year = now.year;
    final month = now.month;
    
    // 1. Regular Users
    for (final user in allUsers) {
      final uid = user['uid'] as String?;
      if (uid == null) continue;

      // Solar
      final solarBirthday = Birthday.getSolarBirthday(user, year);
      if (solarBirthday != null && solarBirthday.occurrenceDate.month == month) {
        items.add(solarBirthday);
      }

      // Lunar - check all days in month
      final daysInMonth = DateTime(year, month + 1, 0).day;
      for (int d = 1; d <= daysInMonth; d++) {
        final checkDate = DateTime(year, month, d);
        final lunarBirthday = Birthday.getLunarBirthday(user, year, checkDate);
        if (lunarBirthday != null) {
          items.add(lunarBirthday);
        }
      }
    }

    // 2. Placeholder Members
    for (final placeholder in placeholderMembers) {
      // Solar
      if (placeholder.birthday != null) {
        final solarBirthday = Birthday.fromPlaceholderMember(placeholder, year);
        if (solarBirthday != null && solarBirthday.occurrenceDate.month == month) {
          items.add(solarBirthday);
        }
      }

      // Lunar
      if (placeholder.hasLunarBirthday) {
        final daysInMonth = DateTime(year, month + 1, 0).day;
        for (int d = 1; d <= daysInMonth; d++) {
          final checkDate = DateTime(year, month, d);
          final lunarBirthday = Birthday.fromPlaceholderLunar(placeholder, year, checkDate);
          if (lunarBirthday != null) {
            items.add(lunarBirthday);
          }
        }
      }
    }

    // Sort by date (day of month)
    items.sort((a, b) => a.occurrenceDate.day.compareTo(b.occurrenceDate.day));
    
    return items;
  }
}
