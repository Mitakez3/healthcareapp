import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class GPSService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  User? get user => FirebaseAuth.instance.currentUser;

  StreamSubscription<Position>? _positionStreamSubscription;

  double _totalDistanceMeters = 0.0;
  int _totalSteps = 0;
  double _sessionDistance = 0.0;

  // Thêm biến để lưu loại hoạt động hiện tại
  String _currentType = 'walk';
  String _currentTitle = 'Đi bộ';

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

  // CẬP NHẬT: Nhận thêm tham số type và title
  Future<void> startTracking({String type = 'walk', String title = 'Đi bộ'}) async {
    if (!await _handlePermission()) return;

    isTracking = true;
    _totalDistanceMeters = 0;
    _totalSteps = 0;
    _sessionDistance = 0.0;

    // Lưu lại loại hình đang tập
    _currentType = type;
    _currentTitle = title;

    try {
      _lastPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      print("START $_currentTitle ($_currentType): ${_lastPosition!.latitude}, ${_lastPosition!.longitude}");
    } catch (e) {
      print("Lỗi vị trí đầu: $e");
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0, // Nhận tất cả thay đổi nhỏ nhất
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

              // Lọc nhiễu: Chỉ tính khi di chuyển > 1.5 mét
              if (distance > 1.5) {
                _totalDistanceMeters += distance;
                _sessionDistance += distance;

                // Tính số bước (Ước lượng)
                // Đi bộ/Chạy: ~0.7m/bước. Đạp xe: Không có bước (nhưng vẫn tính quy đổi để hiện chỉ số vận động)
                int newSteps = 0;
                if (_currentType == 'cycle') {
                  newSteps = (distance / 2.0).ceil(); // Đạp xe tốn ít bước hơn/mét
                } else {
                  newSteps = (distance / 0.7).ceil(); // Đi bộ/Chạy
                }

                if (newSteps > 0) {
                  _totalSteps += newSteps;
                  // Cập nhật realtime
                  _updateFirebase(_totalSteps, _totalDistanceMeters);

                  // Reset biến tạm
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

    // Chỉ lưu nếu quãng đường > 10m (tránh bấm nhầm)
    if (_sessionDistance > 10) {
      print("Đang lưu lịch sử $_currentTitle...");
      await _saveSessionHistory();
    } else {
      print("Quãng đường quá ngắn (${_sessionDistance.toInt()}m), không lưu.");
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

        // CẬP NHẬT: Lưu đúng title và type hiện tại
        currentHistory.add({
          'title': _currentTitle, // Ví dụ: "Đạp xe"
          'time': timestamp,
          'stat': statStr,
          'type': _currentType,   // Ví dụ: "cycle"
        });
        return Transaction.success(currentHistory);
      });
      print("Đã lưu lịch sử thành công.");
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

        // Tính Calo:
        // Đi bộ: ~30 bước = 1 cal
        // Đạp xe: Tốn ít calo hơn cho cùng quãng đường quy đổi
        int caloriesBurned = 0;
        if (_currentType == 'cycle') {
          caloriesBurned = (stepsToAdd / 60).floor(); // Đạp xe nhẹ hơn
        } else if (_currentType == 'run') {
          caloriesBurned = (stepsToAdd / 20).floor(); // Chạy tốn nhiều hơn
        } else {
          caloriesBurned = (stepsToAdd / 30).floor(); // Đi bộ
        }

        if (post == null) {
          return Transaction.success({
            'steps': stepsToAdd,
            'distance': distanceInt,
            'calories': caloriesBurned,
            'timestamp': nowTimestamp,
          });
        }

        Map<String, dynamic> data = Map<String, dynamic>.from(post as Map);
        int lastTimestamp = (data['timestamp'] as num?)?.toInt() ?? 0;

        // Kiểm tra qua ngày mới
        bool isSameDay = false;
        if (lastTimestamp > 0) {
          DateTime lastDate = DateTime.fromMillisecondsSinceEpoch(lastTimestamp);
          DateTime nowDate = DateTime.now();
          isSameDay = (lastDate.year == nowDate.year && lastDate.month == nowDate.month && lastDate.day == nowDate.day);
        }

        if (!isSameDay) {
          data['steps'] = stepsToAdd;
          data['distance'] = distanceInt;
          data['calories'] = caloriesBurned;
        } else {
          int currentSteps = (data['steps'] as num?)?.toInt() ?? 0;
          int currentDist = (data['distance'] as num?)?.toInt() ?? 0;
          int currentCal = (data['calories'] as num?)?.toInt() ?? 0;

          data['steps'] = currentSteps + stepsToAdd;
          data['distance'] = currentDist + distanceInt;
          data['calories'] = currentCal + caloriesBurned;
        }

        data['timestamp'] = nowTimestamp;
        return Transaction.success(data);
      });
    } catch (e) {
      print("❌ Lỗi update: $e");
    }
  }
}