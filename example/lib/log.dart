import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'dart:developer' as developer;

class LogUtils {
  static void v(String tag, dynamic message) {
    _log(LogLevel.verbose, tag, message);
  }

  static void d(String tag, dynamic message) {
    _log(LogLevel.debug, tag, message);
  }

  static void i(String tag, dynamic message) {
    _log(LogLevel.info, tag, message);
  }

  static void w(String tag, dynamic message) {
    _log(LogLevel.warn, tag, message);
  }

  static void e(String tag, e, dynamic message) {
    Error? error;
    Exception? exception;
    if (e is Error) {
      error = e;
    } else if (e is Exception) {
      exception = e;
    } else {
      exception = Exception(e);
    }

    _log(LogLevel.error, tag, message, error: error, exception: exception);
  }

  static void _log(LogLevel logLevel, String tag, dynamic message, {Error? error, Exception? exception}) {
    // ONLY output WARNING and ERROR log info in release/profile mode
    if (!kDebugMode && (logLevel.index <= LogLevel.debug.index)) return;

    developer.log("${false ? '' : _currentTime()} $tag | $message", name: logLevel.shownName, error: error ?? exception, stackTrace: error?.stackTrace);
  }

  static String _currentTime() => DateTime.now().toLogTimeString();
}

enum LogLevel {
  _never(""),
  verbose("VERBOSE"),
  debug(" DEBUG "),
  info(" INFO  "),
  warn(" WARN  "),
  error(" ERROR ");

  final String shownName;

  const LogLevel(this.shownName);
}

extension LogDateTimeFormatExtension on DateTime {
  String toLogTimeString({bool withTimezone = false}) {
    String y = _fourDigits(year);
    String m = _twoDigits(month);
    String d = _twoDigits(day);
    String h = _twoDigits(hour);
    String min = _twoDigits(minute);
    String sec = _twoDigits(second);
    String ms = _threeDigits(millisecond);
    if (isUtc) {
      return "$y-$m-$d $h:$min:$sec.${ms}Z";
    } else {
      if (withTimezone) return "[$timeZoneName]$y-$m-$d $h:$min:$sec.$ms";
      return "$y-$m-$d $h:$min:$sec.$ms";
    }
  }

  /// copy from DateTime.class
  static String _fourDigits(int n) {
    int absN = n.abs();
    String sign = n < 0 ? "-" : "";
    if (absN >= 1000) return "$n";
    if (absN >= 100) return "${sign}0$absN";
    if (absN >= 10) return "${sign}00$absN";
    return "${sign}000$absN";
  }

  static String _threeDigits(int n) {
    if (n >= 100) return "${n}";
    if (n >= 10) return "0${n}";
    return "00${n}";
  }

  static String _twoDigits(int n) {
    if (n >= 10) return "${n}";
    return "0${n}";
  }
}
