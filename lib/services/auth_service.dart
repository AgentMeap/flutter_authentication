import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Toàn bộ thao tác với Firebase Auth + Firestore.
///
/// Firestore:
///   users/{uid}                 -> hồ sơ người dùng (chỉ chủ sở hữu đọc/ghi)
///   registered_emails/{emailKey}-> đánh dấu email đã đăng ký (dùng để kiểm tra trùng
///                                  TRƯỚC khi gửi OTP; chỉ cho phép `get`, không `list`)
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  // `late final` để chỉ khởi tạo khi thật sự dùng (không dùng trên Web).
  late final GoogleSignIn _google = GoogleSignIn();

  /// true trong lúc đang tạo tài khoản (Firebase tự đăng nhập sau khi tạo).
  /// AuthGate dùng cờ này để không chuyển sang Home — vì ta muốn người dùng
  /// phải đăng nhập lại bằng email/mật khẩu sau khi đăng ký.
  bool isRegistering = false;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Stream<DocumentSnapshot<Map<String, dynamic>>> userDocStream(String uid) =>
      _db.collection('users').doc(uid).snapshots();

  // ---------------------------------------------------------------------------
  // Kiểm tra email đã tồn tại chưa
  // ---------------------------------------------------------------------------

  /// Doc ID an toàn (không chứa '/') cho một email.
  static String emailKey(String email) =>
      base64Url.encode(utf8.encode(email.trim().toLowerCase())).replaceAll('=', '');

  Future<bool> isEmailRegistered(String email) async {
    final doc = await _db.collection('registered_emails').doc(emailKey(email)).get();
    return doc.exists;
  }

  // ---------------------------------------------------------------------------
  // Đăng ký email + mật khẩu (gọi SAU KHI OTP đã đúng)
  // ---------------------------------------------------------------------------

  Future<void> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    isRegistering = true;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      await user.updateDisplayName(name.trim());
      await _saveProfile(
        user,
        provider: 'password',
        isNew: true,
        nameOverride: name.trim(),
      );
      // Bắt người dùng đăng nhập lại bằng email/mật khẩu.
      await _auth.signOut();
    } finally {
      isRegistering = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Đăng nhập
  // ---------------------------------------------------------------------------

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  /// Trả về `null` nếu người dùng huỷ cửa sổ chọn tài khoản Google.
  Future<UserCredential?> signInWithGoogle() async {
    final UserCredential cred;

    if (kIsWeb) {
      cred = await _auth.signInWithPopup(GoogleAuthProvider());
    } else {
      final googleUser = await _google.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      cred = await _auth.signInWithCredential(credential);
    }

    final user = cred.user;
    if (user != null) {
      await _saveProfile(
        user,
        provider: 'google.com',
        isNew: cred.additionalUserInfo?.isNewUser ?? false,
      );
    }
    return cred;
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await _google.signOut();
      } catch (_) {
        // Bỏ qua: người dùng có thể không đăng nhập bằng Google.
      }
    }
    await _auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // Lưu hồ sơ lên Firestore
  // ---------------------------------------------------------------------------

  Future<void> _saveProfile(
    User user, {
    required String provider,
    required bool isNew,
    String? nameOverride,
  }) async {
    final data = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'displayName': nameOverride ?? user.displayName,
      'photoURL': user.photoURL,
      'providers': FieldValue.arrayUnion([provider]),
      'lastLoginAt': FieldValue.serverTimestamp(),
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
    };
    await _db.collection('users').doc(user.uid).set(data, SetOptions(merge: true));

    final email = user.email;
    if (email != null) {
      final ref = _db.collection('registered_emails').doc(emailKey(email));
      if (!(await ref.get()).exists) {
        await ref.set({'createdAt': FieldValue.serverTimestamp()});
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Việt hoá thông báo lỗi
  // ---------------------------------------------------------------------------

  static String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
        case 'invalid-email':
          return 'Email hoặc mật khẩu không đúng.';
        case 'user-disabled':
          return 'Tài khoản đã bị vô hiệu hoá.';
        case 'too-many-requests':
          return 'Thao tác quá nhiều lần. Vui lòng thử lại sau.';
        case 'email-already-in-use':
          return 'Email này đã được đăng ký.';
        case 'weak-password':
          return 'Mật khẩu quá yếu.';
        case 'network-request-failed':
          return 'Không có kết nối mạng.';
        case 'account-exists-with-different-credential':
          return 'Email này đã đăng ký bằng phương thức khác.';
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
          return 'Bạn đã đóng cửa sổ đăng nhập.';
        default:
          return 'Lỗi xác thực (${e.code}).';
      }
    }
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return 'Không có quyền truy cập Firestore. Hãy kiểm tra Firestore Rules.';
      }
      return 'Lỗi Firebase (${e.code}).';
    }
    return 'Đã xảy ra lỗi: $e';
  }
}
