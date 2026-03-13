import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/logger.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({Key? key}) : super(key: key);

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _logs = '';
  bool _isLoading = true;
  LogLevel _selectedLevel = LogLevel.info;
  bool _autoScroll = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final logs = await AppLogger.getLogs(maxLines: 1000);
      setState(() {
        _logs = logs;
        _isLoading = false;
      });

      if (_autoScroll && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      setState(() {
        _logs = '加载日志失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日志查看'),
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('清空日志'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy),
                    SizedBox(width: 8),
                    Text('复制日志'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download),
                    SizedBox(width: 8),
                    Text('导出日志'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'statistics',
                child: Row(
                  children: [
                    Icon(Icons.analytics),
                    SizedBox(width: 8),
                    Text('日志统计'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading ? _buildLoadingWidget() : _buildLogContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          const Text('日志级别: '),
          DropdownButton<LogLevel>(
            value: _selectedLevel,
            onChanged: (level) {
              if (level != null) {
                setState(() {
                  _selectedLevel = level;
                });
                AppLogger.setLogLevel(level);
              }
            },
            items: LogLevel.values.map((level) {
              return DropdownMenuItem(
                value: level,
                child: Text(_getLogLevelName(level)),
              );
            }).toList(),
          ),
          const Spacer(),
          Row(
            children: [
              const Text('自动滚动'),
              Switch(
                value: _autoScroll,
                onChanged: (value) {
                  setState(() {
                    _autoScroll = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('正在加载日志...'),
        ],
      ),
    );
  }

  Widget _buildLogContent() {
    if (_logs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '暂无日志',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final filteredLogs = _filterLogsByLevel(_logs);
    final logLines = filteredLogs.split('\n');

    return Container(
      color: Colors.black,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        itemCount: logLines.length,
        itemBuilder: (context, index) {
          final line = logLines[index];
          return _buildLogLine(line);
        },
      ),
    );
  }

  Widget _buildLogLine(String line) {
    if (line.trim().isEmpty) {
      return const SizedBox(height: 4);
    }

    Color textColor = Colors.white;
    FontWeight fontWeight = FontWeight.normal;

    if (line.contains('[ERROR]')) {
      textColor = Colors.red[300]!;
      fontWeight = FontWeight.w500;
    } else if (line.contains('[WARNING]')) {
      textColor = Colors.orange[300]!;
    } else if (line.contains('[INFO]')) {
      textColor = Colors.blue[300]!;
    } else if (line.contains('[DEBUG]')) {
      textColor = Colors.grey[400]!;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: SelectableText(
        line,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: textColor,
          fontWeight: fontWeight,
        ),
      ),
    );
  }

  String _filterLogsByLevel(String logs) {
    final lines = logs.split('\n');
    final filteredLines = <String>[];

    for (final line in lines) {
      if (line.contains('[ERROR]') && _selectedLevel.index <= LogLevel.error.index) {
        filteredLines.add(line);
      } else if (line.contains('[WARNING]') && _selectedLevel.index <= LogLevel.warning.index) {
        filteredLines.add(line);
      } else if (line.contains('[INFO]') && _selectedLevel.index <= LogLevel.info.index) {
        filteredLines.add(line);
      } else if (line.contains('[DEBUG]') && _selectedLevel.index <= LogLevel.debug.index) {
        filteredLines.add(line);
      } else if (!line.contains('[ERROR]') && !line.contains('[WARNING]') && 
                 !line.contains('[INFO]') && !line.contains('[DEBUG]')) {
        // 包含非标准格式的日志行
        filteredLines.add(line);
      }
    }

    return filteredLines.join('\n');
  }

  String _getLogLevelName(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARNING';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'clear':
        _clearLogs();
        break;
      case 'copy':
        _copyLogs();
        break;
      case 'export':
        _exportLogs();
        break;
      case 'statistics':
        _showStatistics();
        break;
    }
  }

  void _clearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有日志吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AppLogger.clearLogs();
              await _loadLogs();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('日志已清空')),
              );
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _copyLogs() {
    Clipboard.setData(ClipboardData(text: _logs));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('日志已复制到剪贴板')),
    );
  }

  void _exportLogs() {
    // 这里可以实现导出功能，比如保存到文件或分享
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导出功能开发中...')),
    );
  }

  void _showStatistics() async {
    try {
      final stats = await AppLogger.getLogStatistics();
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('日志统计'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatItem('总行数', stats['totalLines']?.toString() ?? '0'),
              _buildStatItem('错误', stats['errorCount']?.toString() ?? '0'),
              _buildStatItem('警告', stats['warningCount']?.toString() ?? '0'),
              _buildStatItem('信息', stats['infoCount']?.toString() ?? '0'),
              _buildStatItem('调试', stats['debugCount']?.toString() ?? '0'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取统计信息失败: $e')),
      );
    }
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}