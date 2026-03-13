import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/show_provider.dart';
import '../models/show.dart';
import '../models/platform_config.dart';
import 'show_search_screen.dart';

class ShowConfigScreen extends StatefulWidget {
  final Show? show;

  const ShowConfigScreen({super.key, this.show});

  @override
  State<ShowConfigScreen> createState() => _ShowConfigScreenState();
}

class _ShowConfigScreenState extends State<ShowConfigScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShowProvider>().loadShows();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('演出配置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _navigateToSearch,
            tooltip: '搜索演出',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddShowDialog,
            tooltip: '手动添加',
          ),
        ],
      ),
      body: Consumer<ShowProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.shows.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.shows.length,
            itemBuilder: (context, index) {
              final show = provider.shows[index];
              return _buildShowCard(show);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无演出配置',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '可以从平台搜索或手动添加演出',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToSearch,
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
            onPressed: _showAddShowDialog,
            icon: const Icon(Icons.add),
            label: const Text('手动添加'),
          ),
        ],
      ),
    );
  }

  Widget _buildShowCard(Show show) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    show.statusText,
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
              '开售时间: ${_formatDateTime(show.saleStartTime)}',
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-'
           '${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _navigateToSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ShowSearchScreen()),
    );
  }

  void _showAddShowDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddShowDialog(),
    );
  }

  void _editShow(Show show) {
    showDialog(
      context: context,
      builder: (context) => _AddShowDialog(show: show),
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

class _AddShowDialog extends StatefulWidget {
  final Show? show;

  const _AddShowDialog({this.show});

  @override
  State<_AddShowDialog> createState() => _AddShowDialogState();
}

class _AddShowDialogState extends State<_AddShowDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _venueController = TextEditingController();
  final _itemIdController = TextEditingController();
  TicketPlatform _selectedPlatform = TicketPlatform.damai;
  ShowType _selectedType = ShowType.concert;
  DateTime _showTime = DateTime.now().add(const Duration(days: 30));
  DateTime _saleStartTime = DateTime.now().add(const Duration(days: 1));

  List<TicketSku> _skus = [];
  
  @override
  void initState() {
    super.initState();
    if (widget.show != null) {
      _nameController.text = widget.show!.name;
      _venueController.text = widget.show!.venue;
      _itemIdController.text = widget.show!.itemId;
      _selectedPlatform = widget.show!.platform;
      _selectedType = widget.show!.type;
      _showTime = widget.show!.showTime;
      _saleStartTime = widget.show!.saleStartTime;
      _skus = List.from(widget.show!.skus);
    } else {
      // 默认添加一个 SKU
      _skus = [
        TicketSku(
          skuId: 'default',
          name: '默认票档',
          price: 0.0,
          priority: TicketPriority.high,
        )
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.show == null ? '添加演出' : '编辑演出'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<TicketPlatform>(
                value: _selectedPlatform,
                decoration: const InputDecoration(labelText: '平台'),
                items: TicketPlatform.values.map((platform) {
                  final config = PlatformConfig.getConfig(platform);
                  return DropdownMenuItem(
                    value: platform,
                    child: Row(
                      children: [
                        Text(config.platformIcon),
                        const SizedBox(width: 8),
                        Text(config.platformName),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPlatform = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ShowType>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: '类型'),
                items: ShowType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_getTypeText(type)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '演出名称'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入演出名称';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _venueController,
                decoration: const InputDecoration(labelText: '场馆/影院'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入场馆或影院';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _itemIdController,
                decoration: const InputDecoration(labelText: '商品ID'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入商品ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('票档配置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _addSku,
                  ),
                ],
              ),
              ..._skus.asMap().entries.map((entry) {
                final index = entry.key;
                final sku = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: sku.name,
                                decoration: const InputDecoration(labelText: '票档名称'),
                                onChanged: (val) {
                                  setState(() {
                                    _skus[index] = TicketSku(
                                      skuId: sku.skuId,
                                      name: val,
                                      price: sku.price,
                                      priority: sku.priority,
                                      isEnabled: sku.isEnabled
                                    );
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                initialValue: sku.price.toString(),
                                decoration: const InputDecoration(labelText: '价格'),
                                keyboardType: TextInputType.number,
                                onChanged: (val) {
                                  setState(() {
                                    _skus[index] = TicketSku(
                                      skuId: sku.skuId,
                                      name: sku.name,
                                      price: double.tryParse(val) ?? 0.0,
                                      priority: sku.priority,
                                      isEnabled: sku.isEnabled
                                    );
                                  });
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeSku(index),
                            ),
                          ],
                        ),
                        TextFormField(
                          initialValue: sku.skuId,
                          decoration: const InputDecoration(labelText: 'SKU ID'),
                          onChanged: (val) {
                            setState(() {
                              _skus[index] = TicketSku(
                                skuId: val,
                                name: sku.name,
                                price: sku.price,
                                priority: sku.priority,
                                isEnabled: sku.isEnabled
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _saveShow,
          child: Text(widget.show == null ? '添加' : '保存'),
        ),
      ],
    );
  }

  void _addSku() {
    setState(() {
      _skus.add(TicketSku(
        skuId: '',
        name: '',
        price: 0.0,
        priority: TicketPriority.high,
      ));
    });
  }

  void _removeSku(int index) {
    setState(() {
      _skus.removeAt(index);
    });
  }

  String _getTypeText(ShowType type) {
    switch (type) {
      case ShowType.concert:
        return '演唱会';
      case ShowType.drama:
        return '话剧';
      case ShowType.movie:
        return '电影';
      case ShowType.sports:
        return '体育赛事';
      case ShowType.other:
        return '其他';
    }
  }

  void _saveShow() {
    if (_formKey.currentState!.validate()) {
      final now = DateTime.now();
      final show = Show(
        id: widget.show?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        venue: _venueController.text,
        itemId: _itemIdController.text,
        platform: _selectedPlatform,
        type: _selectedType,
        showTime: _showTime,
        saleStartTime: _saleStartTime,
        skus: _skus,
        createdAt: widget.show?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.show == null) {
        context.read<ShowProvider>().addShow(show);
      } else {
        context.read<ShowProvider>().updateShow(show);
      }

      Navigator.pop(context);
    }
  }
}