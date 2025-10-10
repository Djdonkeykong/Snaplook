import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'src/services/debug_logger.dart';

// Simple debug log viewer
void main() async {
  print('=== SNAPLOOK DEBUG LOG VIEWER ===\n');

  try {
    await viewRecentSessions();
    await viewColorMatchingLogs();
    await viewDebugStats();
    await exportReport();
  } catch (e) {
    print('❌ Error: $e');
  }
}

Future<void> viewRecentSessions() async {
  print('📊 RECENT DETECTION SESSIONS');
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
    final recentSessions = lines.reversed.take(5).toList();

    for (int i = 0; i < recentSessions.length; i++) {
      final session = json.decode(recentSessions[i]);

      print('\n${i + 1}. Session: ${session['session_id']}');
      print('   Timestamp: ${session['timestamp']}');
      print('   Items Detected: ${session['analysis']['total_items_detected']}');
      print('   Results Found: ${session['analysis']['total_results_found']}');
      print('   Summary: ${session['analysis']['detection_summary']}');

      // Show detected items
      final detectionResults = session['detection_results'] as Map<String, dynamic>? ?? {};
      final items = detectionResults['items'] as List? ?? [];

      for (int j = 0; j < items.length && j < 3; j++) {
        final item = items[j];
        print('   Item ${j + 1}: ${item['category']} (${item['color_primary']}) - ${item['confidence']}');
      }

      // Show top results
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
    print('❌ Failed to view recent sessions: $e');
  }
}

Future<void> viewColorMatchingLogs() async {
  print('\n\n🎨 COLOR MATCHING ANALYSIS');
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
    final recentLogs = lines.reversed.take(3).toList();

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

      // Show matched products
      final matchedProducts = log['matched_products'] as List? ?? [];
      if (matchedProducts.isNotEmpty) {
        print('   Sample Matches:');
        for (int j = 0; j < matchedProducts.length && j < 5; j++) {
          final product = matchedProducts[j];
          print('     ${product['id']}: ${product['color_primary']} ${product['category']}');
        }
      }
    }

  } catch (e) {
    print('❌ Failed to view color matching logs: $e');
  }
}

Future<void> viewDebugStats() async {
  print('\n\n📈 DEBUG STATISTICS');
  print('=' * 50);

  try {
    final stats = await DebugLogger.instance.getDebugStats();

    print('Total Sessions: ${stats['total_sessions'] ?? 0}');
    print('Recent Sessions: ${stats['recent_sessions'] ?? 0}');
    print('Color Accuracy: ${(stats['color_accuracy'] ?? 0).toStringAsFixed(1)}%');
    print('Avg Results/Session: ${(stats['avg_results_per_session'] ?? 0).toStringAsFixed(1)}');

    final mostSearchedColors = stats['most_searched_colors'] as Map<String, dynamic>? ?? {};
    if (mostSearchedColors.isNotEmpty) {
      print('\nMost Searched Colors:');
      final sortedColors = mostSearchedColors.entries.toList()
        ..sort((a, b) => (b.value as int).compareTo(a.value as int));

      for (int i = 0; i < sortedColors.length && i < 5; i++) {
        final entry = sortedColors[i];
        print('  ${entry.key}: ${entry.value} searches');
      }
    }

    final mostSearchedCategories = stats['most_searched_categories'] as Map<String, dynamic>? ?? {};
    if (mostSearchedCategories.isNotEmpty) {
      print('\nMost Searched Categories:');
      final sortedCategories = mostSearchedCategories.entries.toList()
        ..sort((a, b) => (b.value as int).compareTo(a.value as int));

      for (int i = 0; i < sortedCategories.length && i < 5; i++) {
        final entry = sortedCategories[i];
        print('  ${entry.key}: ${entry.value} searches');
      }
    }

  } catch (e) {
    print('❌ Failed to view debug stats: $e');
  }
}

Future<void> exportReport() async {
  print('\n\n📄 EXPORTING DEBUG REPORT');
  print('=' * 50);

  try {
    final reportPath = await DebugLogger.instance.exportDebugReport();

    if (reportPath != null) {
      print('✅ Debug report exported to: $reportPath');
      print('\nYou can analyze this file to understand:');
      print('  - Color matching accuracy');
      print('  - Search performance patterns');
      print('  - Most problematic color combinations');
      print('  - Detection confidence trends');
    } else {
      print('❌ Failed to export debug report');
    }

  } catch (e) {
    print('❌ Error exporting report: $e');
  }
}