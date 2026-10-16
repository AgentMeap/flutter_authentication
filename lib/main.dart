import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? initError;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    initError = e;
  }

  runApp(MyApp(initError: initError));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.initError});

  final Object? initError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OTP & Google Sign-In Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5)),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        ),
      ),
      home: initError != null ? SetupErrorScreen(error: initError!) : const AuthGate(),
    );
  }
}

/// Quyết định hiển thị Login hay Home theo trạng thái đăng nhập Firebase.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        // Đang đăng ký: giữ nguyên màn Login (Firebase tự đăng nhập sau khi tạo user,
        // nhưng ta muốn người dùng đăng nhập lại bằng email/mật khẩu).
        if (snapshot.hasData && !AuthService.instance.isRegistering) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class SetupErrorScreen extends StatelessWidget {
  const SetupErrorScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Chưa cấu hình Firebase')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.settings_suggest_outlined, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('Cần cấu hình Firebase trước khi chạy', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          const Text(
            '1. Tạo project trên Firebase Console\n'
            '2. Chạy: dart pub global activate flutterfire_cli\n'
            '3. Chạy: flutterfire configure\n'
            '4. Chạy lại app\n\n'
            'Xem README.md để biết chi tiết.',
          ),
          const SizedBox(height: 24),
          Text('Chi tiết lỗi:', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SelectableText('$error', style: TextStyle(color: theme.colorScheme.error)),
        ],
      ),
    );
  }
}
