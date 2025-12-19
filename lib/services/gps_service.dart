import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class GPSService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  User? get user => FirebaseAuth.instance.currentUser;

  StreamSubscription<Position>? _positionStreamSubscription;

  double _totalDistanceMeters = 0.0;
  int _totalSteps = 0;
  double _sessionDistance = 0.0;

  Position? _lastPosition;
  bool isTracking = false;

  Future<bool> _handlePermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<void> startTracking() async {
    if (!await _handlePermission()) return;

    isTracking = true;
    _totalDistanceMeters = 0;
    _totalSteps = 0;

    // Reset quãng đường phiên chạy về 0 khi bắt đầu
    _sessionDistance = 0.0;

    try {
      _lastPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation
      );
      print("START TRACKING: ${_lastPosition!.latitude}, ${_lastPosition!.longitude}");
    } catch (e) {
      print("Lỗi vị trí đầu: $e");
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {

      if (_lastPosition != null) {
        double distance = Geolocator.distanceBetween(
            _lastPosition!.latitude, _lastPosition!.longitude,
            position.latitude, position.longitude
        );

        if (distance > 0.2) {
          double demoDistance = distance * 2.5;

          // Cộng vào biến tạm để update Realtime (Health Data)
          _totalDistanceMeters += demoDistance;

          // Cộng vào biến Session để lưu Lịch sử sau này
          _sessionDistance += demoDistance;

          int newSteps = (demoDistance / 0.7).ceil();

          print("MOVE: +${demoDistance.toStringAsFixed(2)}m | Session: ${_sessionDistance.toStringAsFixed(2)}m");

          if (newSteps > 0) {
            _totalSteps += newSteps;

            // Cập nhật realtime chỉ số bước/calo
            _updateFirebase(_totalSteps, _totalDistanceMeters);

            // Reset biến realtime
            _totalDistanceMeters = 0;
            _totalSteps = 0;
          }
        }
      }
      _lastPosition = position;

    }, onError: (e) {
      print("Lỗi Stream: $e");
    });
  }

  Future<void> stopTracking() async {
    isTracking = false;
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _lastPosition = null;

    // Khi dừng, nếu quãng đường đi được > 10 mét thì mới lưu
    if (_sessionDistance > 10) {
      print("Đang lưu lịch sử chạy bộ...");
      await _saveSessionHistory();
    } else {
      print("Quãng đường quá ngắn (${_sessionDistance.toStringAsFixed(1)}m), không lưu lịch sử.");
    }
    _sessionDistance = 0.0;
  }

  Future<void> _saveSessionHistory() async {
    if (user == null) return;

    try {
      final historyRef = _dbRef.child('users/${user!.uid}/activity_history');
      final int timestamp = DateTime.now().millisecondsSinceEpoch;

      String statStr;
      if (_sessionDistance >= 1000) {
        statStr = "${(_sessionDistance / 1000).toStringAsFixed(2)} km";
      } else {
        statStr = "${_sessionDistance.toInt()} m";
      }

      await historyRef.runTransaction((Object? post) {
        List<dynamic> currentHistory = [];

        if (post != null) {
          if (post is List) {
            currentHistory = List.from(post);
          } else if (post is Map) {
            Map<dynamic, dynamic> map = post as Map;
            var sortedKeys = map.keys.toList()..sort();
            for (var key in sortedKeys) {
              currentHistory.add(map[key]);
            }
          }
        }

        currentHistory.add({
          'title': "Đi bộ",
          'time': timestamp,
          'stat': statStr,
          'type': 'walk',
        });

        return Transaction.success(currentHistory);
      });

      print("Đã lưu lịch sử (Timestamp: $timestamp)");

    } catch (e) {
      print("Lỗi lưu lịch sử: $e");
    }
  }

  // --- HÀM CẬP NHẬT REALTIME (GIỮ NGUYÊN) ---
  Future<void> _updateFirebase(int stepsToAdd, double distanceToAdd) async {
    if (user == null) return;
    try {
      final ref = _dbRef.child('users/${user!.uid}/health_data');

      await ref.runTransaction((Object? post) {
        final int nowTimestamp = DateTime.now().millisecondsSinceEpoch;
        int distanceInt = distanceToAdd.round();

        if (post == null) {
          return Transaction.success({
            'steps': stepsToAdd,
            'distance': distanceInt,
            'calories': (stepsToAdd * 0.04).toInt(),
            'timestamp': nowTimestamp,
          });
        }

        Map<String, dynamic> data = Map<String, dynamic>.from(post as Map);

        int lastTimestamp = (data['timestamp'] as num?)?.toInt() ?? 0;
        bool isSameDay = false;
        if (lastTimestamp > 0) {
          DateTime lastDate = DateTime.fromMillisecondsSinceEpoch(lastTimestamp);
          DateTime nowDate = DateTime.now();
          isSameDay = (lastDate.year == nowDate.year &&
              lastDate.month == nowDate.month &&
              lastDate.day == nowDate.day);
        }

        if (!isSameDay) {
          data['steps'] = stepsToAdd;
          data['distance'] = distanceInt;
          data['calories'] = (stepsToAdd * 0.04).toInt();
        } else {
          int currentSteps = (data['steps'] as num?)?.toInt() ?? 0;
          int currentDist = (data['distance'] as num?)?.toInt() ?? 0;
          int currentCal = (data['calories'] as num?)?.toInt() ?? 0;

          data['steps'] = currentSteps + stepsToAdd;
          data['distance'] = currentDist + distanceInt;
          data['calories'] = currentCal + (stepsToAdd * 0.04).toInt();
        }

        data['timestamp'] = nowTimestamp;
        return Transaction.success(data);
      });
    } catch (e) {
      print("❌ Lỗi update: $e");
    }
  }
}