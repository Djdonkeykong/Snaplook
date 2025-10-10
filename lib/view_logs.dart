import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() async {
  print('=== SNAPLOOK DEBUG LOG VIEWER ===\n');

  try {
    await viewRecentSessions();
    await viewColorMatchingLogs();
    await viewDebugStats();
  } catch (e) {
    print('Error: $e');
  }
}

Future<void> viewRecentSessions() async {
  print('RECENT DETECTION SESSIONS');
  print('=' * 50);

  try {
    final appDir = await getApplicationDocumentsDirectory();
    final logsDir = Directory('${appDir.path}/snaplook_debug_logs');
    final sessionsFile = File('${logsDir.path}/detection_sessions.jsonl');

    if (!await sessionsFile.exists()) {
      print('No detection sessions found yet.');
      return;
    }

    final lines = await sessionsFile.readAsLines();
    final recentSessions = lines.reversed.take(3).toList();

    for (int i = 0; i < recentSessions.length; i++) {
      final session = json.decode(recentSessions[i]);

      print('\n${i + 1}. Session: ${session['session_id']}');
      print('   Timestamp: ${session['timestamp']}');
      print('   Items Detected: ${session['analysis']['total_items_detected']}');
      print('   Results Found: ${session['analysis']['total_results_found']}');

      final detectionResults = session['detection_results'] as Map<String, dynamic>? ?? {};
      final items = detectionResults['items'] as List? ?? [];

      for (int j = 0; j < items.length && j < 2; j++) {
        final item = items[j];
        print('   Item ${j + 1}: ${item['category']} (${item['color_primary']})');
      }

      final searchResults = session['search_results'] as List? ?? [];
      if (searchResults.isNotEmpty) {
        print('   Top Results:');
        for (int j = 0; j < searchResults.length && j < 3; j++) {
          final result = searchResults[j];
          print('     - ${result['product_name']} (${result['confidence']})');
        }
      }
    }

  } catch (e) {
    print('Failed to view recent sessions: $e');
  }
}

Future<void> viewColorMatchingLogs() async {
  print('\n\nCOLOR MATCHING ANALYSIS');
  print('=' * 50);

  try {
    final appDir = await getApplicationDocumentsDirectory();
    final logsDir = Directory('${appDir.path}/snaplook_debug_logs');
    final colorFile = File('${logsDir.path}/color_matching.jsonl');

    if (!await colorFile.exists()) {
      print('No color matching logs found yet.');
      return;
    }

    final lines = await colorFile.readAsLines();
    final recentLogs = lines.reversed.take(2).toList();

    for (int i = 0; i < recentLogs.length; i++) {
      final log = json.decode(recentLogs[i]);
      final colorMatching = log['color_matching'] as Map<String, dynamic>? ?? {};

      print('\n${i + 1}. Color Analysis: ${log['session_id']}');
      print('   Requested Color: ${colorMatching['requested_color']}');
      print('   Variations: ${colorMatching['variations_generated']}');
      print('   Total Matches: ${colorMatching['total_matches_before_filter']}');

      final colorDistribution = colorMatching['color_distribution'] as Map<String, dynamic>? ?? {};
      if (colorDistribution.isNotEmpty) {
        print('   Color Distribution:');
        colorDistribution.forEach((color, count) {
          print('     $color: $count items');
        });
      }
    }

  } catch (e) {
    print('Failed to view color matching logs: $e');
  }
}

Future<void> viewDebugStats() async {
  print('\n\nDEBUG STATISTICS');
  print('=' * 50);

  try {
    final appDir = await getApplicationDocumentsDirectory();
    final logsDir = Directory('${appDir.path}/snaplook_debug_logs');
    final sessionsFile = File('${logsDir.path}/detection_sessions.jsonl');

    if (!await sessionsFile.exists()) {
      print('No sessions found yet.');
      return;
    }

    final lines = await sessionsFile.readAsLines();
    final sessions = lines.map((line) => json.decode(line)).toList();

    print('Total Sessions: ${sessions.length}');

    final mostSearchedColors = <String, int>{};
    final mostSearchedCategories = <String, int>{};

    for (final session in sessions) {
      final detectionResults = session['detection_results'] as Map<String, dynamic>? ?? {};
      final items = detectionResults['items'] as List? ?? [];

      for (final item in items) {
        final color = item['color_primary'] as String?;
        final category = item['category'] as String?;

        if (color != null) {
          mostSearchedColors[color] = (mostSearchedColors[color] ?? 0) + 1;
        }
        if (category != null) {
          mostSearchedCategories[category] = (mostSearchedCategories[category] ?? 0) + 1;
        }
      }
    }

    if (mostSearchedColors.isNotEmpty) {
      print('\nMost Searched Colors:');
      final sortedColors = mostSearchedColors.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (int i = 0; i < sortedColors.length && i < 5; i++) {
        final entry = sortedColors[i];
        print('  ${entry.key}: ${entry.value} searches');
      }
    }

  } catch (e) {
    print('Failed to view debug stats: $e');
  }
}