import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import '../models/account.dart';
import '../models/platform_config.dart';
import '../utils/logger.dart';
import '../utils/device_utils.dart';
import '../config/app_config.dart';
import 'signature_service.dart';
import 'captcha_service.dart';

class DamaiAccountService {
  final Dio _dio = Dio();
  final SignatureService _signatureService = SignatureService();
  final CaptchaService _captchaService = CaptchaService();
  
  // 使用集中配置
  final PlatformConfig _config = PlatformConfig.damai;

  DamaiAccountService() {
    _setupDio();
  }

  void _setupDio() {
    _dio.options = BaseOptions(
      baseUrl: _config.baseUrl,
      connectTimeout: Duration(seconds: AppConfig.defaultConnectTimeout),
      receiveTimeout: Duration(seconds: AppConfig.defaultReceiveTimeout * 2),
      headers: kIsWeb ? {
        'Accept': 'application/json',
        'Accept-Language': 'zh-CN,zh;q=0.9',
      } : {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15',
        ..._config.headers,
      },
    );

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        AppLogger.debug('Damai Account Request: ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        AppLogger.debug('Damai Account Response: ${response.statusCode} ${response.requestOptions.uri}');
        handler.next(response);
      },
      onError: (error, handler) {
        AppLogger.error('Damai Account Request error: ${error.message}', error);
        handler.next(error);
      },
    ));
  }

  Future<LoginResult> login(Account account) async {
    try {
      AppLogger.info('Attempting Damai login for account: ${account.username}');
      
      final loginPageResult = await _getLoginPage(account);
      if (!loginPageResult.success) {
        return LoginResult(
          success: false,
          message: loginPageResult.message,
        );
      }

      String? captchaResult;
      if (loginPageResult.needCaptcha) {
        captchaResult = await _handleCaptcha(loginPageResult.captchaImage!);
        if (captchaResult == null) {
          return LoginResult(
            success: false,
            message: '验证码识别失败',
          );
        }
      }

      final loginResult = await _submitLogin(
        account: account,
        token: loginPageResult.token!,
        captcha: captchaResult,
      );

      if (loginResult.success) {
        final userInfo = await _getUserInfo(loginResult.cookies!);
        if (userInfo != null) {
          return LoginResult(
            success: true,
            message: '登录成功',
            cookies: loginResult.cookies,
            token: loginResult.token,
            userInfo: userInfo,
          );
        }
      }

      return loginResult;
    } catch (e) {
      AppLogger.error('Damai Login failed', e);
      return LoginResult(
        success: false,
        message: '登录异常: $e',
      );
    }
  }

  Future<LoginPageResult> _getLoginPage(Account account) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final headers = {
        'X-DEVICE-ID': account.deviceId,
        'X-T': timestamp.toString(),
        'X-APP-KEY': _config.appKey,
        'X-UMID': await DeviceUtils.generateUmid(account.deviceId),
      };

      final response = await _dio.get(
        _config.getEndpoint('loginPage'),
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        return LoginPageResult(
          success: true,
          token: data['data']?['token'],
          needCaptcha: data['data']?['needCaptcha'] ?? false,
          captchaImage: data['data']?['captchaImage'],
        );
      }

      return LoginPageResult(
        success: false,
        message: '获取登录页面失败',
      );
    } catch (e) {
      return LoginPageResult(
        success: false,
        message: '获取登录页面异常: $e',
      );
    }
  }

  Future<String?> _handleCaptcha(String captchaImage) async {
    try {
      final imageBytes = base64Decode(captchaImage);
      final result = await _captchaService.recognizeCaptcha(imageBytes);
      
      if (result.success && result.text != null) {
        AppLogger.info('Captcha recognized: ${result.text}');
        return result.text;
      }
      return null;
    } catch (e) {
      AppLogger.error('Captcha handling error', e);
      return null;
    }
  }

  Future<LoginResult> _submitLogin({
    required Account account,
    required String token,
    String? captcha,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final params = {
        'loginId': account.username,
        'password': _encryptPassword(account.password),
        'token': token,
        if (captcha != null) 'captcha': captcha,
      };

      final signature = await _signatureService.generateSignature(
        params: params,
        deviceId: account.deviceId,
        timestamp: timestamp,
      );

      final headers = {
        'X-DEVICE-ID': account.deviceId,
        'X-T': timestamp.toString(),
        'X-APP-KEY': _config.appKey,
        'X-SIGN': signature,
        'X-UMID': await DeviceUtils.generateUmid(account.deviceId),
        'Content-Type': 'application/x-www-form-urlencoded',
      };

      final response = await _dio.post(
        _config.getEndpoint('loginSubmit'),
        data: params,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['ret']?[0] == 'SUCCESS::调用成功') {
          final cookies = _extractCookies(response);
          
          return LoginResult(
            success: true,
            message: '登录成功',
            cookies: cookies,
            token: data['data']?['token'],
          );
        } else {
          return LoginResult(
            success: false,
            message: data['ret']?[1] ?? '登录失败',
          );
        }
      }

      return LoginResult(
        success: false,
        message: '登录请求失败',
      );
    } catch (e) {
      return LoginResult(
        success: false,
        message: '登录请求异常: $e',
      );
    }
  }

  Future<Map<String, dynamic>?> _getUserInfo(Map<String, String> cookies) async {
    try {
      final cookieString = cookies.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');

      final response = await _dio.get(
        _config.getEndpoint('userInfo'),
        options: Options(
          headers: {'Cookie': cookieString},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['ret']?[0] == 'SUCCESS::调用成功') {
          return data['data'];
        }
      }

      return null;
    } catch (e) {
      AppLogger.error('Get user info failed', e);
      return null;
    }
  }

  String _encryptPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Map<String, String> _extractCookies(Response response) {
    final cookies = <String, String>{};
    final setCookieHeaders = response.headers['set-cookie'];
    if (setCookieHeaders != null) {
      for (final cookieHeader in setCookieHeaders) {
        final cookie = Cookie.fromSetCookieValue(cookieHeader);
        cookies[cookie.name] = cookie.value;
      }
    }
    return cookies;
  }

  /// 账号有效性检测
  Future<AccountCheckResult> checkAccount(Account account) async {
    try {
      AppLogger.info('Checking Damai account: ${account.username}');
      
      // 如果没有cookies，直接返回失败
      if (account.cookies == null || account.cookies!.isEmpty) {
        return AccountCheckResult(
          success: false,
          message: '账号未登录，请先登录或导入Cookie',
          isValid: false,
        );
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cookieString = account.cookies!.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');

      // 调用用户检测接口
      final headers = {
        'Cookie': cookieString,
        'X-DEVICE-ID': account.deviceId,
        'X-T': timestamp.toString(),
        'X-APP-KEY': _config.appKey,
      };

      final response = await _dio.get(
        _config.getEndpoint('userCheck'),
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final ret = data['ret'] as List?;
        
        if (ret != null && ret.isNotEmpty) {
          final retCode = ret[0] as String;
          
          if (retCode.startsWith('SUCCESS')) {
            final userData = data['data'];
            return AccountCheckResult(
              success: true,
              message: '账号有效',
              isValid: true,
              userInfo: {
                'userId': userData?['userId']?.toString() ?? '',
                'username': userData?['username'] ?? userData?['nickName'] ?? '',
                'phone': userData?['phone'] ?? '',
                'email': userData?['email'] ?? '',
                'vipLevel': userData?['vipLevel'] ?? 0,
                'realName': userData?['realName'] ?? '',
                'isRealNamed': userData?['isRealNamed'] ?? false,
              },
            );
          } else {
            // Token过期或账号异常
            return AccountCheckResult(
              success: true,
              message: ret.length > 1 ? ret[1] as String : '账号已过期',
              isValid: false,
            );
          }
        }
      }

      return AccountCheckResult(
        success: false,
        message: '检测账号失败',
        isValid: false,
      );
    } catch (e) {
      AppLogger.error('Check account failed', e);
      return AccountCheckResult(
        success: false,
        message: '检测账号异常: $e',
        isValid: false,
      );
    }
  }

  /// 快速验证Cookie有效性（轻量级检测）
  Future<bool> validateCookies(Map<String, dynamic> cookies) async {
    try {
      final cookieString = cookies.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');

      final response = await _dio.get(
        _config.getEndpoint('userInfo'),
        options: Options(headers: {'Cookie': cookieString}),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final ret = data['ret'] as List?;
        return ret != null && ret.isNotEmpty && ret[0].toString().startsWith('SUCCESS');
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 获取观演人列表
  Future<List<Map<String, dynamic>>> getViewerList(Account account) async {
    try {
      final cookieString = account.cookies?.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ') ?? '';

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final headers = {
        'Cookie': cookieString,
        'X-DEVICE-ID': account.deviceId,
        'X-T': timestamp.toString(),
        'X-APP-KEY': _config.appKey,
      };

      final response = await _dio.get(
        _config.getEndpoint('viewerList'),
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['ret']?[0]?.toString().startsWith('SUCCESS') == true) {
          return List<Map<String, dynamic>>.from(data['data']?['viewers'] ?? []);
        }
      }
      return [];
    } catch (e) {
      AppLogger.error('Get viewer list failed', e);
      return [];
    }
  }

  /// 添加观演人
  Future<bool> addViewer(Account account, {
    required String name,
    required String idCard,
    String? phone,
  }) async {
    try {
      final cookieString = account.cookies?.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ') ?? '';

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final params = {
        'name': name,
        'idCard': idCard,
        if (phone != null) 'phone': phone,
      };

      final signature = await _signatureService.generateSignature(
        params: params,
        deviceId: account.deviceId,
        timestamp: timestamp,
      );

      final headers = {
        'Cookie': cookieString,
        'X-DEVICE-ID': account.deviceId,
        'X-T': timestamp.toString(),
        'X-APP-KEY': _config.appKey,
        'X-SIGN': signature,
      };

      final response = await _dio.post(
        _config.getEndpoint('viewerAdd'),
        data: params,
        options: Options(headers: headers),
      );

      return response.statusCode == 200 && 
             response.data['ret']?[0]?.toString().startsWith('SUCCESS') == true;
    } catch (e) {
      AppLogger.error('Add viewer failed', e);
      return false;
    }
  }
}

class LoginResult {
  final bool success;
  final String? message;
  final Map<String, String>? cookies;
  final String? token;
  final Map<String, dynamic>? userInfo;

  LoginResult({
    required this.success,
    this.message,
    this.cookies,
    this.token,
    this.userInfo,
  });
}

class LoginPageResult {
  final bool success;
  final String? message;
  final String? token;
  final bool needCaptcha;
  final String? captchaImage;

  LoginPageResult({
    required this.success,
    this.message,
    this.token,
    this.needCaptcha = false,
    this.captchaImage,
  });
}

/// 账号检测结果
class AccountCheckResult {
  final bool success;
  final String message;
  final bool isValid;
  final Map<String, dynamic>? userInfo;

  AccountCheckResult({
    required this.success,
    required this.message,
    required this.isValid,
    this.userInfo,
  });
}
