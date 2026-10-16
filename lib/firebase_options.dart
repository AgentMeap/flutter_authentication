// FILE TẠM (placeholder).
//
// File này sẽ bị GHI ĐÈ khi bạn chạy lệnh:
//   flutterfire configure
//
// Trước khi chạy lệnh trên, app sẽ hiển thị màn hình hướng dẫn cấu hình Firebase.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Chưa cấu hình Firebase. Hãy chạy "flutterfire configure" '
      'để tạo file firebase_options.dart thật.',
    );
  }
}
