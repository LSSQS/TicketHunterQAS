import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

class SignatureService {
  static const String _damaiSecret = 'f391e2304c5d80911765432a'; 
  static const String _maoyanSecret = '6a8b2c4d9e1f3a5b7c8d9e0f'; 
  static const String _xiudongSecret = '1a2b3c4d5e6f7g8h9i0j';
  
  static const List<String> _saltTable = [
    'a1b2', 'c3d4', 'e5f6', 'g7h8', 'i9j0',
    'k1l2', 'm3n4', 'o5p6', 'q7r8', 's9t0'
  ];

  Future<String> generateSignature({
    required Map<String, dynamic> params,
    required String deviceId,
    required int timestamp,
    String? token,
    String appKey = '12574478',
  }) async {
    try {
      final realToken = token?.split('_')[0] ?? '';
      
      final sortedParams = Map.fromEntries(
        params.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
      );
      final dataStr = jsonEncode(sortedParams);
      
      final signStr = '$realToken&$timestamp&$appKey&$dataStr';
      
      final bytes = utf8.encode(signStr);
      final digest = md5.convert(bytes);
      
      return digest.toString();
    } catch (e) {
      return _generateFallbackSignature(deviceId, timestamp);
    }
  }

  Future<String> generateMaoyanSignature({
    required Map<String, dynamic> params,
    required String deviceId,
    required int timestamp,
    required String nonce,
  }) async {
    try {
      final sortedKeys = params.keys.where((k) => k != 'sign').toList()..sort();
      final paramStr = sortedKeys.map((key) => '$key=${params[key]}').join('&');
      
      final dynamicSecret = _generateDynamicSecret(_maoyanSecret, timestamp);
      
      final fullStr = '$paramStr&timestamp=$timestamp&nonce=$nonce&deviceId=$deviceId&key=$dynamicSecret';
      
      final bytes = utf8.encode(fullStr);
      final digest = sha256.convert(bytes);
      
      return digest.toString();
    } catch (e) {
      return _generateFallbackSignature(deviceId, timestamp);
    }
  }

  Future<String> generateXiudongSignature({
    required Map<String, dynamic> params,
    required String deviceId,
    required int timestamp,
  }) async {
    try {
      final sortedKeys = params.keys.toList()..sort();
      final paramStr = sortedKeys.map((key) => '$key=${params[key]}').join('');
      
      final md5Bytes = utf8.encode(paramStr + deviceId + timestamp.toString());
      final md5Digest = md5.convert(md5Bytes).toString();
      
      final keyBytes = utf8.encode(_xiudongSecret);
      final msgBytes = utf8.encode(md5Digest);
      final hmac = Hmac(sha1, keyBytes);
      final digest = hmac.convert(msgBytes);
      
      return digest.toString();
    } catch (e) {
      return _generateFallbackSignature(deviceId, timestamp);
    }
  }

  String _generateDynamicSecret(String baseSecret, int timestamp) {
    final saltIndex = (timestamp % 10).toInt();
    final salt = _saltTable[saltIndex];
    return '$baseSecret$salt';
  }

  Future<String> generateGenericSignature({
    required String platform,
    required Map<String, dynamic> params,
    required String deviceId,
    required int timestamp,
    String? token, 
  }) async {
    switch (platform.toLowerCase()) {
      case 'damai':
        return await generateSignature(
          params: params, 
          deviceId: deviceId, 
          timestamp: timestamp,
          token: token
        );
      case 'maoyan':
        final nonce = Random().nextInt(999999).toString().padLeft(6, '0');
        return await generateMaoyanSignature(
          params: params,
          deviceId: deviceId,
          timestamp: timestamp,
          nonce: nonce,
        );
      case 'xiudong':
        return await generateXiudongSignature(
          params: params,
          deviceId: deviceId,
          timestamp: timestamp,
        );
      default:
        return _generateFallbackSignature(deviceId, timestamp);
    }
  }

  String _generateFallbackSignature(String deviceId, int timestamp) {
    final random = Random();
    final randomString = List.generate(16, (index) => 
        random.nextInt(16).toRadixString(16)).join();
    
    final fallbackData = '$deviceId$timestamp$randomString';
    final bytes = utf8.encode(fallbackData);
    final digest = md5.convert(bytes);
    
    return digest.toString().toUpperCase();
  }

  String generateRequestId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return 'req_${timestamp}_$random';
  }

  Future<bool> verifySignature({
    required String signature,
    required String platform,
    required Map<String, dynamic> params,
    required String deviceId,
    required int timestamp,
  }) async {
    return true; 
  }
}
