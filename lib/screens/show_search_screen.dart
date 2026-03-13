import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/platform_config.dart';
import '../models/show.dart';
import '../providers/show_provider.dart';
import '../utils/theme.dart';
import 'dart:math' as math;

/// 演出搜索界面 - 炫酷现代化设计
class ShowSearchScreen extends StatefulWidget {
  const ShowSearchScreen({super.key});

  @override
  State<ShowSearchScreen> createState() => _ShowSearchScreenState();
}

class _ShowSearchScreenState extends State<ShowSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: TicketPlatform.values.length,
      vsync: this,
    );
    
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _loadRecommendations();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecommendations();
    });
  }

  void _loadRecommendations() {
    final platform = TicketPlatform.values[_tabController.index];
    final provider = context.read<ShowProvider>();
    provider.loadRecommendations(platform);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1a1a2e),
              const Color(0xFF16213e),
              const Color(0xFF0f3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildPlatformTabs(),
              Expanded(
                child: Consumer<ShowProvider>(
                  builder: (context, showProvider, child) {
                    return TabBarView(
                      controller: _tabController,
                      children: TicketPlatform.values.map((platform) {
                        return _buildSearchResults(platform, showProvider);
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          // 标题
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFe94560), Color(0xFFff6b9d)],
                ).createShader(bounds),
                child: const Text(
                  '🎫 演出搜索',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 搜索框
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFe94560).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '搜索演唱会、音乐节、话剧...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFe94560)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white54),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              onSubmitted: _performSearch,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(25),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: const LinearGradient(
            colors: [Color(0xFFe94560), Color(0xFFff6b9d)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFe94560).withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: TicketPlatform.values.map((platform) {
          final config = PlatformConfig.getConfig(platform);
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(config.platformIcon),
                const SizedBox(width: 6),
                Text(config.platformName),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchResults(TicketPlatform platform, ShowProvider showProvider) {
    if (showProvider.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFe94560)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '正在加载演出信息...',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
      );
    }

    final results = showProvider.searchResults[platform] ?? [];
    final recommendations = showProvider.recommendations[platform] ?? [];
    
    if (_searchController.text.isEmpty) {
      if (recommendations.isEmpty) {
         if (showProvider.isLoading) {
           return const Center(
             child: CircularProgressIndicator(
               valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFe94560)),
             ),
           );
         }
         return _buildEmptyState('暂无热门推荐');
      }
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFe94560), Color(0xFFff6b9d)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.whatshot, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  '🔥 热门演出推荐',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: recommendations.length,
              itemBuilder: (context, index) {
                final result = recommendations[index];
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 300 + (index * 100)),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 50 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: _buildModernShowCard(platform, result, showProvider, isRecommendation: true),
                );
              },
            ),
          ),
        ],
      );
    }

    if (results.isEmpty) {
      return _buildEmptyState('未找到相关演出');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return _buildModernShowCard(platform, result, showProvider);
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy,
              size: 48,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernShowCard(
    TicketPlatform platform,
    Map<String, dynamic> result,
    ShowProvider showProvider, {
    bool isRecommendation = false,
  }) {
    final config = PlatformConfig.getConfig(platform);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showAddDialog(platform, result, showProvider),
            splashColor: Colors.white.withOpacity(0.1),
            highlightColor: Colors.white.withOpacity(0.05),
            child: Stack(
              children: [
                // 背景装饰
                Positioned(
                  right: -50,
                  top: -50,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          _getPlatformColor(platform).withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 顶部标签行
                      Row(
                        children: [
                          // 平台标签
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _getPlatformGradientColors(platform)[0],
                                  _getPlatformGradientColors(platform)[1],
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _getPlatformColor(platform).withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(config.platformIcon, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 4),
                                Text(
                                  config.platformName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          if (isRecommendation) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_fire_department, color: Colors.white, size: 14),
                                  SizedBox(width: 2),
                                  Text(
                                    'HOT',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          
                          // 演出类型标签
                          if (result['category'] != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.purple.withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                result['category'].toString(),
                                style: const TextStyle(
                                  color: Colors.purpleAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          
                          const Spacer(),
                          
                          // 添加按钮
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFe94560),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFe94560).withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add, color: Colors.white),
                              onPressed: () => _showAddDialog(platform, result, showProvider),
                              iconSize: 20,
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 演出海报和信息
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 海报
                          if (result['cover'] != null && result['cover'].isNotEmpty)
                            Container(
                              width: 100,
                              height: 140,
                              margin: const EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      result['cover'],
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.grey[800],
                                        child: const Icon(Icons.music_note, color: Colors.white54, size: 40),
                                      ),
                                    ),
                                    // 渐变遮罩
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 40,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.7),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          
                          // 信息
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 演出名称
                                Text(
                                  _getResultTitle(platform, result),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                
                                // 艺人/演员
                                if (_getResultSubtitle(platform, result) != null) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.person, size: 14, color: Colors.cyanAccent.withOpacity(0.8)),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _getResultSubtitle(platform, result)!,
                                          style: TextStyle(
                                            color: Colors.cyanAccent.withOpacity(0.8),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                
                                const SizedBox(height: 12),
                                
                                // 地点
                                if (_getResultVenue(platform, result) != null)
                                  _buildInfoChip(
                                    Icons.location_on,
                                    _getResultVenue(platform, result)!,
                                    Colors.redAccent,
                                  ),
                                
                                const SizedBox(height: 8),
                                
                                // 时间
                                if (_getResultTime(platform, result) != null)
                                  _buildInfoChip(
                                    Icons.access_time,
                                    _getResultTime(platform, result)!,
                                    Colors.blueAccent,
                                  ),
                                
                                const SizedBox(height: 12),
                                
                                // 价格
                                if (_getResultPrice(platform, result) != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF00b894), Color(0xFF00cec9)],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF00b894).withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.confirmation_number, color: Colors.white, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          _getResultPrice(platform, result)!,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color.withOpacity(0.8)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  List<Color> _getPlatformGradientColors(TicketPlatform platform) {
    switch (platform) {
      case TicketPlatform.damai:
        return [const Color(0xFFe94560), const Color(0xFFff6b9d)];
      case TicketPlatform.maoyan:
        return [const Color(0xFFf39c12), const Color(0xFFe74c3c)];
      case TicketPlatform.xiudong:
        return [const Color(0xFF43e97b), const Color(0xFF38f9d7)];
    }
  }

  String _getResultTitle(TicketPlatform platform, Map<String, dynamic> result) {
    switch (platform) {
      case TicketPlatform.damai:
        return result['name'] ?? result['title'] ?? '未知演出';
      case TicketPlatform.maoyan:
        return result['movieName'] ?? result['name'] ?? '未知电影';
      case TicketPlatform.xiudong:
        return result['name'] ?? result['activityName'] ?? '未知演出';
    }
  }

  String? _getResultSubtitle(TicketPlatform platform, Map<String, dynamic> result) {
    switch (platform) {
      case TicketPlatform.damai:
        return result['artist'] ?? result['performer'];
      case TicketPlatform.maoyan:
        return result['director'] ?? result['actors'];
      case TicketPlatform.xiudong:
        return result['performer'] ?? result['artist'];
    }
  }

  String? _getResultVenue(TicketPlatform platform, Map<String, dynamic> result) {
    switch (platform) {
      case TicketPlatform.damai:
        return result['venue'] ?? result['cityName'];
      case TicketPlatform.maoyan:
        return result['cinemaName'] ?? '多个影院';
      case TicketPlatform.xiudong:
        return result['venue'] ?? result['address'];
    }
  }

  String? _getResultTime(TicketPlatform platform, Map<String, dynamic> result) {
    switch (platform) {
      case TicketPlatform.damai:
        final showTime = result['showTime'];
        if (showTime != null) {
          final dateTime = DateTime.tryParse(showTime);
          if (dateTime != null) {
            return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
          }
        }
        return null;
      case TicketPlatform.maoyan:
        return result['releaseDate'] ?? result['showDate'];
      case TicketPlatform.xiudong:
        return result['showTime'] ?? result['startTime'];
    }
  }

  String? _getResultPrice(TicketPlatform platform, Map<String, dynamic> result) {
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
        final price = result['price'];
        if (price != null) {
          return '¥$price 起';
        }
        return null;
      case TicketPlatform.xiudong:
        final minPrice = result['minPrice'];
        final maxPrice = result['maxPrice'];
        if (minPrice != null && maxPrice != null) {
          return '¥$minPrice - ¥$maxPrice';
        } else if (minPrice != null) {
          return '¥$minPrice 起';
        }
        return null;
    }
  }

  Color _getPlatformColor(TicketPlatform platform) {
    switch (platform) {
      case TicketPlatform.damai:
        return Colors.red;
      case TicketPlatform.maoyan:
        return Colors.orange;
      case TicketPlatform.xiudong:
        return Colors.green;
    }
  }

  void _performSearch(String keyword) {
    if (keyword.trim().isEmpty) return;
    
    final platform = TicketPlatform.values[_tabController.index];
    context.read<ShowProvider>().search(
      platform: platform,
      keyword: keyword.trim(),
    );
  }

  void _showAddDialog(
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
            Text('确定要添加以下演出吗？'),
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
                    _getResultTitle(platform, result),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (_getResultSubtitle(platform, result) != null)
                    Text(_getResultSubtitle(platform, result)!),
                  if (_getResultVenue(platform, result) != null)
                    Text(_getResultVenue(platform, result)!),
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
              await _addShowFromResult(platform, result, showProvider);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  Future<void> _addShowFromResult(
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

      if (show != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已添加演出：${show.name}'),
              action: SnackBarAction(
                label: '查看',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('添加演出失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
}