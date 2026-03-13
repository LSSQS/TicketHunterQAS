import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/show.dart';
import '../models/account.dart';
import '../models/platform_config.dart';
import '../providers/show_provider.dart';
import '../providers/account_provider.dart';
import '../providers/ticket_hunter_provider.dart';
import '../services/unified_ticket_service.dart';
import '../utils/theme.dart';

/// 统一抢票界面
class UnifiedHuntingScreen extends StatefulWidget {
  const UnifiedHuntingScreen({super.key});

  @override
  State<UnifiedHuntingScreen> createState() => _UnifiedHuntingScreenState();
}

class _UnifiedHuntingScreenState extends State<UnifiedHuntingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UnifiedTicketService _ticketService = UnifiedTicketService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // 加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShowProvider>().loadShows();
      context.read<AccountProvider>().loadAccounts();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('统一抢票'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '快速抢票'),
            Tab(text: '批量抢票'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _showHuntingHistory,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuickHuntingTab(),
          _buildBatchHuntingTab(),
        ],
      ),
    );
  }

  Widget _buildQuickHuntingTab() {
    return Consumer3<ShowProvider, AccountProvider, TicketHunterProvider>(
      builder: (context, showProvider, accountProvider, huntingProvider, child) {
        final activeShows = showProvider.activeShows;
        final accounts = accountProvider.accounts;

        if (activeShows.isEmpty) {
          return _buildEmptyState(
            icon: Icons.event_busy,
            title: '暂无活跃演出',
            subtitle: '请先在演出配置中添加演出',
            actionText: '添加演出',
            onAction: () => _navigateToShowConfig(),
          );
        }

        if (accounts.isEmpty) {
          return _buildEmptyState(
            icon: Icons.account_circle_outlined,
            title: '暂无可用账号',
            subtitle: '请先在账号管理中添加账号',
            actionText: '添加账号',
            onAction: () => _navigateToAccountManagement(),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 平台统计
              _buildPlatformStats(showProvider),
              const SizedBox(height: 20),
              
              // 演出列表
              Text(
                '活跃演出 (${activeShows.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              ...activeShows.map((show) => _buildQuickHuntingCard(
                show, accounts, huntingProvider,
              )),
              
              const SizedBox(height: 20),
              // 日志区域
              if (huntingProvider.logs.isNotEmpty) ...[
                 _buildLogPanel(huntingProvider),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildBatchHuntingTab() {
    return Consumer3<ShowProvider, AccountProvider, TicketHunterProvider>(
      builder: (context, showProvider, accountProvider, huntingProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 批量配置
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '批量抢票配置',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // 选择演出
                      _buildBatchShowSelector(showProvider),
                      const SizedBox(height: 12),
                      
                      // 选择账号
                      _buildBatchAccountSelector(accountProvider),
                      const SizedBox(height: 16),
                      
                      // 批量操作按钮
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: huntingProvider.isHunting ? null : () => _startBatchHunting(
                                showProvider, accountProvider, huntingProvider,
                              ),
                              child: Text(huntingProvider.isHunting ? '抢票中...' : '开始批量抢票'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: huntingProvider.isHunting ? () => huntingProvider.stopHunting() : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('停止'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // 抢票状态
            if (huntingProvider.isHunting || huntingProvider.status != TicketHunterStatus.idle) ...[
              _buildHuntingStatus(huntingProvider),
              const SizedBox(height: 20),
            ],
              
            // 结果统计
            _buildResultStats(huntingProvider),
            
            const SizedBox(height: 20),
            // 日志区域
            if (huntingProvider.logs.isNotEmpty) ...[
               _buildLogPanel(huntingProvider),
            ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogPanel(TicketHunterProvider provider) {
    return Card(
      color: Colors.black87,
      child: Container(
        padding: const EdgeInsets.all(12),
        height: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '运行日志',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: ListView.builder(
                itemCount: provider.logs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      provider.logs[index],
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformStats(ShowProvider showProvider) {
    final stats = showProvider.getPlatformStats();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '平台统计',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: TicketPlatform.values.map((platform) {
                final config = PlatformConfig.getConfig(platform);
                final count = stats[platform] ?? 0;
                
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getPlatformColor(platform).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getPlatformColor(platform).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          config.platformIcon,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          config.platformName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '$count 个',
                          style: TextStyle(
                            color: _getPlatformColor(platform),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickHuntingCard(
    Show show,
    List<Account> accounts,
    TicketHunterProvider huntingProvider,
  ) {
    final isHunting = huntingProvider.isHunting && 
                     huntingProvider.currentShow?.id == show.id;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 海报
                if (show.posterUrl != null && show.posterUrl!.isNotEmpty)
                  Container(
                    width: 60,
                    height: 80,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      image: DecorationImage(
                        image: NetworkImage(show.posterUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 60,
                    height: 80,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        show.platformIcon,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),

                // 信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        show.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        show.venue,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${show.showTime.year}.${show.showTime.month}.${show.showTime.day} ${show.showTime.hour}:${show.showTime.minute.toString().padLeft(2, '0')}',
                         style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getPlatformColor(show.platform).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              show.platformName,
                              style: TextStyle(
                                color: _getPlatformColor(show.platform),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${show.skus.length} 个票档',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 票档选择
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: show.skus.where((sku) => sku.isEnabled).map((sku) {
                return ActionChip(
                  label: Text('${sku.name} ¥${sku.price.toStringAsFixed(0)}'),
                  onPressed: isHunting ? null : () => _startQuickHunting(show, sku, accounts, huntingProvider),
                );
              }).toList(),
            ),
            
            if (isHunting || huntingProvider.status != TicketHunterStatus.idle && huntingProvider.currentShow?.id == show.id) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: huntingProvider.progress,
                backgroundColor: Colors.grey[300],
              ),
              const SizedBox(height: 8),
              Text(
                huntingProvider.statusMessage,
                style: TextStyle(
                  color: huntingProvider.status == TicketHunterStatus.error ? Colors.red : 
                         huntingProvider.status == TicketHunterStatus.success ? Colors.green : Colors.blue,
                  fontWeight: FontWeight.bold
                ),
              ),
              if (isHunting)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => huntingProvider.stopHunting(),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('停止'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBatchShowSelector(ShowProvider showProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择演出',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: showProvider.activeShows.length,
            itemBuilder: (context, index) {
              final show = showProvider.activeShows[index];
              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(show.platformIcon),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                show.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          show.venue,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Text(
                          '${show.skus.length} 个票档',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBatchAccountSelector(AccountProvider accountProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择账号 (${accountProvider.accounts.length} 个)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '将使用所有可用账号进行批量抢票',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildHuntingStatus(TicketHunterProvider huntingProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '抢票状态',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: huntingProvider.progress,
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(height: 8),
            Text(huntingProvider.status.toString()),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatusItem('尝试次数', huntingProvider.attemptCount.toString()),
                _buildStatusItem('成功次数', huntingProvider.successCount.toString()),
                _buildStatusItem('失败次数', huntingProvider.errorCount.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultStats(TicketHunterProvider huntingProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '抢票统计',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatItem('总尝试', huntingProvider.totalAttempts.toString(), Colors.blue),
                _buildStatItem('成功', huntingProvider.totalSuccesses.toString(), Colors.green),
                _buildStatItem('失败', huntingProvider.totalErrors.toString(), Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onAction,
            child: Text(actionText),
          ),
        ],
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

  void _startQuickHunting(
    Show show,
    TicketSku sku,
    List<Account> accounts,
    TicketHunterProvider huntingProvider,
  ) async {
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先添加账号')),
      );
      return;
    }

    await huntingProvider.startHunting(
      show: show,
      sku: sku,
      accounts: accounts,
      params: {
        'maxConcurrency': show.maxConcurrency,
        'retryCount': show.retryCount,
        'retryDelay': show.retryDelay.inMilliseconds,
      },
    );
  }

  void _startBatchHunting(
    ShowProvider showProvider,
    AccountProvider accountProvider,
    TicketHunterProvider huntingProvider,
  ) async {
    final shows = showProvider.activeShows;
    final accounts = accountProvider.accounts;

    if (shows.isEmpty || accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请确保有可用的演出和账号')),
      );
      return;
    }

    // TODO: 实现批量抢票逻辑
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('批量抢票功能开发中')),
    );
  }

  void _showHuntingHistory() {
    // TODO: 实现抢票历史界面
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('抢票历史功能开发中')),
    );
  }

  void _navigateToShowConfig() {
    DefaultTabController.of(context)?.animateTo(2);
  }

  void _navigateToAccountManagement() {
    DefaultTabController.of(context)?.animateTo(1);
  }
}