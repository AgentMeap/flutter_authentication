import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../config/app_config.dart';

enum OtpVerifyResult { success, wrong, expired, tooManyAttempts, notFound }

class _OtpEntry {
  _OtpEntry({
    required this.hash,
    required this.salt,
    required this.sentAt,
    required this.expiresAt,
  });

  final String hash;
  final String salt;
  final DateTime sentAt;
  final DateTime expiresAt;
  int attempts = 0;
}

/// Sinh và xác thực OTP.
///
/// - OTP 6 chữ số sinh bằng bộ random an toàn (Random.secure).
/// - Chỉ lưu bản BĂM (SHA-256 + salt), không lưu OTP gốc.
/// - Hết hạn sau [AppConfig.otpTtl], giới hạn [AppConfig.maxOtpAttempts] lần nhập sai.
/// - Mỗi mã chỉ dùng được 1 lần.
///
/// DEMO: dữ liệu giữ trong bộ nhớ của app. Production nên làm ở server.
class OtpService {
  OtpService({DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  static final OtpService instance = OtpService();

  final DateTime Function() _now;
  final Random _rng = Random.secure();
  final Map<String, _OtpEntry> _store = {};

  String _key(String email) => email.trim().toLowerCase();

  String _hash(String salt, String key, String code) =>
      sha256.convert(utf8.encode('$salt:$key:$code')).toString();

  /// Tạo OTP mới cho [email] (ghi đè mã cũ) và trả về mã gốc để gửi đi.
  String generate(String email) {
    final key = _key(email);
    final otp = List.generate(AppConfig.otpLength, (_) => _rng.nextInt(10)).join();
    final salt = base64UrlEncode(List.generate(16, (_) => _rng.nextInt(256)));
    final now = _now();
    _store[key] = _OtpEntry(
      hash: _hash(salt, key, otp),
      salt: salt,
      sentAt: now,
      expiresAt: now.add(AppConfig.otpTtl),
    );
    return otp;
  }

  /// Số giây còn lại trước khi được phép gửi lại mã.
  int resendSecondsLeft(String email) {
    final entry = _store[_key(email)];
    if (entry == null) return 0;
    final remaining =
        AppConfig.resendCooldown - _now().difference(entry.sentAt);
    if (remaining.isNegative) return 0;
    return (remaining.inMilliseconds / 1000).ceil();
  }

  /// Số lần thử còn lại của mã hiện tại.
  int attemptsLeft(String email) {
    final entry = _store[_key(email)];
    if (entry == null) return 0;
    return max(0, AppConfig.maxOtpAttempts - entry.attempts);
  }

  OtpVerifyResult verify(String email, String code) {
    final key = _key(email);
    final entry = _store[key];
    if (entry == null) return OtpVerifyResult.notFound;

    if (_now().isAfter(entry.expiresAt)) {
      _store.remove(key);
      return OtpVerifyResult.expired;
    }

    entry.attempts++;
    if (_hash(entry.salt, key, code.trim()) == entry.hash) {
      _store.remove(key); // dùng 1 lần
      return OtpVerifyResult.success;
    }

    if (entry.attempts >= AppConfig.maxOtpAttempts) {
      _store.remove(key);
      return OtpVerifyResult.tooManyAttempts;
    }
    return OtpVerifyResult.wrong;
  }

  void clear(String email) => _store.remove(_key(email));
}
