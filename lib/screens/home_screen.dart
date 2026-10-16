import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static String _providerLabel(String id) {
    switch (id) {
      case 'google.com':
        return 'Google';
      case 'password':
        return 'Email / Mật khẩu';
      default:
        return id;
    }
  }

  static String _formatTime(dynamic value) {
    if (value is! Timestamp) return '—';
    final d = value.toDate().toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AuthService.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final name = (user.displayName?.trim().isNotEmpty ?? false) ? user.displayName! : 'Người dùng';
    final providers = user.providerData.map((p) => _providerLabel(p.providerId)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService.instance.signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- Thông tin tài khoản ----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                    child: user.photoURL == null
                        ? Text(
                            name.substring(0, 1).toUpperCase(),
                            style: theme.textTheme.headlineMedium,
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Xin chào, $name!',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(user.email ?? ''),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final p in providers)
                        Chip(
                          avatar: const Icon(Icons.verified_user_outlined, size: 18),
                          label: Text(p),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ---- Dữ liệu lưu trên Firestore ----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: AuthService.instance.userDocStream(user.uid),
                builder: (context, snap) {
                  final data = snap.data?.data();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.cloud_done_outlined, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Hồ sơ lưu trên Firestore',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      if (snap.hasError)
                        Text(
                          AuthService.friendlyError(snap.error!),
                          style: TextStyle(color: theme.colorScheme.error),
                        )
                      else if (data == null)
                        const Text('Đang tải...')
                      else ...[
                        _InfoRow(label: 'UID', value: user.uid),
                        _InfoRow(label: 'Tạo lúc', value: _formatTime(data['createdAt'])),
                        _InfoRow(label: 'Đăng nhập gần nhất', value: _formatTime(data['lastLoginAt'])),
                        _InfoRow(
                          label: 'Phương thức',
                          value: ((data['providers'] as List?) ?? const [])
                              .map((e) => _providerLabel('$e'))
                              .join(', '),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ---- Tóm tắt 2 phương thức bảo mật ----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security_outlined, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '2 phương thức bảo mật được demo',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const _Bullet(
                    title: 'OTP qua email khi đăng ký',
                    body: 'Xác minh quyền sở hữu email: mã 6 số, hết hạn 5 phút, '
                        'giới hạn 5 lần nhập sai, chỉ dùng 1 lần. Tài khoản chỉ được tạo sau khi OTP đúng.',
                  ),
                  const SizedBox(height: 12),
                  const _Bullet(
                    title: 'Đăng nhập Google qua Firebase',
                    body: 'Ủy quyền cho Google (OAuth 2.0) xác thực danh tính — '
                        'app không bao giờ nhận hay lưu mật khẩu Google của người dùng.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => AuthService.instance.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(body),
      ],
    );
  }
}
