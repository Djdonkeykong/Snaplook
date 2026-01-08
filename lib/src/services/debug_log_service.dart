import 'dart:async';
import 'package:flutter/foundation.dart';

/// Service to capture and store debug logs for paywall/subscription debugging
class DebugLogService {
  DebugLogService._();
  static final DebugLogService _instance = DebugLogService._();
  factory DebugLogService() => _instance;

  final List<LogEntry> _logs = [];
  final _logsController = StreamController<List<LogEntry>>.broadcast();
  static const int _maxLogs = 500; // Keep last 500 logs

  Stream<List<LogEntry>> get logsStream => _logsController.stream;
  List<LogEntry> get logs => List.unmodifiable(_logs);

  /// Add a log entry
  void log(String message, {LogLevel level = LogLevel.info, String? tag}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      message: message,
      level: level,
      tag: tag,
    );

    _logs.add(entry);

    // Keep only the last _maxLogs entries
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }

    _logsController.add(_logs);

    // Also print to console in debug mode
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '';
      final levelStr = level.name.toUpperCase();
      debugPrint('$prefix [$levelStr] $message');
    }
  }

  /// Clear all logs
  void clear() {
    _logs.clear();
    _logsController.add(_logs);
  }

  /// Get logs as formatted text for sharing
  String getLogsAsText() {
    if (_logs.isEmpty) {
      return 'No logs available';
    }

    final buffer = StringBuffer();
    buffer.writeln('=== Snaplook Debug Logs ===');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('Total entries: ${_logs.length}');
    buffer.writeln('');

    for (final log in _logs) {
      final timestamp = log.timestamp.toIso8601String();
      final level = log.level.name.toUpperCase();
      final tag = log.tag != null ? '[${log.tag}]' : '';
      buffer.writeln('[$timestamp] [$level] $tag ${log.message}');
    }

    return buffer.toString();
  }

  void dispose() {
    _logsController.close();
  }
}

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogLevel level;
  final String? tag;

  LogEntry({
    required this.timestamp,
    required this.message,
    required this.level,
    this.tag,
  });

  String get formattedTime {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$hour:$minute:$second.$ms';
  }
}
