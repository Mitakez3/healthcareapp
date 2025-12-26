import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
// import 'package:intl/intl.dart'; // Không dùng thì comment lại cho gọn

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
    _sessionDistance = 0.0;

    try {
      _lastPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      print(
        "START TRACKING: ${_lastPosition!.latitude}, ${_lastPosition!.longitude}",
      );
    } catch (e) {
      print("Lỗi vị trí đầu: $e");
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            if (_lastPosition != null) {
              double distance = Geolocator.distanceBetween(
                _lastPosition!.latitude,
                _lastPosition!.longitude,
                position.latitude,
                position.longitude,
              );

              // Lọc nhiễu: Chỉ tính khi di chuyển > 0.2 mét
              if (distance > 1.5) {
                // Nhân hệ số 2.5 để demo cho nhanh (thực tế nên để 1.0)
                double realDistance = distance;

                _totalDistanceMeters += realDistance;
                _sessionDistance += realDistance;

                // Công thức: 0.7m = 1 bước chân
                int newSteps = (realDistance / 0.7).ceil();

                print(
                  "MOVE: +${realDistance.toStringAsFixed(2)}m (+ $newSteps bước) | Session: ${_sessionDistance.toStringAsFixed(2)}m",
                );

                if (newSteps > 0) {
                  _totalSteps += newSteps;

                  // Cập nhật realtime lên Firebase
                  _updateFirebase(_totalSteps, _totalDistanceMeters);

                  // Reset biến tạm sau khi update
                  _totalDistanceMeters = 0;
                  _totalSteps = 0;
                }
              }
            }
            _lastPosition = position;
          },
          onError: (e) {
            print("Lỗi Stream: $e");
          },
        );
  }

  Future<void> stopTracking() async {
    isTracking = false;
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _lastPosition = null;

    if (_sessionDistance > 10) {
      print("Đang lưu lịch sử chạy bộ...");
      await _saveSessionHistory();
    } else {
      print("Quãng đường quá ngắn, không lưu.");
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
      print("Đã lưu lịch sử.");
    } catch (e) {
      print("Lỗi lưu lịch sử: $e");
    }
  }

  Future<void> _updateFirebase(int stepsToAdd, double distanceToAdd) async {
    if (user == null) return;
    try {
      final ref = _dbRef.child('users/${user!.uid}/health_data');

      await ref.runTransaction((Object? post) {
        final int nowTimestamp = DateTime.now().millisecondsSinceEpoch;
        int distanceInt = distanceToAdd.round();

        if (post == null) {
          int cal = (stepsToAdd / 30).floor();

          return Transaction.success({
            'steps': stepsToAdd,
            'distance': distanceInt,
            'calories': cal,
            'timestamp': nowTimestamp,
          });
        }

        // Trường hợp đã có dữ liệu (Cập nhật)
        Map<String, dynamic> data = Map<String, dynamic>.from(post as Map);

        int lastTimestamp = (data['timestamp'] as num?)?.toInt() ?? 0;
        bool isSameDay = false;
        if (lastTimestamp > 0) {
          DateTime lastDate = DateTime.fromMillisecondsSinceEpoch(
            lastTimestamp,
          );
          DateTime nowDate = DateTime.now();
          isSameDay =
              (lastDate.year == nowDate.year &&
              lastDate.month == nowDate.month &&
              lastDate.day == nowDate.day);
        }

        int totalStepsToday = 0;

        if (!isSameDay) {
          // Sang ngày mới -> Reset về 0 rồi cộng thêm lượng mới
          data['steps'] = stepsToAdd;
          data['distance'] = distanceInt;
          totalStepsToday = stepsToAdd;
        } else {
          // Cùng ngày -> Cộng dồn vào số cũ
          int currentSteps = (data['steps'] as num?)?.toInt() ?? 0;
          int currentDist = (data['distance'] as num?)?.toInt() ?? 0;

          data['steps'] = currentSteps + stepsToAdd;
          data['distance'] = currentDist + distanceInt;

          totalStepsToday = data['steps'];
        }

        // --- CÔNG THỨC MỚI: TÍNH CALO DỰA TRÊN TỔNG SỐ BƯỚC ---
        // Lấy tổng số bước chia cho 30, lấy phần nguyên.
        // Ví dụ: 29 bước -> 0 cal. 30 bước -> 1 cal. 65 bước -> 2 cal.
        data['calories'] = (totalStepsToday / 30).floor();
        // -----------------------------------------------------

        data['timestamp'] = nowTimestamp;
        return Transaction.success(data);
      });
    } catch (e) {
      print("❌ Lỗi update: $e");
    }
  }
}
