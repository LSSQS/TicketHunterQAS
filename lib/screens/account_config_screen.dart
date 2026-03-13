import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../models/account.dart';
import '../utils/logger.dart';

class AccountConfigScreen extends StatefulWidget {
  const AccountConfigScreen({Key? key}) : super(key: key);

  @override
  State<AccountConfigScreen> createState() => _AccountConfigScreenState();
}

class _AccountConfigScreenState extends State<AccountConfigScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账号管理'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddAccountDialog(),
          ),
        ],
      ),
      body: Consumer<AccountProvider>(
        builder: (context, provider, child) {
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
            Icons.account_circle,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无账号配置',
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
        ],
      ),
    );
  }

  Widget _buildAccountCard(Account account) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    account.username.isNotEmpty ? account.username[0].toUpperCase() : 'U',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.bold,
                    ),
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
                        account.phone ?? '未设置手机号',
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
                    color: account.isEnabled ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    account.isEnabled ? '启用' : '禁用',
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
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${account.province ?? ""} ${account.city ?? ""}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.priority_high, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '优先级: ${account.priority}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            if (account.cookies != null && account.cookies!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.cookie, size: 16, color: Colors.green[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Cookie已配置',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[600],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _testAccount(account),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('测试'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _editAccount(account),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('编辑'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _deleteAccount(account),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('删除'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAccountDialog() {
    _showAccountDialog();
  }

  void _editAccount(Account account) {
    _showAccountDialog(account: account);
  }

  void _showAccountDialog({Account? account}) {
    final isEditing = account != null;
    final usernameController = TextEditingController(text: account?.username ?? '');
    final passwordController = TextEditingController(text: account?.password ?? '');
    final phoneController = TextEditingController(text: account?.phone ?? '');
    final provinceController = TextEditingController(text: account?.province ?? '');
    final cityController = TextEditingController(text: account?.city ?? '');
    // cookies 是 Map，需要转换为字符串显示
    String cookiesStr = '';
    if (account?.cookies != null) {
      try {
        cookiesStr = account!.cookies!.entries.map((e) => '${e.key}=${e.value}').join('; ');
      } catch (_) {}
    }
    final cookiesController = TextEditingController(text: cookiesStr);
    int priority = account?.priority ?? 1;
    bool isEnabled = account?.isEnabled ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? '编辑账号' : '添加账号'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: '手机号',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: provinceController,
                        decoration: const InputDecoration(
                          labelText: '省份',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: cityController,
                        decoration: const InputDecoration(
                          labelText: '城市',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cookiesController,
                  decoration: const InputDecoration(
                    labelText: 'Cookies (可选)',
                    border: OutlineInputBorder(),
                    hintText: '从浏览器复制的Cookie字符串',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('优先级: '),
                    Expanded(
                      child: Slider(
                        value: priority.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: priority.toString(),
                        onChanged: (value) {
                          setState(() {
                            priority = value.round();
                          });
                        },
                      ),
                    ),
                    Text(priority.toString()),
                  ],
                ),
                Row(
                  children: [
                    const Text('启用账号'),
                    const Spacer(),
                    Switch(
                      value: isEnabled,
                      onChanged: (value) {
                        setState(() {
                          isEnabled = value;
                        });
                      },
                    ),
                  ],
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
              onPressed: () => _saveAccount(
                context,
                isEditing,
                account?.id,
                usernameController.text,
                passwordController.text,
                phoneController.text,
                provinceController.text,
                cityController.text,
                cookiesController.text,
                priority,
                isEnabled,
              ),
              child: Text(isEditing ? '保存' : '添加'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveAccount(
    BuildContext context,
    bool isEditing,
    String? accountId,
    String username,
    String password,
    String phone,
    String province,
    String city,
    String cookies,
    int priority,
    bool isEnabled,
  ) {
    if (username.isEmpty || password.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写必要信息')),
      );
      return;
    }

    try {
      // 将 cookies 字符串转换为 Map
      Map<String, dynamic>? cookiesMap;
      if (cookies.isNotEmpty) {
        cookiesMap = {};
        final pairs = cookies.split(';');
        for (var pair in pairs) {
          final trimmed = pair.trim();
          if (trimmed.contains('=')) {
            final parts = trimmed.split('=');
            if (parts.length >= 2) {
              cookiesMap[parts[0].trim()] = parts.sublist(1).join('=').trim();
            }
          }
        }
      }

      final account = Account(
        id: accountId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        username: username,
        password: password,
        phone: phone,
        province: province.isEmpty ? null : province,
        city: city.isEmpty ? null : city,
        cookies: cookiesMap,
        priority: priority,
        isEnabled: isEnabled,
      );

      if (isEditing) {
        context.read<AccountProvider>().updateAccount(account);
      } else {
        context.read<AccountProvider>().addAccount(account);
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEditing ? '账号更新成功' : '账号添加成功')),
      );
    } catch (e) {
      AppLogger.error('Save account failed', e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败，请重试')),
      );
    }
  }

  void _testAccount(Account account) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在测试账号...'),
          ],
        ),
      ),
    );

    try {
      final result = await context.read<AccountProvider>().verifyAccount(account);
      Navigator.pop(context); // 关闭加载对话框

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(result ? '测试成功' : '测试失败'),
          content: Text(result ? '账号登录正常' : '账号登录失败，请检查用户名和密码'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.pop(context); // 关闭加载对话框
      AppLogger.error('Test account failed', e);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('测试失败'),
          content: Text('测试过程中发生错误: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('账号删除成功')),
              );
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}