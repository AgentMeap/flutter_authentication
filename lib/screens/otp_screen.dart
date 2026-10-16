import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../services/email_service.dart';
import '../services/otp_service.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.name,
    required this.email,
    required this.password,
    required this.devMode,
  });

  final String name;
  final String email;
  final String password;

  /// true nếu SMTP chưa cấu hình -> OTP chỉ in ra console.
  final bool devMode;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _codeCtrl = TextEditingController();
  Timer? _timer;

  int _cooldown = 0;
  bool _verifying = false;
  bool _resending = false;
  late bool _devMode;
  String? _error;

  bool get _busy => _verifying || _resending;

  @override
  void initState() {
    super.initState();
    _devMode = widget.devMode;
    _cooldown = OtpService.instance.resendSecondsLeft(widget.email);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = OtpService.instance.resendSecondsLeft(widget.email);
      if (mounted && left != _cooldown) setState(() => _cooldown = left);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.length != AppConfig.otpLength) {
      setState(() => _error = 'Vui lòng nhập đủ ${AppConfig.otpLength} chữ số.');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    final result = OtpService.instance.verify(widget.email, code);

    if (result == OtpVerifyResult.success) {
      try {
        // OTP đúng -> mới tạo tài khoản trên Firebase.
        await AuthService.instance.registerWithEmail(
          name: widget.name,
          email: widget.email,
          password: widget.password,
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _verifying = false;
          _error = '${AuthService.friendlyError(e)} Hãy gửi lại mã để thử lại.';
        });
      }
      return;
    }

    final message = switch (result) {
      OtpVerifyResult.wrong =>
        'Mã OTP không đúng. Bạn còn ${OtpService.instance.attemptsLeft(widget.email)} lần thử.',
      OtpVerifyResult.expired => 'Mã OTP đã hết hạn. Hãy gửi lại mã mới.',
      OtpVerifyResult.tooManyAttempts => 'Bạn đã nhập sai quá nhiều lần. Hãy gửi lại mã mới.',
      OtpVerifyResult.notFound => 'Chưa có mã OTP. Hãy gửi lại mã.',
      OtpVerifyResult.success => null,
    };

    setState(() {
      _verifying = false;
      _error = message;
    });
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final otp = OtpService.instance.generate(widget.email);
      final delivered = await EmailService.instance.sendOtp(
        toEmail: widget.email,
        name: widget.name,
        otp: otp,
      );
      if (!mounted) return;
      _codeCtrl.clear();
      setState(() {
        _devMode = !delivered;
        _cooldown = OtpService.instance.resendSecondsLeft(widget.email);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi lại mã OTP.')),
      );
    } catch (e) {
      OtpService.instance.clear(widget.email);
      if (!mounted) return;
      setState(() => _error = 'Không gửi được email OTP: $e');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Xác thực OTP')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.mark_email_read_outlined, size: 72, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Kiểm tra email của bạn',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      text: 'Mã gồm ${AppConfig.otpLength} chữ số đã được gửi đến\n',
                      children: [
                        TextSpan(
                          text: widget.email,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: '\nMã có hiệu lực trong ${AppConfig.otpTtl.inMinutes} phút.'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_devMode) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: theme.colorScheme.tertiaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Chế độ dev: SMTP chưa được cấu hình nên email KHÔNG được gửi. '
                          'Xem mã OTP trong Debug Console / logcat.',
                          style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextField(
                    controller: _codeCtrl,
                    enabled: !_busy,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: AppConfig.otpLength,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: theme.textTheme.headlineMedium?.copyWith(
                      letterSpacing: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(hintText: '••••••', counterText: ''),
                    onSubmitted: (_) => _busy ? null : _verify(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _verify,
                    child: _verifying
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Xác nhận'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: (_busy || _cooldown > 0) ? null : _resend,
                    child: Text(
                      _resending
                          ? 'Đang gửi...'
                          : _cooldown > 0
                              ? 'Gửi lại mã sau ${_cooldown}s'
                              : 'Gửi lại mã',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
