/// Các hàm kiểm tra dữ liệu nhập vào form.
class Validators {
  Validators._();

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? name(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Vui lòng nhập họ tên';
    if (value.length < 2) return 'Họ tên quá ngắn';
    return null;
  }

  static String? email(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Vui lòng nhập email';
    if (!_emailRegex.hasMatch(value)) return 'Email không hợp lệ';
    return null;
  }

  /// Mật khẩu đăng ký: tối thiểu 8 ký tự, có cả chữ và số.
  static String? newPassword(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (value.length < 8) return 'Mật khẩu tối thiểu 8 ký tự';
    if (!RegExp(r'[A-Za-z]').hasMatch(value) || !RegExp(r'\d').hasMatch(value)) {
      return 'Mật khẩu phải có cả chữ và số';
    }
    return null;
  }

  static String? loginPassword(String? v) {
    if ((v ?? '').isEmpty) return 'Vui lòng nhập mật khẩu';
    return null;
  }
}
