import 'package:intl/intl.dart';

/// Date and text formatting used across screens.
///
/// Centralised so "20 Jan 2026" cannot become "Jan 20, 2026" on one screen
/// and "2026-01-20" on another — Task 09 is graded on consistency.
abstract final class Formatters {
  static final DateFormat _date = DateFormat('d MMM yyyy');
  static final DateFormat _dateTime = DateFormat('d MMM yyyy, HH:mm');

  static String date(DateTime? value) =>
      value == null ? '—' : _date.format(value);

  static String dateTime(DateTime? value) =>
      value == null ? '—' : _dateTime.format(value.toLocal());

  /// "Due in 3 days" / "Overdue by 2 days" / "Due today".
  ///
  /// [now] is a parameter rather than DateTime.now() so this is testable and
  /// so a whole list renders against one consistent instant.
  static String relativeDue(DateTime? due, DateTime now) {
    if (due == null) return 'No due date';

    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(due.year, due.month, due.day);
    final days = target.difference(today).inDays;

    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    if (days == -1) return 'Overdue by 1 day';
    if (days < 0) return 'Overdue by ${-days} days';
    if (days < 7) return 'Due in $days days';
    return 'Due ${_date.format(due)}';
  }

  static String count(int value, String singular, [String? plural]) =>
      value == 1 ? '1 $singular' : '$value ${plural ?? '${singular}s'}';
}
