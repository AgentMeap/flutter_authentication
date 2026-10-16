# Flutter OTP & Google Sign-In Demo

> 📖 **Hướng dẫn từng bước (có ảnh):** https://agentmeap.github.io/flutter_authentication/

Project demo **2 phương thức bảo mật tài khoản**:

1. **OTP qua email khi đăng ký** – xác minh quyền sở hữu email trước khi tạo tài khoản.
2. **Đăng nhập bằng Google qua Firebase** – ủy quyền OAuth 2.0, lưu hồ sơ lên Firestore.

## Luồng hoạt động

```
ĐĂNG KÝ
 Nhập tên + email + mật khẩu
   └─► Kiểm tra email đã có trên Firebase chưa (Firestore: registered_emails)
         ├─ Có rồi  ─► báo lỗi, yêu cầu đăng nhập
         └─ Chưa có ─► sinh OTP 6 số ─► gửi về email (SMTP)
                          └─► Nhập OTP
                                ├─ Sai / hết hạn ─► báo lỗi, cho gửi lại
                                └─ Đúng ─► tạo tài khoản Firebase Auth
                                           + lưu users/{uid}
                                           ─► quay về Đăng nhập (email + mật khẩu)

ĐĂNG NHẬP
 ├─ Email + mật khẩu  (Firebase Auth)
 └─ Google            (google_sign_in ─► Firebase Auth ─► lưu users/{uid})
```

## Cấu trúc

```
lib/
├── main.dart                    # khởi tạo Firebase, AuthGate (Login ↔ Home)
├── firebase_options.dart        # placeholder – bị ghi đè bởi `flutterfire configure`
├── config/app_config.dart       # cấu hình SMTP + quy tắc OTP
├── services/
│   ├── auth_service.dart        # Firebase Auth + Firestore + Google Sign-In
│   ├── otp_service.dart         # sinh/băm/xác thực OTP (hết hạn, giới hạn lần thử)
│   └── email_service.dart       # gửi OTP qua Gmail SMTP
├── screens/
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── otp_screen.dart
│   └── home_screen.dart
└── utils/validators.dart
test/otp_service_test.dart       # unit test cho logic OTP
firestore.rules                  # Firestore Security Rules
```

## Cài đặt

### 1. Sinh thư mục nền tảng (android/ios)

Trong thư mục project:

```bash
flutter create . --project-name flutter_otp_demo --platforms=android,ios
flutter pub get
```

> `flutter create .` **không ghi đè** `pubspec.yaml` và `lib/` đã có.
> Nếu gặp lỗi build Android liên quan `minSdk`, đặt `minSdk = 23` trong `android/app/build.gradle(.kts)`.

### 2. Tạo project Firebase

1. Vào [Firebase Console](https://console.firebase.google.com) → **Add project**.
2. **Authentication → Sign-in method**: bật **Email/Password** và **Google** (chọn support email).
3. **Firestore Database → Create database** (chọn location gần nhất).
4. Tab **Rules** của Firestore: dán nội dung file `firestore.rules` → **Publish**.

### 3. Kết nối app với Firebase

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Chọn project vừa tạo và các nền tảng android/ios. Lệnh này sinh `lib/firebase_options.dart` thật.

### 4. Cấu hình Google Sign-In

**Android** – thêm SHA-1 (và SHA-256) của debug keystore:

```bash
cd android && ./gradlew signingReport
```

Copy SHA-1 của biến thể `debug` → Firebase Console → **Project settings → Your apps (Android) → Add fingerprint**.
Sau đó chạy lại `flutterfire configure` (hoặc tải lại `google-services.json`).

**iOS** – mở `ios/Runner/Info.plist`, thêm URL scheme bằng giá trị `REVERSED_CLIENT_ID` trong `GoogleService-Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.XXXXXXXX-xxxxxxxx</string>
    </array>
  </dict>
</array>
```

### 5. Cấu hình gửi email OTP (Gmail SMTP)

1. Tài khoản Gmail dùng để gửi: bật **Xác minh 2 bước**.
2. Vào <https://myaccount.google.com/apppasswords> → tạo **Mật khẩu ứng dụng** (16 ký tự).
3. Sửa `lib/config/app_config.dart`:

```dart
static const String smtpUser = 'ten_ban@gmail.com';
static const String smtpAppPassword = 'abcd efgh ijkl mnop';
```

> **Chưa cấu hình SMTP?** App vẫn chạy ở *chế độ dev*: email không gửi đi,
> mã OTP được in ra **Debug Console / logcat** và màn OTP hiện thông báo tương ứng.

### 6. Chạy

```bash
flutter run
flutter test        # chạy unit test OTP
```

> `flutter create` có thể sinh `test/widget_test.dart` mặc định (test bộ đếm) – hãy **xoá file này**.

## Kịch bản demo gợi ý

| # | Thao tác | Kết quả mong đợi |
|---|----------|------------------|
| 1 | Đăng ký email mới | Nhận email OTP 6 số |
| 2 | Nhập sai OTP | Báo sai + số lần thử còn lại |
| 3 | Nhập sai 5 lần | Mã bị huỷ, phải gửi lại |
| 4 | Chờ quá 5 phút rồi nhập | Báo hết hạn |
| 5 | Nhập đúng OTP | Tạo tài khoản, quay về màn Đăng nhập (đã điền sẵn email) |
| 6 | Đăng ký lại cùng email | Báo email đã tồn tại, **không** gửi OTP |
| 7 | Đăng nhập email + mật khẩu | Vào Trang chủ, thấy hồ sơ từ Firestore |
| 8 | Đăng xuất → Đăng nhập Google | Vào Trang chủ, hồ sơ Google lưu trên Firestore |

Kiểm chứng dữ liệu trong Firebase Console: **Authentication → Users** và **Firestore → users / registered_emails**.

## Lưu ý bảo mật (quan trọng khi trình bày)

Đây là project **demo**. Điểm khác biệt so với hệ thống thật:

- **OTP sinh và kiểm tra ngay trong app** → người dùng rành kỹ thuật có thể can thiệp. Thực tế phải
  sinh + xác thực OTP ở **server** (Cloud Functions, backend riêng) và chỉ tạo tài khoản khi server xác nhận.
- **Thông tin SMTP nằm trong app** → có thể bị trích xuất từ file APK. Thực tế gửi mail từ server,
  hoặc dùng dịch vụ như SendGrid / Firebase Extension *Trigger Email*.
- App đã làm đúng các nguyên tắc cơ bản: OTP sinh bằng `Random.secure`, chỉ lưu bản **băm + salt**,
  hết hạn, giới hạn số lần thử, dùng một lần, cooldown gửi lại.
- Collection `registered_emails` chỉ cho `get` (không `list`) để hạn chế dò danh sách email;
  vẫn có thể bị dò từng email – đánh đổi để có thể kiểm tra trùng trước khi gửi OTP.
- Có thể chạy Android/iOS; **Flutter Web không hỗ trợ** gửi SMTP bằng package `mailer`.
