/// ============================================================================
/// 免责声明 / Disclaimer
/// ============================================================================
/// 本项目仅供学习交流使用，严禁用于商业用途和违法行为。
/// This project is for educational and research purposes only.
/// Commercial use and illegal activities are strictly prohibited.
/// 
/// 使用本软件即表示您同意：
/// By using this software, you agree that:
/// 1. 本软件仅用于技术研究和学习目的
///    This software is used solely for technical research and learning
/// 2. 使用者需遵守当地法律法规及平台服务条款
///    Users must comply with local laws and platform terms of service
/// 3. 开发者不对使用本软件造成的任何后果负责
///    Developers are not responsible for any consequences of using this software
/// 4. 请尊重演出主办方、平台及其他用户的权益
///    Please respect the rights of event organizers, platforms and other users
/// 
/// ⚠️ 警告：滥用本软件可能导致账号封禁、法律责任等严重后果
/// ⚠️ Warning: Abuse may result in account bans, legal liability, etc.
/// ============================================================================

import 'dart:ui';
import 'package:flutter/foundation.dart' show FlutterError, FlutterErrorDetails, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/account_management_screen.dart';
import 'screens/show_config_screen.dart';
import 'screens/unified_hunting_screen.dart';
import 'providers/account_provider.dart';
import 'providers/show_provider.dart';
import 'providers/ticket_hunter_provider.dart';
import 'utils/theme.dart';
import 'utils/logger.dart';
import 'config/app_config.dart';
import 'services/rsa_encryption_service.dart';

void main() async {
  // 捕获所有未处理的错误
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error('Flutter error: ${details.exception}', details.exception, details.stack);
    // 在 Web 上打印到控制台
    if (kIsWeb) {
      print('Flutter Error: ${details.exception}');
      print('Stack: ${details.stack}');
    }
  };
  
  // 捕获异步错误
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('Uncaught error', error, stack);
    if (kIsWeb) {
      print('Uncaught Error: $error');
      print('Stack: $stack');
    }
    return true;
  };
  
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化SharedPreferences
  try {
    await SharedPreferences.getInstance();
  } catch (e) {
    AppLogger.error('Failed to initialize SharedPreferences', e);
  }
  
  // 初始化应用配置（Web平台跳过可能失败的操作）
  try {
    await AppConfig.instance.initialize();
    AppLogger.info('App config initialized');
  } catch (e) {
    AppLogger.error('Failed to initialize app config', e);
  }
  
  // 初始化RSA加密服务（Web平台可能不完全支持）
  if (!kIsWeb) {
    try {
      await RsaEncryptionService.instance.initialize();
      AppLogger.info('RSA encryption service initialized');
    } catch (e) {
      AppLogger.error('Failed to initialize RSA service', e);
    }
  }
  
  runApp(const TicketHunterProApp());
}

class TicketHunterProApp extends StatelessWidget {
  const TicketHunterProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AccountProvider()),
        ChangeNotifierProvider(create: (_) => ShowProvider()),
        ChangeNotifierProvider(create: (_) => TicketHunterProvider()),
      ],
      child: MaterialApp(
        title: '票务猎手',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const MainNavigator(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;
  bool _disclaimerShown = false;
  
  // 懒加载 Screen 列表
  final List<Widget> _screens = [];
  
  Widget _getScreen(int index) {
    while (_screens.length <= index) {
      switch (_screens.length) {
        case 0:
          _screens.add(const HomeScreen());
          break;
        case 1:
          _screens.add(const AccountManagementScreen());
          break;
        case 2:
          _screens.add(const ShowConfigScreen());
          break;
        case 3:
          _screens.add(const UnifiedHuntingScreen());
          break;
        default:
          _screens.add(const SizedBox.shrink());
      }
    }
    return _screens[index];
  }

  @override
  void initState() {
    super.initState();
    // 应用启动时显示免责声明
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDisclaimerDialog();
    });
  }

  /// 显示免责声明对话框
  Future<void> _showDisclaimerDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final hasAgreed = prefs.getBool('disclaimer_agreed') ?? false;
    
    if (!hasAgreed && mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('免责声明'),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '重要提示',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '本软件仅供学习研究使用，严禁用于商业用途和违法行为。\n\n'
                  '使用本软件即表示您同意：\n'
                  '1. 本软件仅用于技术研究和学习目的\n'
                  '2. 使用者需遵守当地法律法规及平台服务条款\n'
                  '3. 开发者不对使用本软件造成的任何后果负责\n'
                  '4. 请尊重演出主办方、平台及其他用户的权益\n\n'
                  '⚠️ 警告：滥用本软件可能导致账号封禁或法律责任',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('不同意', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                await prefs.setBool('disclaimer_agreed', true);
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
                if (mounted) {
                  setState(() {
                    _disclaimerShown = true;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: const Text('同意并继续'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getScreen(_currentIndex),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f0c29),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFFf093fb),
          unselectedItemColor: Colors.white54,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
          ),
          selectedIconTheme: const IconThemeData(
            size: 28,
            shadows: [
              Shadow(
                color: Color(0xFFf093fb),
                blurRadius: 10,
              ),
            ],
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: '首页',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle_outlined),
              activeIcon: Icon(Icons.account_circle),
              label: '账号',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.music_note_outlined),
              activeIcon: Icon(Icons.music_note),
              label: '演出',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.flash_on_outlined),
              activeIcon: Icon(Icons.flash_on),
              label: '抢票',
            ),
          ],
        ),
      ),
    );
  }
}