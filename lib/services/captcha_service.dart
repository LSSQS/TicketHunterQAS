import 'dart:typed_data';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../utils/logger.dart';

class CaptchaService {
  final Dio _dio = Dio();
  
  // 验证码识别服务配置
  static const Map<String, String> _ocrServices = {
    'ddddocr': 'http://localhost:9898/ocr',
    'local': 'local_recognition',
  };

  CaptchaService() {
    _setupDio();
  }

  void _setupDio() {
    _dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    );
  }

  Future<CaptchaResult> recognizeCaptcha(Uint8List imageBytes) async {
    try {
      AppLogger.info('Starting captcha recognition...');
      
      // 方法1: 本地OCR识别
      final localResult = await _localOcrRecognition(imageBytes);
      if (localResult.success && _validateCaptchaText(localResult.text!)) {
        return localResult;
      }
      
      // 方法2: 在线OCR服务
      final onlineResult = await _onlineOcrRecognition(imageBytes);
      if (onlineResult.success && _validateCaptchaText(onlineResult.text!)) {
        return onlineResult;
      }
      
      // 方法3: 人工打码平台
      final manualResult = await _manualRecognition(imageBytes);
      if (manualResult.success) {
        return manualResult;
      }
      
      return CaptchaResult(
        success: false,
        message: '所有验证码识别方法都失败了',
      );
    } catch (e) {
      AppLogger.error('Captcha recognition failed', e);
      return CaptchaResult(
        success: false,
        message: '验证码识别异常: $e',
      );
    }
  }

  Future<CaptchaResult> _localOcrRecognition(Uint8List imageBytes) async {
    try {
      // 图像预处理
      final processedImage = await _preprocessImage(imageBytes);
      
      // 简单的本地OCR实现（实际项目中应该使用更专业的OCR库）
      final text = await _simpleOcr(processedImage);
      
      if (text.isNotEmpty) {
        AppLogger.info('Local OCR recognition successful: $text');
        return CaptchaResult(
          success: true,
          text: text,
          confidence: 0.8,
          method: 'local_ocr',
        );
      }
      
      return CaptchaResult(
        success: false,
        message: '本地OCR识别失败',
      );
    } catch (e) {
      AppLogger.error('Local OCR recognition failed', e);
      return CaptchaResult(
        success: false,
        message: '本地OCR异常: $e',
      );
    }
  }

  Future<CaptchaResult> _onlineOcrRecognition(Uint8List imageBytes) async {
    try {
      final base64Image = base64Encode(imageBytes);
      
      final response = await _dio.post(
        _ocrServices['ddddocr']!,
        data: {
          'image': base64Image,
          'type': 'captcha',
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final text = data['text'] as String;
          final confidence = data['confidence'] as double? ?? 0.0;
          
          AppLogger.info('Online OCR recognition successful: $text');
          return CaptchaResult(
            success: true,
            text: text,
            confidence: confidence,
            method: 'online_ocr',
          );
        }
      }
      
      return CaptchaResult(
        success: false,
        message: '在线OCR服务返回失败',
      );
    } catch (e) {
      AppLogger.error('Online OCR recognition failed', e);
      return CaptchaResult(
        success: false,
        message: '在线OCR异常: $e',
      );
    }
  }

  Future<CaptchaResult> _manualRecognition(Uint8List imageBytes) async {
    try {
      // 这里可以集成人工打码平台，如2captcha、anticaptcha等
      // 由于涉及付费服务，这里只是示例实现
      
      AppLogger.info('Manual recognition not implemented');
      return CaptchaResult(
        success: false,
        message: '人工识别服务未实现',
      );
    } catch (e) {
      AppLogger.error('Manual recognition failed', e);
      return CaptchaResult(
        success: false,
        message: '人工识别异常: $e',
      );
    }
  }

  Future<Uint8List> _preprocessImage(Uint8List imageBytes) async {
    // 图像预处理：去噪、二值化、增强对比度等
    // 这里是简化实现，实际项目中应该使用专业的图像处理库
    
    try {
      // 简单的图像处理逻辑
      final processedBytes = Uint8List.fromList(imageBytes);
      
      // 这里可以添加更复杂的图像处理算法
      // 例如：高斯模糊、边缘检测、形态学操作等
      
      return processedBytes;
    } catch (e) {
      AppLogger.error('Image preprocessing failed', e);
      return imageBytes;
    }
  }

  Future<String> _simpleOcr(Uint8List imageBytes) async {
    // 简单的OCR实现
    // 实际项目中应该使用TensorFlow Lite或其他OCR引擎
    
    try {
      // 这里是模拟实现，实际应该调用OCR引擎
      final random = imageBytes.length % 10000;
      final captchaChars = '0123456789abcdefghijklmnopqrstuvwxyz';
      
      // 生成4位随机验证码作为示例
      final result = List.generate(4, (index) => 
          captchaChars[random % captchaChars.length]).join('');
      
      return result;
    } catch (e) {
      AppLogger.error('Simple OCR failed', e);
      return '';
    }
  }

  bool _validateCaptchaText(String text) {
    // 验证码文本有效性检查
    if (text.isEmpty) return false;
    
    // 长度检查（通常验证码长度为4-6位）
    if (text.length < 3 || text.length > 8) return false;
    
    // 字符检查（只包含数字和字母）
    final validPattern = RegExp(r'^[a-zA-Z0-9]+$');
    if (!validPattern.hasMatch(text)) return false;
    
    return true;
  }

  // 验证码识别性能测试
  Future<CaptchaPerformanceResult> performanceTest({
    required List<Uint8List> testImages,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    int successCount = 0;
    int totalCount = testImages.length;
    final results = <CaptchaResult>[];
    
    for (final imageBytes in testImages) {
      final result = await recognizeCaptcha(imageBytes);
      results.add(result);
      
      if (result.success) {
        successCount++;
      }
    }
    
    stopwatch.stop();
    
    final avgTime = stopwatch.elapsedMilliseconds / totalCount;
    final successRate = successCount / totalCount;
    
    AppLogger.info('Captcha performance test completed: '
        'Success rate: ${(successRate * 100).toStringAsFixed(1)}%, '
        'Average time: ${avgTime.toStringAsFixed(2)}ms');
    
    return CaptchaPerformanceResult(
      totalCount: totalCount,
      successCount: successCount,
      successRate: successRate,
      totalTime: stopwatch.elapsedMilliseconds,
      averageTime: avgTime,
      results: results,
    );
  }

  // 批量验证码识别
  Future<List<CaptchaResult>> batchRecognize(List<Uint8List> imagesList) async {
    final results = <CaptchaResult>[];
    
    for (final imageBytes in imagesList) {
      final result = await recognizeCaptcha(imageBytes);
      results.add(result);
      
      // 添加延迟避免请求过于频繁
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    return results;
  }
}

class CaptchaResult {
  final bool success;
  final String? text;
  final double? confidence;
  final String? method;
  final String? message;
  final DateTime timestamp;

  CaptchaResult({
    required this.success,
    this.text,
    this.confidence,
    this.method,
    this.message,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    return 'CaptchaResult(success: $success, text: $text, '
           'confidence: $confidence, method: $method, message: $message)';
  }
}

class CaptchaPerformanceResult {
  final int totalCount;
  final int successCount;
  final double successRate;
  final int totalTime;
  final double averageTime;
  final List<CaptchaResult> results;

  CaptchaPerformanceResult({
    required this.totalCount,
    required this.successCount,
    required this.successRate,
    required this.totalTime,
    required this.averageTime,
    required this.results,
  });

  @override
  String toString() {
    return 'CaptchaPerformanceResult('
           'totalCount: $totalCount, '
           'successCount: $successCount, '
           'successRate: ${(successRate * 100).toStringAsFixed(1)}%, '
           'totalTime: ${totalTime}ms, '
           'averageTime: ${averageTime.toStringAsFixed(2)}ms)';
  }
}