import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/concert_provider.dart';
import '../models/concert.dart';
import '../utils/logger.dart';

class ConcertConfigScreen extends StatefulWidget {
  final Concert? concert;

  const ConcertConfigScreen({Key? key, this.concert}) : super(key: key);

  @override
  State<ConcertConfigScreen> createState() => _ConcertConfigScreenState();
}

class _ConcertConfigScreenState extends State<ConcertConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late TextEditingController _venueController;
  late TextEditingController _artistController;
  late DateTime _saleStartTime;
  late List<String> _targetPrices;
  late List<String> _targetSessions;
  late int _priority;
  late int _maxTickets;
  late bool _isEnabled;
  late bool _autoRefresh;
  late int _refreshInterval;
  late int _maxRetries;

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    final concert = widget.concert;
    _nameController = TextEditingController(text: concert?.name ?? '');
    _urlController = TextEditingController(text: concert?.url ?? '');
    _venueController = TextEditingController(text: concert?.venue ?? '');
    _artistController = TextEditingController(text: concert?.artist ?? '');
    _saleStartTime = concert?.saleStartTime ?? DateTime.now().add(const Duration(days: 1));
    _targetPrices = List.from(concert?.targetPrices ?? ['']);
    _targetSessions = List.from(concert?.targetSessions ?? ['']);
    _priority = concert?.priority ?? 5;
    _maxTickets = concert?.maxTickets ?? 2;
    _isEnabled = concert?.isEnabled ?? true;
    _autoRefresh = concert?.autoRefresh ?? true;
    _refreshInterval = concert?.refreshInterval ?? 1000;
    _maxRetries = concert?.maxRetries ?? 10;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _venueController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.concert != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑演唱会' : '添加演唱会'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveConcert,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildBasicInfoSection(),
            const SizedBox(height: 24),
            _buildTimeSection(),
            const SizedBox(height: 24),
            _buildTicketSection(),
            const SizedBox(height: 24),
            _buildAdvancedSection(),
            const SizedBox(height: 32),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '基本信息',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '演唱会名称 *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.music_note),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入演唱会名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _artistController,
              decoration: const InputDecoration(
                labelText: '艺人/乐队',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _venueController,
              decoration: const InputDecoration(
                labelText: '演出场馆',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: '演出链接 *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
                hintText: 'https://detail.damai.cn/item.htm?id=...',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入某卖链接';
                }
                if (!value.contains('damai.cn')) {
                  return '请输入有效的某卖链接';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '时间设置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('开售时间'),
              subtitle: Text(_formatDateTime(_saleStartTime)),
              trailing: const Icon(Icons.edit),
              onTap: _selectDateTime,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '票务设置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildPriceSection(),
            const SizedBox(height: 16),
            _buildSessionSection(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _maxTickets.toString(),
                    decoration: const InputDecoration(
                      labelText: '最大购票数量',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.confirmation_number),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _maxTickets = int.tryParse(value) ?? 2;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('优先级'),
                      Slider(
                        value: _priority.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: _priority.toString(),
                        onChanged: (value) {
                          setState(() {
                            _priority = value.round();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('目标价格', style: TextStyle(fontWeight: FontWeight.w500)),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                setState(() {
                  _targetPrices.add('');
                });
              },
            ),
          ],
        ),
        ..._targetPrices.asMap().entries.map((entry) {
          final index = entry.key;
          final price = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: price,
                    decoration: InputDecoration(
                      labelText: '价格 ${index + 1}',
                      border: const OutlineInputBorder(),
                      suffixText: '元',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _targetPrices[index] = value;
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _targetPrices.length > 1
                      ? () {
                          setState(() {
                            _targetPrices.removeAt(index);
                          });
                        }
                      : null,
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSessionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('目标场次', style: TextStyle(fontWeight: FontWeight.w500)),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                setState(() {
                  _targetSessions.add('');
                });
              },
            ),
          ],
        ),
        ..._targetSessions.asMap().entries.map((entry) {
          final index = entry.key;
          final session = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: session,
                    decoration: InputDecoration(
                      labelText: '场次 ${index + 1}',
                      border: const OutlineInputBorder(),
                      hintText: '例如：2024-03-15 19:30',
                    ),
                    onChanged: (value) {
                      _targetSessions[index] = value;
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _targetSessions.length > 1
                      ? () {
                          setState(() {
                            _targetSessions.removeAt(index);
                          });
                        }
                      : null,
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildAdvancedSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '高级设置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('启用抢票'),
              subtitle: const Text('是否启用此演唱会的抢票功能'),
              value: _isEnabled,
              onChanged: (value) {
                setState(() {
                  _isEnabled = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('自动刷新'),
              subtitle: const Text('开售前自动刷新页面'),
              value: _autoRefresh,
              onChanged: (value) {
                setState(() {
                  _autoRefresh = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _refreshInterval.toString(),
                    decoration: const InputDecoration(
                      labelText: '刷新间隔 (毫秒)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _refreshInterval = int.tryParse(value) ?? 1000;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _maxRetries.toString(),
                    decoration: const InputDecoration(
                      labelText: '最大重试次数',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _maxRetries = int.tryParse(value) ?? 10;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _saveConcert,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
            child: Text(widget.concert != null ? '保存' : '添加'),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _saleStartTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_saleStartTime),
      );

      if (time != null) {
        setState(() {
          _saleStartTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _saveConcert() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 过滤空的价格和场次
    final filteredPrices = _targetPrices.where((p) => p.isNotEmpty).toList();
    final filteredSessions = _targetSessions.where((s) => s.isNotEmpty).toList();

    if (filteredPrices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加一个目标价格')),
      );
      return;
    }

    try {
      // 从 URL 提取 itemId
      String itemId = '';
      if (_urlController.text.contains('id=')) {
        final uri = Uri.parse(_urlController.text);
        itemId = uri.queryParameters['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      } else if (_urlController.text.contains('item.htm')) {
        final match = RegExp(r'/(\d+)').firstMatch(_urlController.text);
        itemId = match?.group(1) ?? DateTime.now().millisecondsSinceEpoch.toString();
      } else {
        itemId = DateTime.now().millisecondsSinceEpoch.toString();
      }

      final concert = Concert(
        id: widget.concert?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        url: _urlController.text,
        venue: _venueController.text,
        artist: _artistController.text.isEmpty ? null : _artistController.text,
        saleStartTime: _saleStartTime,
        itemId: itemId,
        targetPrices: filteredPrices,
        targetSessions: filteredSessions,
        priority: _priority,
        maxTickets: _maxTickets,
        isEnabled: _isEnabled,
        autoRefresh: _autoRefresh,
        refreshInterval: _refreshInterval,
        maxRetries: _maxRetries,
      );

      if (widget.concert != null) {
        context.read<ConcertProvider>().updateConcert(concert);
      } else {
        context.read<ConcertProvider>().addConcert(concert);
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.concert != null ? '演唱会更新成功' : '演唱会添加成功'),
        ),
      );
    } catch (e) {
      AppLogger.error('Save concert failed', e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败，请重试')),
      );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-'
           '${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}