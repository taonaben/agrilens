import 'dart:math';
import 'package:intl/intl.dart';

/// Generates a random alphanumeric string with exactly [length] characters.
///
/// Expected outcome:
/// - Returns a string that may contain lowercase letters, uppercase letters,
///   and digits.
/// - Example: for length 6, output might be `aB3kP9`.
String generateRandomString(int length) {
  const characters =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  Random random = Random();
  return String.fromCharCodes(
    Iterable.generate(
      length,
      (_) => characters.codeUnitAt(random.nextInt(characters.length)),
    ),
  );
}

/// Converts a numeric string to an integer.
///
/// Expected outcome:
/// - Returns parsed integer when [input] contains only digits.
/// - Returns 0 when [input] contains letters or mixed/special characters.
/// - Examples: `"42" -> 42`, `"abc" -> 0`, `"12a" -> 0`.
int parseStringToNumber(String input) {
  final numberRegExp = RegExp(r'^\d+$'); // Matches only numbers
  final letterRegExp = RegExp(r'^[a-zA-Z]+$'); // Matches only letters

  if (numberRegExp.hasMatch(input)) {
    return int.parse(input);
  } else if (letterRegExp.hasMatch(input)) {
    return 0;
  } else {
    return 0; // Return -1 if the string contains any other characters
  }
}

/// Capitalizes the first character of [input] and keeps the rest unchanged.
///
/// Expected outcome:
/// - Example: `"harare" -> "Harare"`.
String capitalize(String input) {
  return input[0].toUpperCase() + input.substring(1);
}

/// Formats a date value as `dd-MM-yyyy` in local time.
///
/// Accepts either an ISO date [String] or a [DateTime].
/// Expected outcome:
/// - Valid date returns a formatted date, for example `17-07-2026`.
/// - Invalid/unparseable input returns `00-00-0000`.
String dateFormatted(dynamic date, {bool showMonthName = false}) {
  if (date is String) {
    try {
      date = DateTime.parse(date).toLocal();
    } catch (e) {
      return '00-00-0000';
    }
  }
  if (date is DateTime) {
    return showMonthName
        ? '${twoDigits(date.day)} ${DateFormat('MMM').format(date)} ${date.year}'
        : '${twoDigits(date.day)}-${twoDigits(date.month)}-${date.year}';
  }
  return '00-00-0000';
}

/// Formats a date value as `HH:mm` in local time.
///
/// Accepts either an ISO date [String] or a [DateTime].
/// Expected outcome:
/// - Valid date returns a time like `09:45`.
/// - Invalid/unparseable input returns `00:00`.
String timeFormatted(dynamic date) {
  if (date is String) {
    try {
      date = DateTime.parse(date).toLocal();
    } catch (e) {
      return '--:--';
    }
  }
  if (date is DateTime) {
    return '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }
  return '--:--';
}

/// Formats a date value as `dd MMM,yyyy • HH:mm` in local time.
///
/// Accepts either an ISO date [String] or a [DateTime].
/// Expected outcome:
/// - Valid date returns output like `17 Jul,2026 • 09:45`.
/// - Invalid/unparseable input returns `0000-00-00 00:00`.
String dateTimeFormatted(dynamic date) {
  if (date is String) {
    try {
      date = DateTime.parse(date).toLocal();
    } catch (e) {
      return '0000-00-00 00:00';
    }
  }
  if (date is DateTime) {
    return '${twoDigits(date.day)} ${DateFormat('MMM').format(date)},${date.year} • ${timeFormatted(date)}';
  }
  return '0000-00-00 00:00';
}

/// Returns a compact relative time label for [date].
///
/// Expected outcome:
/// - `< 1 minute` -> `Now`
/// - `< 60 minutes` -> `Xm`
/// - `< 24 hours` -> `Xhr` or `Xhrs`
/// - `< 7 days` -> `Xd`
/// - `< 30 days` -> `Xw`
/// - `< 365 days` -> `Xmo`
/// - Otherwise -> `Xy`
/// - Invalid input -> `Invalid date`.
String timeAgo(dynamic date) {
  final dateTime = _parseToLocalDateTime(date);
  if (dateTime == null) {
    return 'Invalid date';
  }

  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inMinutes < 1) {
    return 'Now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}hr${difference.inHours > 1 ? 's' : ''}';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d';
  } else if (difference.inDays < 30) {
    return '${(difference.inDays / 7).round()}w';
  } else if (difference.inDays < 365) {
    return '${(difference.inDays / 30).round()}mo';
  } else {
    return '${(difference.inDays / 365).round()}y';
  }
}

/// Produces a human-friendly recent-date label for [date].
///
/// Expected outcome:
/// - Same day -> `N hour(s) ago` (or `1 hour ago` when less than 1 hour)
/// - Yesterday -> `Yesterday`
/// - Within last 3 days -> weekday name, for example `Tuesday`
/// - Older -> formatted date from [dateFormatted], for example `14-07-2026`
/// - Invalid input -> `Invalid date`.
String formatRecentDateLabel(dynamic date, {DateTime? now}) {
  final dateTime = _parseToLocalDateTime(date);
  if (dateTime == null) {
    return 'Invalid date';
  }

  final current = (now ?? DateTime.now()).toLocal();
  final isSameCalendarDay =
      current.year == dateTime.year &&
      current.month == dateTime.month &&
      current.day == dateTime.day;
  final yesterday = DateTime(current.year, current.month, current.day - 1);
  final isYesterday =
      yesterday.year == dateTime.year &&
      yesterday.month == dateTime.month &&
      yesterday.day == dateTime.day;

  if (isSameCalendarDay) {
    final difference = current.difference(dateTime);

    if (difference.inHours < 1 && difference.inMinutes < 1) {
      return 'Now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes} min${difference.inMinutes == 1 ? '' : 's'} ago';
    }

    if (difference.inHours >= 1 && difference.inHours < 2) {
      return '1 hr ago';
    }

    final hours = difference.inHours;
    return '$hours hr${hours == 1 ? '' : 's'} ago';
  }

  if (isYesterday) {
    return 'Yesterday';
  }

  final differenceInDays = current.difference(dateTime).inDays;

  if (differenceInDays < 4) {
    return dayOfWeek(dateTime);
  }

  return dateFormatted(dateTime, showMonthName: true);
}

/// Returns the weekday name for [date] in local time.
///
/// Expected outcome:
/// - Valid date returns full weekday, for example `Friday`.
/// - Invalid/unparseable input returns `Invalid date`.
String dayOfWeek(dynamic date, {bool showFullName = true}) {
  DateTime dateTime;
  if (date is String) {
    try {
      dateTime = DateTime.parse(date).toLocal();
    } catch (e) {
      return 'Invalid date';
    }
  } else if (date is DateTime) {
    dateTime = date.toLocal();
  } else {
    return 'Invalid date';
  }
  return showFullName
      ? DateFormat('EEEE').format(dateTime)
      : DateFormat('EEE').format(dateTime);
}

/// Formats a date as `Weekday, D mon` and appends year when needed.
///
/// Expected outcome:
/// - Current year example: `Friday, 17 jul`
/// - Different year example: `Friday, 17 jul, 2025`
/// - Invalid/unparseable input returns `Invalid date`.
String formatDayDate(dynamic date) {
  DateTime dateTime;
  if (date is String) {
    try {
      dateTime = DateTime.parse(date).toLocal();
    } catch (e) {
      return 'Invalid date';
    }
  } else if (date is DateTime) {
    dateTime = date.toLocal();
  } else {
    return 'Invalid date';
  }

  final now = DateTime.now();
  final String dayAndDate =
      '${DateFormat('EEEE').format(dateTime)}, ${dateTime.day} ${DateFormat('MMM').format(dateTime).toLowerCase()}';

  if (dateTime.year != now.year) {
    return '$dayAndDate, ${dateTime.year}';
  }
  return dayAndDate;
}

/// Adds thousands separators to a numeric string.
///
/// Expected outcome:
/// - Example: `"1234567" -> "1,234,567"`.
String numberFormatted(String number) {
  return number.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
}

String phoneNumberFormatted(String value) {
  final digitsOnly = value.trim().replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.length <= 9) {
    return digitsOnly;
  }

  return digitsOnly.substring(digitsOnly.length - 9);
}

/// Normalizes package-contact phone numbers to an E.164-style value.
///
/// Contact entry supplies an explicit country code. Older locally stored
/// Zimbabwean numbers without one are treated as Zimbabwean for backwards
/// compatibility, while an already supplied international code is preserved.
String e164PhoneNumberFormatted(String value) {
  final trimmed = value.trim();
  final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.isEmpty) return '';

  if (trimmed.startsWith('+')) return '+$digitsOnly';
  if (digitsOnly.startsWith('00') && digitsOnly.length > 2) {
    return '+${digitsOnly.substring(2)}';
  }
  if (digitsOnly.startsWith('0')) return '+263${digitsOnly.substring(1)}';
  if (digitsOnly.length == 9) return '+263$digitsOnly';

  return '+$digitsOnly';
}

bool isValidPaymentPhoneNumber(String value) {
  final phone = phoneNumberFormatted(value);
  return RegExp(r'^\d{9}$').hasMatch(phone) &&
      (phone.startsWith('77') ||
          phone.startsWith('78') ||
          phone.startsWith('71'));
}

/// Converts a numeric string into a short compact representation.
///
/// Expected outcome:
/// - `>= 1,000` -> `k`
/// - `>= 1,000,000` -> `m`
/// - `>= 1,000,000,000` -> `b`
/// - Smaller numbers are returned as their parsed numeric string form.
/// - Examples: `"1500" -> "2k"`, `"2400000" -> "2m"`.
String formatLargeNumber(String number) {
  double num = double.parse(number);
  if (num >= 1000000000) {
    return '${(num / 1000000000).round()}b';
  } else if (num >= 1000000) {
    return '${(num / 1000000).round()}m';
  } else if (num >= 1000) {
    return '${(num / 1000).round()}k';
  } else {
    return num.toString();
  }
}

/// Left-pads [n] with a leading zero to ensure at least two digits.
///
/// Expected outcome:
/// - `7 -> "07"`
/// - `12 -> "12"`.
String twoDigits(int n) => n.toString().padLeft(2, '0');

/// Builds a short greeting based on local time and optional [firstName].
///
/// Expected outcome:
/// - Returns a time-appropriate greeting template.
/// - Appends first name when provided.
/// - Final greeting is capped to at most 3 words.
/// - Examples: `Good morning Taona`, `Night mode`.
String generateDynamicGreeting({String? firstName, DateTime? now}) {
  final localNow = (now ?? DateTime.now()).toLocal();
  final templates = _greetingTemplatesForHour(localNow.hour);
  final index = (localNow.weekday + localNow.minute) % templates.length;
  final baseGreeting = templates[index];
  final name = _extractFirstName(firstName);

  if (name.isEmpty) {
    return baseGreeting;
  }

  return _limitToThreeWords('$baseGreeting $name');
}

/// Returns greeting templates for a given hour of day.
///
/// Expected outcome:
/// - Morning (5-11), afternoon (12-16), evening (17-21), or late-night set.
List<String> _greetingTemplatesForHour(int hour) {
  if (hour >= 5 && hour < 12) {
    return const ['Good morning', 'Morning', 'Rise up'];
  }
  if (hour >= 12 && hour < 17) {
    return const ['Good afternoon', 'Afternoon', 'Midday check'];
  }
  if (hour >= 17 && hour < 22) {
    return const ['Good evening', 'Evening', 'Easy evening'];
  }

  return const ['Late night', 'Night mode', 'Still awake'];
}

/// Extracts and returns the first name token from [firstName].
///
/// Expected outcome:
/// - Null/blank input returns an empty string.
/// - Multi-word names return only the first word.
String _extractFirstName(String? firstName) {
  if (firstName == null) {
    return '';
  }

  final trimmed = firstName.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  final parts = trimmed.split(RegExp(r'\s+'));
  return parts.first;
}

/// Limits [text] to at most three words.
///
/// Expected outcome:
/// - 3 words or fewer are returned unchanged (after trimming).
/// - More than 3 words are truncated to the first three.
String _limitToThreeWords(String text) {
  final words =
      text
          .trim()
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toList();

  if (words.length <= 3) {
    return words.join(' ');
  }

  return words.take(3).join(' ');
}

/// Parses [date] into a local [DateTime] when possible.
///
/// Expected outcome:
/// - ISO date strings and [DateTime] values are converted to local time.
/// - Unsupported or invalid input returns null.
DateTime? _parseToLocalDateTime(dynamic date) {
  if (date is String) {
    try {
      return DateTime.parse(date).toLocal();
    } catch (e) {
      return null;
    }
  }

  if (date is DateTime) {
    return date.toLocal();
  }

  return null;
}
