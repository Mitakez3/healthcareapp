import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _rtdbRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://healthyapp-dfcc0-default-rtdb.asia-southeast1.firebasedatabase.app/'
  ).ref();

  // Lấy người dùng hiện tại
  User? get currentUser => _auth.currentUser;

  // Đăng ký tài khoản mới
  Future<String?> signUp({required String email, required String password, required String name}) async {
    try {
      // Tạo user trên Firebase Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password
      );
      User? user = result.user;

      if (user != null) {
        // Cập nhật tên hiển thị
        await user.updateDisplayName(name);

        // Khởi tạo dữ liệu MẶC ĐỊNH (Tất cả là 0 hoặc rỗng) trên Realtime Database
        await _rtdbRef.child('users/${user.uid}').set({
          'profile': {
            'fullName': name,
            'email': email,
            'uid': user.uid,
            'createdAt': ServerValue.timestamp,
            'phone': '',
          },
          'health_data': {
            'steps': 0,
            'heart_rate': 0,
            'calories': 0,
            'distance': 0.0,
            'sleep_hours': 0.0,
            'water_liters': 0.0,
            'stress_level': 'Bình Thường',
            'spo2': 0,
          },
          'sleep_stats': {
            'quality_score': 0,
            'deep_sleep': "0h 0m",
            'light_sleep': "0h 0m",
            'rem_sleep': "0h 0m",
            'awake_time': "0m",
          },
          'nutrition_stats': {
            'water_glasses': 0,
            'calories_goal': 2000,
            'calories_consumed': 0,
          },
        });
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return "Lỗi: $e";
    }
  }

  Future<String?> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}