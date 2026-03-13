import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import '../models/account.dart';
import '../models/platform_config.dart';
import '../utils/logger.dart';
import '../utils/device_utils.dart';
import 'signature_service.dart';
import 'damai_account_service.dart'; // Reuse LoginResult

class MaoyanAccountService {
  final Dio _dio = Dio();
  final SignatureService _signatureService = SignatureService();
  final PlatformConfig _config = PlatformConfig.maoyan;

  MaoyanAccountService() {
    _setupDio();
  }

  void _setupDio() {
    _dio.options = BaseOptions(
      baseUrl: _config.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: _config.headers,
    );

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        AppLogger.debug('Maoyan Account Request: ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        AppLogger.debug('Maoyan Account Response: ${response.statusCode}');
        handler.next(response);
      },
      onError: (error, handler) {
        AppLogger.error('Maoyan Account Request error: ${error.message}', error);
        handler.next(error);
      },
    ));
  }

  Future<LoginResult> login(Account account) async {
    // 某眼登录通常需要短信验证码或复杂的滑块，
    // 这里模拟一个登录流程，实际上可能需要用户手动导入 cookie
    try {
      AppLogger.info('Attempting Maoyan login for account: ${account.username}');

      // 检查是否有 token 或 cookie，如果有则验证有效性
      if (account.token != null && account.token!.isNotEmpty) {
        final isValid = await _validateToken(account.token!);
        if (isValid) {
          return LoginResult(
            success: true,
            message: 'Token有效',
            token: account.token,
            cookies: account.cookies?.cast<String, String>(),
          );
        }
      }

      // 如果提供了密码，尝试密码登录（假设接口存在）
      // 注意：实际某眼APP主要使用手机号+验证码，这里仅做示例结构
      if (account.password.isNotEmpty) {
          // 这里应该实现真实的登录逻辑
          // 由于无法处理验证码，这里返回失败并提示
          return LoginResult(
            success: false,
            message: '某眼暂不支持自动密码登录，请使用Token或Cookie导入',
          );
      }

      return LoginResult(
        success: false,
        message: '登录失败: 未提供有效的凭证',
      );
    } catch (e) {
      return LoginResult(
        success: false,
        message: '登录异常: $e',
      );
    }
  }

  Future<bool> _validateToken(String token) async {
    try {
      // 调用猫眼用户信息接口验证 token
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final deviceId = await DeviceUtils.generateDeviceId();
      
      final params = {
        'token': token,
        'timestamp': timestamp.toString(),
      };
      
      final signature = await _generateSignature(params, deviceId);
      
      final response = await _dio.get(
        '/ajax/user/info', // 假设的接口
        queryParameters: {
          ...params,
          'sign': signature,
        },
      );

      return response.statusCode == 200 && response.data['status'] == 0;
    } catch (e) {
      return false;
    }
  }

  Future<String> _generateSignature(Map<String, dynamic> params, String deviceId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final nonce = Random().nextInt(999999).toString().padLeft(6, '0');
    
    return await _signatureService.generateMaoyanSignature(
      params: params,
      deviceId: deviceId,
      timestamp: timestamp,
      nonce: nonce,
    );
  }
}
