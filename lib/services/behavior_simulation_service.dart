import 'dart:math';
import '../utils/logger.dart';

class BehaviorSimulationService {
  final Random _random = Random();
  
  // 行为模式配置
  static const Map<String, BehaviorPattern> _patterns = {
    'login': BehaviorPattern(
      minDelay: 800,
      maxDelay: 2000,
      variance: 0.3,
    ),
    'page_browse': BehaviorPattern(
      minDelay: 1200,
      maxDelay: 3000,
      variance: 0.4,
    ),
    'order_build': BehaviorPattern(
      minDelay: 300,
      maxDelay: 800,
      variance: 0.2,
    ),
    'order_create': BehaviorPattern(
      minDelay: 500,
      maxDelay: 1200,
      variance: 0.25,
    ),
    'click': BehaviorPattern(
      minDelay: 100,
      maxDelay: 300,
      variance: 0.15,
    ),
    'scroll': BehaviorPattern(
      minDelay: 200,
      maxDelay: 600,
      variance: 0.2,
    ),
  };

  Future<void> simulateHumanBehavior(String action) async {
    final pattern = _patterns[action] ?? _patterns['click']!;
    final delay = _calculateDelay(pattern);
    
    AppLogger.debug('Simulating $action behavior with ${delay}ms delay');
    await Future.delayed(Duration(milliseconds: delay));
  }

  Future<void> randomDelay({int? minMs, int? maxMs}) async {
    final min = minMs ?? 50;
    final max = maxMs ?? 200;
    final delay = min + _random.nextInt(max - min);
    
    await Future.delayed(Duration(milliseconds: delay));
  }

  int _calculateDelay(BehaviorPattern pattern) {
    // 使用正态分布生成更自然的延迟
    final mean = (pattern.minDelay + pattern.maxDelay) / 2;
    final stdDev = (pattern.maxDelay - pattern.minDelay) * pattern.variance;
    
    final delay = _gaussianRandom(mean, stdDev);
    
    // 确保延迟在合理范围内
    return delay.clamp(pattern.minDelay, pattern.maxDelay).round();
  }

  static double? _spare;
  
  double _gaussianRandom(double mean, double stdDev) {
    // Box-Muller变换生成正态分布随机数
    if (_spare != null) {
      final result = _spare! * stdDev + mean;
      _spare = null;
      return result;
    }
    
    final u = _random.nextDouble();
    final v = _random.nextDouble();
    
    final mag = stdDev * sqrt(-2.0 * log(u));
    _spare = mag * cos(2.0 * pi * v);
    
    return mag * sin(2.0 * pi * v) + mean;
  }

  // 生成鼠标轨迹
  List<Point> generateMouseTrajectory({
    required Point start,
    required Point end,
    int steps = 30,
  }) {
    final trajectory = <Point>[];
    
    // 生成贝塞尔曲线控制点
    final control1 = Point(
      start.x + (end.x - start.x) * 0.3 + _random.nextGaussian() * 5,
      start.y + (end.y - start.y) * 0.4 + _random.nextGaussian() * 10,
    );
    
    final control2 = Point(
      start.x + (end.x - start.x) * 0.7 + _random.nextGaussian() * 5,
      start.y + (end.y - start.y) * 0.6 + _random.nextGaussian() * 10,
    );
    
    // 生成轨迹点
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final point = _bezierPoint(start, control1, control2, end, t);
      
      // 添加微小的随机抖动
      final jitteredPoint = Point(
        point.x + _random.nextGaussian() * 2,
        point.y + _random.nextGaussian() * 2,
      );
      
      trajectory.add(jitteredPoint);
    }
    
    return trajectory;
  }

  Point _bezierPoint(Point p0, Point p1, Point p2, Point p3, double t) {
    final u = 1 - t;
    final tt = t * t;
    final uu = u * u;
    final uuu = uu * u;
    final ttt = tt * t;
    
    final x = uuu * p0.x + 3 * uu * t * p1.x + 3 * u * tt * p2.x + ttt * p3.x;
    final y = uuu * p0.y + 3 * uu * t * p1.y + 3 * u * tt * p2.y + ttt * p3.y;
    
    return Point(x, y);
  }

  // 生成键盘输入模拟
  Future<void> simulateTyping(String text, {bool randomSpeed = true}) async {
    for (int i = 0; i < text.length; i++) {
      if (randomSpeed) {
        // 模拟不同的打字速度
        final delay = 80 + _random.nextInt(120); // 80-200ms
        await Future.delayed(Duration(milliseconds: delay));
      } else {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // 偶尔模拟打字错误和修正
      if (_random.nextDouble() < 0.02) { // 2%的错误率
        await Future.delayed(const Duration(milliseconds: 200));
        // 模拟退格
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }
  }

  // 模拟滚动行为
  Future<void> simulateScroll({
    required int distance,
    int steps = 10,
  }) async {
    final stepDistance = distance / steps;
    
    for (int i = 0; i < steps; i++) {
      await randomDelay(minMs: 16, maxMs: 33); // 模拟60fps滚动
      
      // 这里可以添加实际的滚动逻辑
      AppLogger.debug('Scroll step ${i + 1}/$steps, distance: $stepDistance');
    }
  }

  // 模拟页面浏览行为
  Future<void> simulatePageBrowsing() async {
    // 模拟页面加载等待
    await simulateHumanBehavior('page_browse');
    
    // 随机滚动
    if (_random.nextBool()) {
      await simulateScroll(distance: 100 + _random.nextInt(300));
    }
    
    // 随机停留
    await randomDelay(minMs: 500, maxMs: 2000);
  }

  // 生成随机用户代理
  String generateRandomUserAgent() {
    final androidVersions = ['11', '12', '13'];
    final chromeVersions = ['91.0.4472.114', '92.0.4515.159', '93.0.4577.82'];
    final devices = [
      'SM-G991B', 'SM-G996B', 'SM-G998B', // Samsung
      'Mi 11', 'Mi 12', 'Redmi Note 11', // Xiaomi
      'ONEPLUS A6000', 'ONEPLUS A9000', // OnePlus
    ];
    
    final androidVersion = androidVersions[_random.nextInt(androidVersions.length)];
    final chromeVersion = chromeVersions[_random.nextInt(chromeVersions.length)];
    final device = devices[_random.nextInt(devices.length)];
    
    return 'Mozilla/5.0 (Linux; Android $androidVersion; $device) '
           'AppleWebKit/537.36 (KHTML, like Gecko) '
           'Chrome/$chromeVersion Mobile Safari/537.36';
  }

  // 行为分析和学习
  void learnFromBehavior({
    required String action,
    required int actualDelay,
    required bool success,
  }) {
    // 这里可以实现机器学习算法来优化行为模式
    AppLogger.debug('Learning from behavior: $action, delay: $actualDelay, success: $success');
    
    // 简单的自适应逻辑
    if (success && actualDelay < (_patterns[action]?.minDelay ?? 0)) {
      // 成功且延迟较短，可以适当减少延迟
    } else if (!success && actualDelay > (_patterns[action]?.maxDelay ?? 0)) {
      // 失败且延迟较长，可能需要增加随机性
    }
  }

  // 检测异常行为模式
  bool detectAnomalousPattern(List<int> recentDelays) {
    if (recentDelays.length < 5) return false;
    
    // 计算延迟的标准差
    final mean = recentDelays.reduce((a, b) => a + b) / recentDelays.length;
    final variance = recentDelays
        .map((delay) => pow(delay - mean, 2))
        .reduce((a, b) => a + b) / recentDelays.length;
    final stdDev = sqrt(variance);
    
    // 如果标准差太小，说明行为过于规律
    return stdDev < mean * 0.1;
  }
}

class BehaviorPattern {
  final int minDelay;
  final int maxDelay;
  final double variance;

  const BehaviorPattern({
    required this.minDelay,
    required this.maxDelay,
    required this.variance,
  });
}

class Point {
  final double x;
  final double y;

  Point(this.x, this.y);

  @override
  String toString() => 'Point($x, $y)';
}

extension RandomExtension on Random {
  static double? _extensionSpare;
  
  double nextGaussian() {
    // 生成标准正态分布随机数
    if (_extensionSpare != null) {
      final result = _extensionSpare!;
      _extensionSpare = null;
      return result;
    }
    
    final u = nextDouble();
    final v = nextDouble();
    
    final mag = sqrt(-2.0 * log(u));
    _extensionSpare = mag * cos(2.0 * pi * v);
    
    return mag * sin(2.0 * pi * v);
  }
}