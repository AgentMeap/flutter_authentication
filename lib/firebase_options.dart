// Cấu hình Firebase cho project `test-fb345`.
//
// Giá trị lấy từ android/app/google-services.json.
// Có thể sinh lại tự động bằng lệnh: flutterfire configure
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Chưa cấu hình Firebase cho Web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Chưa cấu hình Firebase cho $defaultTargetPlatform. '
          'Hãy chạy "flutterfire configure" và chọn thêm nền tảng này.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB0AKm84MfP-iqcbcuo4edREBi4AlEC0Y4',
    appId: '1:647928369508:android:8de561d6764ab434c22a71',
    messagingSenderId: '647928369508',
    projectId: 'test-fb345',
    storageBucket: 'test-fb345.firebasestorage.app',
  );
}
