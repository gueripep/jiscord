import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/platform_infos.dart';

/// Provides extra functionality for formatting the time.
extension DateTimeExtension on DateTime {
  bool operator <(DateTime other) {
    return millisecondsSinceEpoch < other.millisecondsSinceEpoch;
  }

  bool operator >(DateTime other) {
    return millisecondsSinceEpoch > other.millisecondsSinceEpoch;
  }

  bool operator >=(DateTime other) {
    return millisecondsSinceEpoch >= other.millisecondsSinceEpoch;
  }

  bool operator <=(DateTime other) {
    return millisecondsSinceEpoch <= other.millisecondsSinceEpoch;
  }

  /// Checks if two DateTimes are close enough to belong to the same
  /// environment.
  bool sameEnvironment(DateTime prevTime) =>
      difference(prevTime) < const Duration(hours: 1);

  static final Map<String, DateFormat> _timeFormatCache = {};
  static final Map<String, DateFormat> _timeFormatAmPmCache = {};
  static final Map<String, DateFormat> _dayFormatCache = {};
  static final Map<String, DateFormat> _monthDayFormatCache = {};
  static final Map<String, DateFormat> _yearMonthDayFormatCache = {};

  /// Returns a simple time String.
  String localizedTimeOfDay(BuildContext context) {
    final locale = L10n.of(context).localeName;
    if (use24HourFormat(context)) {
      final format = _timeFormatCache.putIfAbsent(
        locale,
        () => DateFormat('HH:mm', locale),
      );
      return format.format(this);
    } else {
      final format = _timeFormatAmPmCache.putIfAbsent(
        locale,
        () => DateFormat('h:mm a', locale),
      );
      return format.format(this);
    }
  }

  /// Returns [localizedTimeOfDay()] if the ChatTime is today, the name of the week
  /// day if the ChatTime is this week and a date string else.
  String localizedTimeShort(BuildContext context) {
    final now = DateTime.now();

    final sameYear = now.year == year;

    final sameDay = sameYear && now.month == month && now.day == day;

    final sameWeek =
        sameYear &&
        !sameDay &&
        now.millisecondsSinceEpoch - millisecondsSinceEpoch <
            1000 * 60 * 60 * 24 * 7;

    final languageCode = Localizations.localeOf(context).languageCode;

    if (sameDay) {
      return localizedTimeOfDay(context);
    } else if (sameWeek) {
      final format = _dayFormatCache.putIfAbsent(
        languageCode,
        () => DateFormat.E(languageCode),
      );
      return format.format(this);
    } else if (sameYear) {
      final format = _monthDayFormatCache.putIfAbsent(
        languageCode,
        () => DateFormat.MMMd(languageCode),
      );
      return format.format(this);
    }
    final format = _yearMonthDayFormatCache.putIfAbsent(
      languageCode,
      () => DateFormat.yMMMd(languageCode),
    );
    return format.format(this);
  }

  /// If the DateTime is today, this returns [localizedTimeOfDay()], if not it also
  /// shows the date.
  /// TODO: Add localization
  String localizedTime(BuildContext context) {
    final now = DateTime.now();

    final sameYear = now.year == year;

    final sameDay = sameYear && now.month == month && now.day == day;

    if (sameDay) return localizedTimeOfDay(context);
    return L10n.of(context).dateAndTimeOfDay(
      localizedTimeShort(context),
      localizedTimeOfDay(context),
    );
  }

  /// Check if time needs to be in 24h format
  bool use24HourFormat(BuildContext context) {
    final mediaQuery24h = MediaQuery.alwaysUse24HourFormatOf(context);

    final l10n24h = L10n.of(context).alwaysUse24HourFormat == 'true';

    // https://github.com/krille-chan/fluffychat/pull/1457#discussion_r1836817914
    if (PlatformInfos.isAndroid) {
      return mediaQuery24h;
    } else if (PlatformInfos.isIOS) {
      return mediaQuery24h || l10n24h;
    }

    return l10n24h;
  }
}
