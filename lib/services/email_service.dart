import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../config/app_config.dart';

/// Gửi email chứa OTP qua Gmail SMTP.
///
/// Lưu ý: package `mailer` dùng socket nên chạy trên Android/iOS/desktop,
/// KHÔNG chạy trên Flutter Web.
class EmailService {
  EmailService();

  static final EmailService instance = EmailService();

  /// Trả về `true` nếu email đã được gửi thật.
  /// Trả về `false` nếu SMTP chưa cấu hình (chế độ dev: OTP in ra console).
  /// Ném exception nếu gửi thất bại.
  Future<bool> sendOtp({
    required String toEmail,
    required String name,
    required String otp,
  }) async {
    if (!AppConfig.smtpConfigured) {
      debugPrint('══════════ [DEV] SMTP chưa cấu hình ══════════');
      debugPrint('OTP gửi tới $toEmail: $otp');
      debugPrint('══════════════════════════════════════════════');
      return false;
    }

    final smtpServer = gmail(AppConfig.smtpUser, AppConfig.smtpAppPassword);
    final minutes = AppConfig.otpTtl.inMinutes;

    final message = Message()
      ..from = Address(AppConfig.smtpUser, AppConfig.senderName)
      ..recipients.add(toEmail.trim())
      ..subject = 'Mã xác thực OTP: $otp'
      ..text = 'Xin chào $name,\n\n'
          'Mã OTP của bạn là: $otp\n'
          'Mã có hiệu lực trong $minutes phút. Không chia sẻ mã này với bất kỳ ai.\n\n'
          'Nếu bạn không yêu cầu đăng ký, hãy bỏ qua email này.'
      ..html = '''
<div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;padding:24px;border:1px solid #e5e7eb;border-radius:12px">
  <h2 style="margin:0 0 8px;color:#111827">Xác thực email</h2>
  <p style="color:#374151">Xin chào <b>${_escape(name)}</b>,</p>
  <p style="color:#374151">Mã OTP để hoàn tất đăng ký của bạn:</p>
  <div style="font-size:32px;letter-spacing:10px;font-weight:bold;text-align:center;background:#f3f4f6;border-radius:8px;padding:16px;color:#111827">$otp</div>
  <p style="color:#6b7280;font-size:13px">Mã có hiệu lực trong $minutes phút. Không chia sẻ mã này với bất kỳ ai.</p>
  <p style="color:#6b7280;font-size:13px">Nếu bạn không yêu cầu đăng ký, hãy bỏ qua email này.</p>
</div>''';

    await send(message, smtpServer);
    return true;
  }

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
