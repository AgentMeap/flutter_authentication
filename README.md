# Flutter OTP & Google Sign-In Demo

Project demo **2 phương thức bảo mật tài khoản**:

1. **OTP qua email khi đăng ký** – xác minh quyền sở hữu email trước khi tạo tài khoản.
2. **Đăng nhập bằng Google qua Firebase** – ủy quyền OAuth 2.0, lưu hồ sơ lên Firestore.

## Luồng hoạt động

```
ĐĂNG KÝ
 Nhập tên + email + mật khẩu
   └─► sinh OTP 6 số ─► gửi về email (SMTP)
         └─► Nhập OTP
               ├─ Sai / hết hạn ─► báo lỗi, cho gửi lại
               └─ Đúng ─► tạo tài khoản Firebase Auth
                            ├─ Email đã tồn tại (email-already-in-use) ─► báo lỗi, yêu cầu đăng nhập
                            └─ Thành công ─► lưu users/{uid}
                                             ─► quay về Đăng nhập (email + mật khẩu)

ĐĂNG NHẬP
 ├─ Email + mật khẩu  (Firebase Auth)
 └─ Google            (google_sign_in ─► Firebase Auth ─► lưu users/{uid})
```

## Cấu trúc

```
lib/
├── main.dart                    # khởi tạo Firebase, AuthGate (Login ↔ Home)
├── firebase_options.dart        # cấu hình Firebase (sinh bởi `flutterfire configure` hoặc viết tay – xem bước 6)
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

### 0. Yêu cầu

| Công cụ | Kiểm tra | Ghi chú |
|---|---|---|
| Flutter SDK (Dart ≥ 3.3) | `flutter --version` | |
| JDK 17 | `java -version` | dùng cho Gradle / `keytool` |
| Node.js + npm | `node -v` | để cài Firebase CLI |
| Android Studio / thiết bị Android | `flutter devices` | máy ảo nên chọn image **có Google Play** (để đăng nhập Google) |

Các package Firebase **đã có sẵn** trong `pubspec.yaml` (`firebase_core`, `firebase_auth`,
`cloud_firestore`, `google_sign_in`) – không cần `flutter pub add` thêm.

### 1. Lấy dependencies

```bash
flutter pub get
```

> Thư mục `android/` và `ios/` đã có sẵn. Chỉ khi bị thiếu mới cần chạy
> `flutter create . --project-name flutter_otp_demo --platforms=android,ios`
> (lệnh này **không ghi đè** `pubspec.yaml` và `lib/`).
> Nếu `flutter create` sinh `test/widget_test.dart` mặc định (test bộ đếm) – hãy **xoá file này**.

### 2. Cài Firebase CLI và FlutterFire CLI (làm 1 lần trên máy)

```bash
npm install -g firebase-tools
firebase login                      # mở trình duyệt, đăng nhập tài khoản Google sở hữu project
dart pub global activate flutterfire_cli
```

Kiểm tra: `firebase projects:list` phải liệt kê project của bạn, `flutterfire --version` phải chạy được.

> **Windows:** nếu báo không tìm thấy lệnh `flutterfire`, thêm
> `%LOCALAPPDATA%\Pub\Cache\bin` vào biến môi trường **PATH** rồi mở lại terminal.

### 3. Tạo và cấu hình project trên Firebase Console

1. Vào [Firebase Console](https://console.firebase.google.com) → **Add project** (Google Analytics có thể tắt).
2. **Build → Authentication → Get started → Sign-in method**, bật:
   - **Email/Password** (chỉ bật dòng đầu, *không* cần Email link).
   - **Google** → chọn *Project support email* → **Save**.
3. **Build → Firestore Database → Create database** → chọn location (vd. `asia-southeast1`) →
   chế độ **production** → **Create**.
4. Tab **Rules** của Firestore: xoá nội dung mặc định, dán toàn bộ file `firestore.rules` → **Publish**.

### 4. Lấy SHA-1 / SHA-256 của máy build (bắt buộc cho Google Sign-In trên Android)

Cách 1 – dùng Gradle:

```bash
cd android
./gradlew signingReport             # Windows CMD/PowerShell: .\gradlew signingReport
```

Tìm khối `Variant: debug` → copy dòng `SHA1` và `SHA-256`.

Cách 2 – đọc trực tiếp debug keystore:

```bash
keytool -list -v -alias androiddebugkey -storepass android -keypass android \
  -keystore ~/.android/debug.keystore
# Windows: -keystore %USERPROFILE%\.android\debug.keystore
```

> Mỗi máy tính có debug keystore **khác nhau** → mỗi thành viên trong nhóm phải thêm SHA của máy mình.

### 5. Đăng ký app Android và thêm SHA

1. Firebase Console → ⚙️ **Project settings → General → Your apps → Add app → Android**
   (bỏ qua nếu bước 6 đã tạo app giúp bạn).
2. **Android package name:** `com.example.flutter_otp_demo`
   (phải trùng `applicationId` trong `android/app/build.gradle.kts`).
3. Trong thẻ app Android → **Add fingerprint** → dán **SHA-1**, lặp lại cho **SHA-256** → **Save**.

### 6. Kết nối app với Firebase (sinh file cấu hình)

**Phải làm SAU bước 5** để file cấu hình chứa OAuth client của Google Sign-In.

```bash
flutterfire configure
```

- Chọn project vừa tạo, tick nền tảng **android** (và **ios** nếu cần).
- Khi được hỏi có cập nhật cấu hình Gradle (Google Services plugin) → chọn **yes**.

Kết quả cần có:

| File | Vai trò |
|---|---|
| `lib/firebase_options.dart` | thay thế file placeholder; chứa `apiKey`, `appId`, `projectId`… |
| `android/app/google-services.json` | cấu hình Android, chứa OAuth client cho Google Sign-In |
| `ios/Runner/GoogleService-Info.plist` | chỉ khi chọn iOS |
| `firebase.json` | file ghi lại cấu hình FlutterFire (có thể commit) |

#### Cách thủ công (không cần Firebase CLI / FlutterFire CLI) – chỉ Android

1. Firebase Console → *Project settings → Your apps (Android)* → **Download google-services.json**
   → đặt vào `android/app/google-services.json`.
2. Ghi đè `lib/firebase_options.dart` bằng nội dung sau, thay các giá trị lấy từ `google-services.json`:

| Trường trong `FirebaseOptions` | Lấy từ `google-services.json` |
|---|---|
| `apiKey` | `client[0].api_key[0].current_key` |
| `appId` | `client[0].client_info.mobilesdk_app_id` |
| `messagingSenderId` | `project_info.project_number` |
| `projectId` | `project_info.project_id` |
| `storageBucket` | `project_info.storage_bucket` |

```dart
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
    apiKey: 'AIza...',                          // current_key
    appId: '1:123456789:android:abcdef...',     // mobilesdk_app_id
    messagingSenderId: '123456789',             // project_number
    projectId: 'ten-project',                   // project_id
    storageBucket: 'ten-project.firebasestorage.app',
  );
}
```

> Cách này chỉ cấu hình **Android**. Muốn chạy iOS thì vẫn phải chạy `flutterfire configure`
> (hoặc thêm `static const FirebaseOptions ios` từ `GoogleService-Info.plist`).
> Sau khi thêm SHA mới ở bước 5, nhớ **tải lại** `google-services.json`.

### 7. Kiểm tra plugin Google Services trong Gradle

`GoogleSignIn()` trong `auth_service.dart` **không** truyền `serverClientId`, nên trên Android
plugin `com.google.gms.google-services` **bắt buộc** phải có để đọc `google-services.json`.
Mở 2 file sau, nếu `flutterfire configure` chưa thêm thì tự thêm:

`android/settings.gradle.kts`

```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "..." apply false
    id("org.jetbrains.kotlin.android") version "..." apply false
    id("com.google.gms.google-services") version "4.4.2" apply false   // ← thêm
}
```

`android/app/build.gradle.kts`

```kotlin
plugins {
    id("com.android.application")
    id("com.google.gms.google-services")                                 // ← thêm
    id("dev.flutter.flutter-gradle-plugin")
}
```

> Nếu build báo lỗi `minSdk`, đặt `minSdk = 23` trong `android/app/build.gradle.kts`.

### 8. Cấu hình Google Sign-In cho iOS (bỏ qua nếu chỉ chạy Android)

Mở `ios/Runner/Info.plist`, thêm URL scheme bằng giá trị `REVERSED_CLIENT_ID` trong `GoogleService-Info.plist`:

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

### 9. Cấu hình gửi email OTP (Gmail SMTP)

1. Tài khoản Gmail dùng để gửi: bật **Xác minh 2 bước**.
2. Vào <https://myaccount.google.com/apppasswords> → tạo **Mật khẩu ứng dụng** (16 ký tự).
3. Sửa `lib/config/app_config.dart`:

```dart
static const String smtpUser = 'ten_ban@gmail.com';
static const String smtpAppPassword = 'abcd efgh ijkl mnop';
```

- App Password gồm **16 chữ cái**; viết liền (`abcdefghijklmnop`) hay có dấu cách như Google hiển thị đều được.
- **Không** dùng mật khẩu đăng nhập Gmail thông thường – Gmail sẽ từ chối (`535 Username and Password not accepted`).
- Kiểm tra nhanh: chạy app → Đăng ký bằng một email bạn truy cập được → email OTP đến trong vài giây
  (xem cả thư mục **Spam**). Nếu gửi lỗi, thông báo lỗi hiện trên màn hình và trong Debug Console.

> ⚠️ **Bảo mật:** App Password nằm trong mã nguồn. **Không** đẩy file `app_config.dart` có mật khẩu thật
> lên GitHub công khai. Nếu lỡ lộ, vào <https://myaccount.google.com/apppasswords> xoá mật khẩu đó và tạo mới.

> **Chưa cấu hình SMTP?** App vẫn chạy ở *chế độ dev*: email không gửi đi,
> mã OTP được in ra **Debug Console / logcat** và màn OTP hiện thông báo tương ứng.

### 10. Chạy

Mở máy ảo Android (hoặc cắm điện thoại thật đã bật *USB debugging*):

```bash
flutter emulators                         # liệt kê máy ảo có sẵn
flutter emulators --launch <emulator_id>  # vd. Pixel_7
flutter devices                           # phải thấy thiết bị android
```

> Máy ảo phải dùng system image **có Google Play** (biểu tượng Play Store trong Device Manager),
> nếu không đăng nhập Google sẽ lỗi `ApiException: 12500`. Lần đầu trên máy ảo cần đăng nhập
> một tài khoản Google trong *Settings*.

Chạy app và test:

```bash
flutter clean
flutter pub get
flutter run         # chọn thiết bị android nếu được hỏi (đừng chọn Chrome/Edge – Web không hỗ trợ)
flutter test        # chạy unit test OTP
```

> **Lần build Android đầu tiên khá lâu (5–10 phút)** vì Gradle phải tải dependencies – các lần sau nhanh hơn nhiều.
>
> `test/widget_test.dart` là test bộ đếm mặc định do `flutter create` sinh ra (`Counter increments smoke test`),
> không liên quan app này → **xoá file đó**, nếu không `flutter test` sẽ báo lỗi.

### Checklist trước khi chạy

- [ ] `lib/firebase_options.dart` **không còn** dòng `FILE TẠM (placeholder)`
- [ ] Có file `android/app/google-services.json`, trong đó `package_name` = `com.example.flutter_otp_demo`
- [ ] `google-services.json` có mục `oauth_client` với `client_type: 3` (nếu trống → chưa thêm SHA, làm lại bước 5–6)
- [ ] Đã thêm plugin `com.google.gms.google-services` vào 2 file Gradle
- [ ] Authentication đã bật **Email/Password** và **Google**
- [ ] Firestore đã tạo database và **Publish** rules
- [ ] (Tuỳ chọn) Đã điền `smtpUser` + `smtpAppPassword` thật trong `lib/config/app_config.dart`
- [ ] Đã xoá `test/widget_test.dart` mặc định

### Lỗi thường gặp

| Triệu chứng | Nguyên nhân / cách sửa |
|---|---|
| App hiện màn hình "Chưa cấu hình Firebase" | Chưa chạy `flutterfire configure` → `firebase_options.dart` vẫn là placeholder |
| `File google-services.json is missing` khi build | Đặt file vào đúng `android/app/` (không phải `android/`) |
| Đăng nhập Google: `PlatformException(sign_in_failed, ... ApiException: 10)` | Thiếu/sai SHA-1, hoặc chưa tải lại `google-services.json` sau khi thêm SHA |
| Đăng nhập Google: `ApiException: 12500` | Chưa chọn *support email* khi bật Google provider, hoặc máy ảo không có Google Play |
| Bấm Google xong không có gì xảy ra / `default_web_client_id` not found | Thiếu plugin `com.google.gms.google-services` (bước 7) |
| `[firebase_auth/operation-not-allowed]` | Chưa bật Email/Password hoặc Google trong Sign-in method |
| `[cloud_firestore/permission-denied]` | Chưa Publish `firestore.rules` |
| `[cloud_firestore/not-found]` / `database (default) does not exist` | Chưa tạo Firestore database |
| Gửi OTP lỗi `535 Username and Password not accepted` | Dùng sai mật khẩu (phải là App Password), hoặc tài khoản chưa bật Xác minh 2 bước |
| Không nhận được email OTP | Xem thư mục Spam; kiểm tra `smtpUser` đúng địa chỉ Gmail đã tạo App Password |
| OTP chỉ in ra console, không gửi email | `smtpUser` / `smtpAppPassword` vẫn là giá trị mẫu |
| `flutter test` lỗi `Counter increments smoke test` | Xoá `test/widget_test.dart` mặc định |
| `flutter run` chỉ thấy Chrome / Edge | Chưa mở máy ảo Android hoặc chưa cắm điện thoại (xem bước 10) |
| `firebase: command not found` sau khi `npm install -g` | Mở lại terminal; kiểm tra thư mục của `npm prefix -g` có trong PATH |
| `flutterfire: command not found` | Thêm `%LOCALAPPDATA%\Pub\Cache\bin` (Windows) hoặc `~/.pub-cache/bin` vào PATH |
| `Failed to fetch your Firebase projects` | Chưa `firebase login`, hoặc đăng nhập sai tài khoản |

## Kịch bản demo gợi ý

| # | Thao tác | Kết quả mong đợi |
|---|----------|------------------|
| 1 | Đăng ký email mới | Nhận email OTP 6 số |
| 2 | Nhập sai OTP | Báo sai + số lần thử còn lại |
| 3 | Nhập sai 5 lần | Mã bị huỷ, phải gửi lại |
| 4 | Chờ quá 5 phút rồi nhập | Báo hết hạn |
| 5 | Nhập đúng OTP | Tạo tài khoản, quay về màn Đăng nhập (đã điền sẵn email) |
| 6 | Đăng ký lại cùng email | Nhận OTP; nhập đúng thì báo email đã được đăng ký |
| 7 | Đăng nhập email + mật khẩu | Vào Trang chủ, thấy hồ sơ từ Firestore |
| 8 | Đăng xuất → Đăng nhập Google | Vào Trang chủ, hồ sơ Google lưu trên Firestore |

Kiểm chứng dữ liệu trong Firebase Console: **Authentication → Users** và **Firestore → users**.

## Lưu ý bảo mật (quan trọng khi trình bày)

Đây là project **demo**. Điểm khác biệt so với hệ thống thật:

- **OTP sinh và kiểm tra ngay trong app** → người dùng rành kỹ thuật có thể can thiệp. Thực tế phải
  sinh + xác thực OTP ở **server** (Cloud Functions, backend riêng) và chỉ tạo tài khoản khi server xác nhận.
- **Thông tin SMTP nằm trong app** → có thể bị trích xuất từ file APK. Thực tế gửi mail từ server,
  hoặc dùng dịch vụ như SendGrid / Firebase Extension *Trigger Email*.
- App đã làm đúng các nguyên tắc cơ bản: OTP sinh bằng `Random.secure`, chỉ lưu bản **băm + salt**,
  hết hạn, giới hạn số lần thử, dùng một lần, cooldown gửi lại.
- Firebase Auth là nguồn duy nhất quyết định email đã tồn tại (không lưu bản sao trên Firestore)
  → xoá user trong Authentication là đăng ký lại được ngay, và không lộ danh sách email qua Firestore.
- Có thể chạy Android/iOS; **Flutter Web không hỗ trợ** gửi SMTP bằng package `mailer`.
