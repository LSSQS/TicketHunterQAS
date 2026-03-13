import 'package:logger/logger.dart';

/// 日志级别枚举
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  // 内存日志缓存（用于日志查看页面）
  static final List<String> _logHistory = [];
  static LogLevel _currentLogLevel = LogLevel.info;
  static const int _maxLogLines = 1000;

  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
    _addLog('[DEBUG] $message', error);
  }

  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
    _addLog('[INFO] $message', error);
  }

  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
    _addLog('[WARNING] $message', error);
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    _addLog('[ERROR] $message', error);
  }

  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
    _addLog('[FATAL] $message', error);
  }

  static void _addLog(String message, [dynamic error]) {
    final timestamp = DateTime.now().toString();
    final logEntry = '[$timestamp] $message${error != null ? ' - $error' : ''}';
    
    _logHistory.add(logEntry);
    
    // 保持日志历史不超过最大行数
    if (_logHistory.length > _maxLogLines) {
      _logHistory.removeAt(0);
    }
  }

  /// 获取日志历史
  static Future<String> getLogs({int maxLines = 1000}) async {
    final lines = _logHistory.length > maxLines 
        ? _logHistory.sublist(_logHistory.length - maxLines)
        : _logHistory;
    return lines.join('\n');
  }

  /// 设置日志级别
  static void setLogLevel(LogLevel level) {
    _currentLogLevel = level;
  }

  /// 获取当前日志级别
  static LogLevel get currentLogLevel => _currentLogLevel;

  /// 清空日志
  static Future<void> clearLogs() async {
    _logHistory.clear();
  }

  /// 获取日志统计信息
  static Future<Map<String, int>> getLogStatistics() async {
    int errorCount = 0;
    int warningCount = 0;
    int infoCount = 0;
    int debugCount = 0;

    for (final log in _logHistory) {
      if (log.contains('[ERROR]') || log.contains('[FATAL]')) {
        errorCount++;
      } else if (log.contains('[WARNING]')) {
        warningCount++;
      } else if (log.contains('[INFO]')) {
        infoCount++;
      } else if (log.contains('[DEBUG]')) {
        debugCount++;
      }
    }

    return {
      'totalLines': _logHistory.length,
      'errorCount': errorCount,
      'warningCount': warningCount,
      'infoCount': infoCount,
      'debugCount': debugCount,
    };
  }
}
