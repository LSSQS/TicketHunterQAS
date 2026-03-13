import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../providers/show_provider.dart';
import '../providers/ticket_hunter_provider.dart';
import '../models/platform_config.dart';
import '../models/show.dart';
import '../utils/logger.dart';
import 'account_management_screen.dart';
import 'show_config_screen.dart';
import 'show_search_screen.dart';
import 'platform_selection_screen.dart';
import 'unified_hunting_screen.dart';
import 'dart:math' as math;
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    try {
      await context.read<AccountProvider>().loadAccounts();
      if (!mounted) return;
      await context.read<ShowProvider>().loadShows();
    } catch (e) {
      AppLogger.error('Failed to initialize data', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 动态渐变背景
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0f0c29),
                  Color(0xFF302b63),
                  Color(0xFF24243e),
                ],
              ),
            ),
          ),
          // 粒子特效层
          ParticleBackground(),
          // 主内容
          SafeArea(
            child: Column(
              children: [
                _buildAnimatedHeader(),
                _buildStatusCard(),
                _buildQuickActions(),
                Expanded(child: _buildShowList()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildAnimatedFAB(),
    );
  }
  
  Widget _buildAnimatedHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // 标题动画
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFFf093fb),
                      Color(0xFFf5576c),
                      Color(0xFF4facfe),
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    '🎫 票务猎手',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
          const Spacer(),
          // 动画按钮
          _buildGlowingButton(
            icon: Icons.swap_horiz,
            onPressed: () => _showPlatformSelection(context),
            gradient: const [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
          const SizedBox(width: 12),
          _buildGlowingButton(
            icon: Icons.settings,
            onPressed: () => _showSettingsMenu(context),
            gradient: const [Color(0xFFf093fb), Color(0xFFf5576c)],
          ),
        ],
      ),
    );
  }
  
  Widget _buildGlowingButton({
    required IconData icon,
    required VoidCallback onPressed,
    required List<Color> gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: gradient),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.6),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
  
  Widget _buildAnimatedFAB() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFf093fb).withOpacity(0.6),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () => _navigateToShowConfig(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Consumer2<TicketHunterProvider, ShowProvider>(
      builder: (context, huntingProvider, showProvider, child) {
        final selectedPlatform = showProvider.selectedPlatform ?? TicketPlatform.damai;
        final platformConfig = PlatformConfig.getConfig(selectedPlatform);
        
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [
                              _getPlatformGradientColors(selectedPlatform)[0],
                              _getPlatformGradientColors(selectedPlatform)[1],
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _getPlatformGradientColors(selectedPlatform)[0].withOpacity(0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          platformConfig.platformIcon,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '当前平台',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: _getPlatformGradientColors(selectedPlatform),
                            ).createShader(bounds),
                            child: Text(
                              platformConfig.platformName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          _getStatusGradientColors(huntingProvider.status)[0],
                          _getStatusGradientColors(huntingProvider.status)[1],
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _getStatusGradientColors(huntingProvider.status)[0].withOpacity(0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(huntingProvider.status),
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getStatusText(huntingProvider.status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildAnimatedStatusItem(
                      '活跃演出',
                      showProvider.activeShows.length.toString(),
                      Icons.event,
                      const [Color(0xFF4facfe), Color(0xFF00f2fe)],
                    ),
                  ),
                  Expanded(
                    child: _buildAnimatedStatusItem(
                      '成功次数',
                      huntingProvider.successCount.toString(),
                      Icons.check_circle_outline,
                      const [Color(0xFF43e97b), Color(0xFF38f9d7)],
                    ),
                  ),
                  Expanded(
                    child: _buildAnimatedStatusItem(
                      '失败次数',
                      huntingProvider.errorCount.toString(),
                      Icons.error_outline,
                      const [Color(0xFFfa709a), Color(0xFFfee140)],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  
  List<Color> _getPlatformGradientColors(TicketPlatform platform) {
    switch (platform) {
      case TicketPlatform.damai:
        return [const Color(0xFFf093fb), const Color(0xFFf5576c)];
      case TicketPlatform.maoyan:
        return [const Color(0xFFfa709a), const Color(0xFFfee140)];
      case TicketPlatform.xiudong:
        return [const Color(0xFF43e97b), const Color(0xFF38f9d7)];
    }
  }
  
  List<Color> _getStatusGradientColors(TicketHunterStatus status) {
    switch (status) {
      case TicketHunterStatus.idle:
        return [const Color(0xFF667eea), const Color(0xFF764ba2)];
      case TicketHunterStatus.running:
        return [const Color(0xFF43e97b), const Color(0xFF38f9d7)];
      case TicketHunterStatus.paused:
        return [const Color(0xFFfa709a), const Color(0xFFfee140)];
      case TicketHunterStatus.error:
        return [const Color(0xFFf093fb), const Color(0xFFf5576c)];
      case TicketHunterStatus.success:
        return [const Color(0xFF43e97b), const Color(0xFF38f9d7)];
      case TicketHunterStatus.paying:
        return [const Color(0xFF4facfe), const Color(0xFF00f2fe)];
      case TicketHunterStatus.paid:
        return [const Color(0xFF43e97b), const Color(0xFF38f9d7)];
    }
  }
  
  IconData _getStatusIcon(TicketHunterStatus status) {
    switch (status) {
      case TicketHunterStatus.idle:
        return Icons.pause_circle_outline;
      case TicketHunterStatus.running:
        return Icons.play_circle_outline;
      case TicketHunterStatus.paused:
        return Icons.pause_circle_outline;
      case TicketHunterStatus.error:
        return Icons.error_outline;
      case TicketHunterStatus.success:
        return Icons.check_circle_outline;
      case TicketHunterStatus.paying:
        return Icons.payment;
      case TicketHunterStatus.paid:
        return Icons.check_circle_outline;
    }
  }

  Widget _buildAnimatedStatusItem(String label, String value, IconData icon, List<Color> gradientColors) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (context, animValue, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * animValue),
          child: Opacity(
            opacity: animValue,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: gradientColors),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors[0].withOpacity(0.5),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 12),
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(colors: gradientColors).createShader(bounds),
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        children: [
          // 平台选择按钮 - 炫酷版
          Consumer<ShowProvider>(
            builder: (context, showProvider, child) {
              final selectedPlatform = showProvider.selectedPlatform ?? TicketPlatform.damai;
              final platformConfig = PlatformConfig.getConfig(selectedPlatform);
              
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: GestureDetector(
                        onTap: () => _showPlatformSelection(context),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.15),
                                Colors.white.withOpacity(0.05),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    colors: _getPlatformGradientColors(selectedPlatform),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _getPlatformGradientColors(selectedPlatform)[0].withOpacity(0.5),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.swap_horiz, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '选择抢票平台',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ShaderMask(
                                      shaderCallback: (bounds) => LinearGradient(
                                        colors: _getPlatformGradientColors(selectedPlatform),
                                      ).createShader(bounds),
                                      child: Text(
                                        platformConfig.platformName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // 功能按钮 - 炫酷网格版
          Row(
            children: [
              Expanded(
                child: _buildGlowingActionButton(
                  '账号管理',
                  Icons.account_circle,
                  const [Color(0xFF4facfe), Color(0xFF00f2fe)],
                  () => _navigateToAccountManagement(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGlowingActionButton(
                  '演出配置',
                  Icons.event,
                  const [Color(0xFF43e97b), Color(0xFF38f9d7)],
                  () => _navigateToShowConfig(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGlowingActionButton(
                  '开始抢票',
                  Icons.flash_on,
                  const [Color(0xFFfa709a), Color(0xFFfee140)],
                  () => _navigateToHunting(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildGlowingActionButton(
    String label,
    IconData icon,
    List<Color> gradientColors,
    VoidCallback onPressed,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(
            opacity: value,
            child: GestureDetector(
              onTap: onPressed,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: gradientColors),
                        boxShadow: [
                          BoxShadow(
                            color: gradientColors[0].withOpacity(0.5),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 12),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(colors: gradientColors).createShader(bounds),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildShowList() {
    return Consumer<ShowProvider>(
      builder: (context, provider, child) {
        final shows = provider.activeShows;
        
        // 如果有已保存的演出，显示演出列表
        if (shows.isNotEmpty) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: shows.length,
            itemBuilder: (context, index) {
              final show = shows[index];
              return _buildShowCard(show);
            },
          );
        }
        
        // 如果没有已保存的演出，检查是否有推荐数据
        final selectedPlatform = provider.selectedPlatform;
        if (selectedPlatform != null) {
          final recommendations = provider.recommendations[selectedPlatform] ?? [];
          
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (recommendations.isNotEmpty) {
            return _buildRecommendationsList(selectedPlatform, recommendations, provider);
          }
        }
        
        // 显示空状态
        return _buildEmptyState();
      },
    );
  }

  Widget _buildRecommendationsList(
    TicketPlatform platform,
    List<Map<String, dynamic>> recommendations,
    ShowProvider showProvider,
  ) {
    final platformConfig = PlatformConfig.getConfig(platform);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.whatshot, color: Colors.red[600], size: 24),
              const SizedBox(width: 8),
              Text(
                '今日热门推荐',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _navigateToSearch(),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('更多'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recommendations.length,
            itemBuilder: (context, index) {
              final result = recommendations[index];
              return _buildRecommendationCard(platform, result, showProvider, platformConfig);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(
    TicketPlatform platform,
    Map<String, dynamic> result,
    ShowProvider showProvider,
    PlatformConfig platformConfig,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      child: InkWell(
        onTap: () => _showAddRecommendationDialog(platform, result, showProvider),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPlatformColor(platform).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(platformConfig.platformIcon, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          platformConfig.platformName,
                          style: TextStyle(
                            color: _getPlatformColor(platform),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red[600],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'HOT',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _getRecommendationTitle(platform, result),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              if (_getRecommendationVenue(platform, result) != null)
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _getRecommendationVenue(platform, result)!,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_getRecommendationPrice(platform, result) != null)
                    Text(
                      _getRecommendationPrice(platform, result)!,
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ElevatedButton(
                    onPressed: () => _showAddRecommendationDialog(platform, result, showProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('添加'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRecommendationTitle(TicketPlatform platform, Map<String, dynamic> result) {
    switch (platform) {
      case TicketPlatform.damai:
        return result['name'] ?? result['title'] ?? '未知演出';
      case TicketPlatform.maoyan:
      case TicketPlatform.xiudong:
        return result['movieName'] ?? result['name'] ?? '未知电影';
    }
  }

  String? _getRecommendationVenue(TicketPlatform platform, Map<String, dynamic> result) {
    switch (platform) {
      case TicketPlatform.damai:
        return result['venue'] ?? result['cityName'];
      case TicketPlatform.maoyan:
      case TicketPlatform.xiudong:
        return result['cinemaName'] ?? '多个影院';
    }
  }

  String? _getRecommendationPrice(TicketPlatform platform, Map<String, dynamic> result) {
    switch (platform) {
      case TicketPlatform.damai:
        final minPrice = result['minPrice'];
        final maxPrice = result['maxPrice'];
        if (minPrice != null && maxPrice != null) {
          return '¥$minPrice - ¥$maxPrice';
        } else if (minPrice != null) {
          return '¥$minPrice 起';
        }
        return null;
      case TicketPlatform.maoyan:
      case TicketPlatform.xiudong:
        final price = result['price'];
        if (price != null) {
          return '¥$price 起';
        }
        return null;
    }
  }

  void _showAddRecommendationDialog(
    TicketPlatform platform,
    Map<String, dynamic> result,
    ShowProvider showProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加演出'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('确定要添加以下演出吗？'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getRecommendationTitle(platform, result),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (_getRecommendationVenue(platform, result) != null)
                    Text(_getRecommendationVenue(platform, result)!),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _addRecommendationToShow(platform, result, showProvider);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  Future<void> _addRecommendationToShow(
    TicketPlatform platform,
    Map<String, dynamic> result,
    ShowProvider showProvider,
  ) async {
    try {
      final show = await showProvider.createShowFromSearchResult(
        platform: platform,
        searchResult: result,
        config: {
          'maxConcurrency': 50,
          'retryCount': 5,
          'retryDelay': 100,
          'autoStart': false,
        },
      );

      if (show != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已添加演出：${show.name}'),
            action: SnackBarAction(
              label: '查看',
              onPressed: () => _navigateToShowConfig(),
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('添加演出失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('添加演出失败：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Consumer<ShowProvider>(
      builder: (context, showProvider, child) {
        final selectedPlatform = showProvider.selectedPlatform;
        final platformConfig = selectedPlatform != null 
            ? PlatformConfig.getConfig(selectedPlatform)
            : null;
            
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selectedPlatform == null ? Icons.apps_outlined : Icons.event_busy,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                selectedPlatform == null ? '请先选择抢票平台' : '暂无演出配置',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                selectedPlatform == null 
                    ? '点击上方"选择抢票平台"开始使用'
                    : '搜索或添加${platformConfig?.platformName}演出',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 24),
              if (selectedPlatform == null) ...[
                ElevatedButton(
                  onPressed: () => _showPlatformSelection(context),
                  child: const Text('选择平台'),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: () => _navigateToSearch(),
                  icon: const Icon(Icons.search),
                  label: const Text('搜索演出'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => _navigateToShowConfig(),
                  icon: const Icon(Icons.add),
                  label: const Text('手动添加'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildShowCard(Show show) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToShowDetail(show),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    show.platformIcon,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      show.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: show.isEnabled ? Colors.green : Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      show.isEnabled ? '启用' : '禁用',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '地点: ${show.venue}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '票档: ${show.skus.length} 个',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPlatformColor(show.platform).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      show.platformName,
                      style: TextStyle(
                        color: _getPlatformColor(show.platform),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          show.isEnabled ? Icons.pause : Icons.play_arrow,
                          color: show.isEnabled ? Colors.orange : Colors.green,
                        ),
                        onPressed: () => _toggleShow(show),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editShow(show),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteShow(show),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPlatformColor(TicketPlatform platform) {
    switch (platform) {
      case TicketPlatform.damai:
        return Colors.red;
      case TicketPlatform.maoyan:
      case TicketPlatform.xiudong:
        return Colors.orange;
    }
  }

  Color _getStatusColor(TicketHunterStatus status) {
    switch (status) {
      case TicketHunterStatus.idle:
        return Colors.grey;
      case TicketHunterStatus.running:
        return Colors.green;
      case TicketHunterStatus.paused:
        return Colors.orange;
      case TicketHunterStatus.error:
        return Colors.red;
      case TicketHunterStatus.success:
        return Colors.green;
      case TicketHunterStatus.paying:
        return Colors.blue;
      case TicketHunterStatus.paid:
        return Colors.green;
    }
  }

  String _getStatusText(TicketHunterStatus status) {
    switch (status) {
      case TicketHunterStatus.idle:
        return '空闲';
      case TicketHunterStatus.running:
        return '运行中';
      case TicketHunterStatus.paused:
        return '已暂停';
      case TicketHunterStatus.error:
        return '错误';
      case TicketHunterStatus.success:
        return '抢票成功';
      case TicketHunterStatus.paying:
        return '支付中';
      case TicketHunterStatus.paid:
        return '支付完成';
    }
  }

  void _showPlatformSelection(BuildContext context) async {
    final selectedPlatform = await Navigator.push<TicketPlatform>(
      context,
      MaterialPageRoute(
        builder: (context) => const PlatformSelectionScreen(),
      ),
    );
    
    if (selectedPlatform != null) {
      final showProvider = context.read<ShowProvider>();
      showProvider.setSelectedPlatform(selectedPlatform);
      
      // 如果本地没有演出数据，自动加载推荐数据
      if (showProvider.shows.isEmpty) {
        await showProvider.loadRecommendations(selectedPlatform);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已切换到${PlatformConfig.getConfig(selectedPlatform).platformName}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('切换平台'),
              onTap: () {
                Navigator.pop(context);
                _showPlatformSelection(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('账号管理'),
              onTap: () {
                Navigator.pop(context);
                _navigateToAccountManagement();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('应用设置'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 导航到设置页面
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('关于应用'),
              onTap: () {
                Navigator.pop(context);
                _showAboutDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: '票务猎手',
      applicationVersion: '2.1.0',
      applicationIcon: const Icon(Icons.flash_on, size: 48),
      children: [
        const Text('专业的多平台抢票工具'),
        const SizedBox(height: 16),
        const Text('支持平台:'),
        const Text('• 大麦票务 - 演唱会、话剧、体育赛事'),
        const Text('• 猫眼票务 - 电影票、演出票'),
        const Text('• 秀洞 - 演唱会、音乐节'),
        const SizedBox(height: 16),
        const Text('功能特性:'),
        const Text('• 多平台统一管理'),
        const Text('• 智能抢票算法'),
        const Text('• 实时状态监控'),
        const Text('• 批量抢票支持'),
      ],
    );
  }

  void _navigateToAccountManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AccountManagementScreen()),
    );
  }

  void _navigateToShowConfig() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ShowConfigScreen()),
    );
  }

  void _navigateToSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ShowSearchScreen()),
    );
  }

  void _navigateToHunting() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UnifiedHuntingScreen()),
    );
  }

  void _navigateToShowDetail(Show show) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShowConfigScreen(show: show),
      ),
    );
  }

  void _editShow(Show show) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShowConfigScreen(show: show),
      ),
    );
  }

  void _toggleShow(Show show) {
    context.read<ShowProvider>().toggleShow(show.id);
  }

  void _deleteShow(Show show) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除演出 "${show.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<ShowProvider>().removeShow(show.id);
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// 粒子特效背景
class ParticleBackground extends StatefulWidget {
  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final int particleCount = 50;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    
    // 初始化粒子
    for (int i = 0; i < particleCount; i++) {
      _particles.add(Particle());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: ParticlePainter(_particles, _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class Particle {
  double x;
  double y;
  double speed;
  double size;
  Color color;
  double opacity;

  Particle()
      : x = math.Random().nextDouble(),
        y = math.Random().nextDouble(),
        speed = 0.0005 + math.Random().nextDouble() * 0.001,
        size = 2 + math.Random().nextDouble() * 4,
        color = [
          const Color(0xFFf093fb),
          const Color(0xFFf5576c),
          const Color(0xFF4facfe),
          const Color(0xFF00f2fe),
          const Color(0xFF43e97b),
        ][math.Random().nextInt(5)],
        opacity = 0.3 + math.Random().nextDouble() * 0.7;

  void update() {
    y -= speed;
    if (y < -0.1) {
      y = 1.1;
      x = math.Random().nextDouble();
    }
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animationValue;

  ParticlePainter(this.particles, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      // 更新粒子位置
      particle.update();
      
      final paint = Paint()
        ..color = particle.color.withOpacity(particle.opacity)
        ..style = PaintingStyle.fill;

      final center = Offset(
        particle.x * size.width,
        particle.y * size.height,
      );

      // 绘制发光粒子
      canvas.drawCircle(
        center,
        particle.size,
        paint..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );

      // 绘制粒子核心
      canvas.drawCircle(
        center,
        particle.size * 0.5,
        Paint()..color = Colors.white.withOpacity(particle.opacity * 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}