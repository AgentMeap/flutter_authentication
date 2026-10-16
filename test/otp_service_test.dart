import 'package:flutter_otp_demo/config/app_config.dart';
import 'package:flutter_otp_demo/services/otp_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const email = 'User@Example.com';

  String wrongCodeFor(String otp) => otp == '000000' ? '111111' : '000000';

  test('generate trả về mã toàn chữ số, đúng độ dài', () {
    final otp = OtpService().generate(email);
    expect(otp, matches(RegExp('^\\d{${AppConfig.otpLength}}\$')));
  });

  test('nhập đúng -> success, và mã chỉ dùng được một lần', () {
    final service = OtpService();
    final otp = service.generate(email);

    expect(service.verify(email, otp), OtpVerifyResult.success);
    expect(service.verify(email, otp), OtpVerifyResult.notFound);
  });

  test('email không phân biệt hoa/thường và khoảng trắng', () {
    final service = OtpService();
    final otp = service.generate(email);

    expect(service.verify('  user@example.com ', otp), OtpVerifyResult.success);
  });

  test('nhập sai -> wrong, đếm số lần thử còn lại', () {
    final service = OtpService();
    final otp = service.generate(email);

    expect(service.verify(email, wrongCodeFor(otp)), OtpVerifyResult.wrong);
    expect(service.attemptsLeft(email), AppConfig.maxOtpAttempts - 1);
  });

  test('sai quá số lần cho phép -> tooManyAttempts và mã bị huỷ', () {
    final service = OtpService();
    final otp = service.generate(email);
    final wrong = wrongCodeFor(otp);

    for (var i = 0; i < AppConfig.maxOtpAttempts - 1; i++) {
      expect(service.verify(email, wrong), OtpVerifyResult.wrong);
    }
    expect(service.verify(email, wrong), OtpVerifyResult.tooManyAttempts);
    // Mã đúng cũng không còn dùng được.
    expect(service.verify(email, otp), OtpVerifyResult.notFound);
  });

  test('hết hạn sau otpTtl', () {
    var now = DateTime(2026, 1, 1, 8);
    final service = OtpService(clock: () => now);
    final otp = service.generate(email);

    now = now.add(AppConfig.otpTtl + const Duration(seconds: 1));
    expect(service.verify(email, otp), OtpVerifyResult.expired);
  });

  test('cooldown gửi lại mã', () {
    var now = DateTime(2026, 1, 1, 8);
    final service = OtpService(clock: () => now);
    service.generate(email);

    expect(service.resendSecondsLeft(email), AppConfig.resendCooldown.inSeconds);

    now = now.add(AppConfig.resendCooldown);
    expect(service.resendSecondsLeft(email), 0);
  });

  test('generate lại sẽ vô hiệu hoá mã cũ', () {
    final service = OtpService();
    final first = service.generate(email);
    final second = service.generate(email);

    if (first != second) {
      expect(service.verify(email, first), OtpVerifyResult.wrong);
    }
    expect(service.verify(email, second), OtpVerifyResult.success);
  });
}
