import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/share_extension_logs_service.dart';

class ShareLogsPage extends StatefulWidget {
  const ShareLogsPage({super.key});

  @override
  State<ShareLogsPage> createState() => _ShareLogsPageState();
}

class _ShareLogsPageState extends State<ShareLogsPage> {
  List<String> _logs = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    final entries = await ShareExtensionLogsService.fetchLogs();
    setState(() {
      _logs = entries.reversed.toList();
      _loading = false;
    });
  }

  Future<void> _clearLogs() async {
    await ShareExtensionLogsService.clearLogs();
    await _loadLogs();
  }

  Future<void> _shareLogs() async {
    if (_logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logs to share')),
      );
      return;
    }

    final logsText = _logs.join('\n\n');
    await Share.share(
      logsText,
      subject: 'Share Extension Logs',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Extension Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareLogs,
            tooltip: 'Share logs',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
          ? const Center(child: Text('No logs recorded yet.'))
          : ListView.separated(
              itemCount: _logs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = _logs[index];
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    entry,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              },
            ),
    );
  }
}
