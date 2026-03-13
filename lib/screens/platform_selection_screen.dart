import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/platform_config.dart';
import '../providers/show_provider.dart';

/// 平台选择界面
class PlatformSelectionScreen extends StatelessWidget {
  const PlatformSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择抢票平台'),
        elevation: 0,
      ),
      body: Consumer<ShowProvider>(
        builder: (context, showProvider, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '支持的平台',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '选择您要使用的抢票平台',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView.builder(
                    itemCount: TicketPlatform.values.length,
                    itemBuilder: (context, index) {
                      final platform = TicketPlatform.values[index];
                      final config = PlatformConfig.getConfig(platform);
                      final isSelected = showProvider.selectedPlatform == platform;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: isSelected ? 8 : 2,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context, platform);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border.all(
                                      color: Theme.of(context).primaryColor,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: _getPlatformColor(platform).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      config.platformIcon,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            config.platformName,
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (isSelected) ...[
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.check_circle,
                                              color: Theme.of(context).primaryColor,
                                              size: 20,
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _getPlatformDescription(platform),
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: config.isEnabled ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: config.isEnabled ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          config.isEnabled ? '可用' : '维护中',
                                          style: TextStyle(
                                            color: config.isEnabled ? Colors.green : Colors.orange,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.grey[400],
                                  size: 16,
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
            ),
          );
        },
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

  String _getPlatformDescription(TicketPlatform platform) {
    switch (platform) {
      case TicketPlatform.damai:
        return '演唱会、话剧、体育赛事等';
      case TicketPlatform.maoyan:
        return '电影票、演出票等';
      case TicketPlatform.xiudong:
        return '演唱会、音乐节等';
    }
  }
}
