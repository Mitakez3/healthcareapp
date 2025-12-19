import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class RealtimeDatabaseService {
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://healthyapp-dfcc0-default-rtdb.asia-southeast1.firebasedatabase.app/'
  ).ref();

  User? get user => FirebaseAuth.instance.currentUser;

  // Stream lắng nghe dữ liệu Realtime của User hiện tại
  Stream<DatabaseEvent> getUserDataStream() {
    if (user != null) {
      return _dbRef.child('users/${user!.uid}').onValue;
    }
    return const Stream.empty();
  }

  Future<void> updateWater(int glasses) async {
    if (user == null) return;
    await _dbRef.child('users/${user!.uid}/nutrition_stats').update({'water_glasses': glasses});
  }
}