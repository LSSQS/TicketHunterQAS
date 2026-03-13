import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../models/account.dart';
import '../models/platform_config.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() => _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountProvider>().loadAccounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账号管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddAccountDialog,
          ),
        ],
      ),
      body: Consumer<AccountProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.accounts.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.accounts.length,
            itemBuilder: (context, index) {
              final account = provider.accounts[index];
              return _buildAccountCard(account);
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
            Icons.account_circle_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无账号',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角按钮添加账号',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _showAddAccountDialog,
            child: const Text('添加账号'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(Account account) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getStatusColor(account.status),
                  child: Text(
                    PlatformConfig.getConfig(account.platform).platformIcon,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.username,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        account.phone ?? account.email ?? '未设置联系方式',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(account.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    account.statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoItem('设备ID', account.deviceId.substring(0, 8)),
                _buildInfoItem('登录失败', '${account.loginFailCount}次'),
                _buildInfoItem(
                  '最后登录',
                  account.lastLoginTime != null
                      ? _formatDateTime(account.lastLoginTime!)
                      : '从未',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _editAccount(account),
                  child: const Text('编辑'),
                ),
                TextButton(
                  onPressed: () => _testAccount(account),
                  child: const Text('测试'),
                ),
                TextButton(
                  onPressed: () => _deleteAccount(account),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(AccountStatus status) {
    switch (status) {
      case AccountStatus.active:
        return Colors.green;
      case AccountStatus.inactive:
        return Colors.grey;
      case AccountStatus.banned:
        return Colors.red;
      case AccountStatus.error:
        return Colors.orange;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}-${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showAddAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddAccountDialog(),
    );
  }

  void _editAccount(Account account) {
    showDialog(
      context: context,
      builder: (context) => _AddAccountDialog(account: account),
    );
  }

  void _testAccount(Account account) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在测试账号 ${account.username}...')),
    );
    
    final isValid = await context.read<AccountProvider>().verifyAccount(account);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isValid ? '账号验证成功' : '账号验证失败'),
          backgroundColor: isValid ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _deleteAccount(Account account) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除账号 "${account.username}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<AccountProvider>().removeAccount(account.id);
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _AddAccountDialog extends StatefulWidget {
  final Account? account;

  const _AddAccountDialog({this.account});

  @override
  State<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<_AddAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  TicketPlatform _selectedPlatform = TicketPlatform.damai;

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      _usernameController.text = widget.account!.username;
      _passwordController.text = widget.account!.password;
      _phoneController.text = widget.account!.phone ?? '';
      _emailController.text = widget.account!.email ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.account == null ? '添加账号' : '编辑账号'),
      content: Form(
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
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: '用户名'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入用户名';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: '密码'),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入密码';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: '手机号（可选）'),
            ),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: '邮箱（可选）'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _saveAccount,
          child: Text(widget.account == null ? '添加' : '保存'),
        ),
      ],
    );
  }

  void _saveAccount() {
    if (_formKey.currentState!.validate()) {
      final now = DateTime.now();
      final account = Account(
        id: widget.account?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        username: _usernameController.text,
        password: _passwordController.text,
        phone: _phoneController.text.isEmpty ? null : _phoneController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        deviceId: widget.account?.deviceId ?? 'device_${DateTime.now().millisecondsSinceEpoch}',
        createdAt: widget.account?.createdAt ?? now,
        updatedAt: now,
        platform: _selectedPlatform,
      );

      if (widget.account == null) {
        context.read<AccountProvider>().addAccount(account);
      } else {
        context.read<AccountProvider>().updateAccount(account);
      }

      Navigator.pop(context);
    }
  }
}