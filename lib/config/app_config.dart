/// Cấu hình chung của app demo.
///
/// LƯU Ý: Thông tin SMTP đặt trong app chỉ phù hợp để DEMO.
/// Với sản phẩm thật, hãy gửi OTP từ server (Cloud Functions, backend riêng...).
class AppConfig {
  AppConfig._();

  // ---- Gmail SMTP (dùng "Mật khẩu ứng dụng" / App Password, KHÔNG dùng mật khẩu Gmail) ----
  static const String smtpUser = 'xxx';
  static const String smtpAppPassword = 'xxx';
  static const String senderName = 'Flutter OTP Demo';

  // ---- Quy tắc OTP ----
  static const int otpLength = 6;
  static const Duration otpTtl = Duration(minutes: 5);
  static const Duration resendCooldown = Duration(seconds: 60);
  static const int maxOtpAttempts = 5;

  /// true nếu đã điền thông tin SMTP thật.
  static bool get smtpConfigured =>
      smtpUser != 'YOUR_GMAIL@gmail.com' && !smtpAppPassword.startsWith('xxxx');
}
