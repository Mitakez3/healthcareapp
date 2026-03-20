import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ActivityRecognitionService {
  Interpreter? _interpreter;
  List<String>? _labels;

  final List<double> _buffer = [];
  StreamSubscription? _sensorSubscription;

  bool _isProcessing = false;
  bool _isWarmup = true;

  double _prevMag = 0;
  int _totalSteps = 0;
  double _totalDistance = 0.0;

  // Thời gian bước chân cuối cùng (Chống đếm đúp)
  int _lastStepTime = 0;
  bool _isStepActive = false;
  final double _stepLengthWalking = 0.7;
  // Đã xóa bỏ stepLengthRunning theo yêu cầu

  // CÁC BIẾN THEO DÕI TÉ NGÃ
  bool _isCheckingFall = false;
  int _fallCheckStartTime = 0;

  final _activityController = StreamController<String>.broadcast();
  Stream<String> get activityStream => _activityController.stream;

  final _fallAlertController = StreamController<bool>.broadcast();
  Stream<bool> get fallAlertStream => _fallAlertController.stream;

  final _metricsController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get metricsStream => _metricsController.stream;

  // =============================
  // INIT
  // =============================
  Future<void> init() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/tflite/har_custom_model.tflite',
      );
      final labelData = await rootBundle.loadString(
        'assets/tflite/custom_labels.txt',
      );
      _labels = labelData.trim().split('\n');
      print("✅ Custom Model loaded");
    } catch (e) {
      print("❌ Model load error: $e");
    }
  }

  // =============================
  // START
  // =============================
  void startTracking() {
    _buffer.clear();
    _totalSteps = 0;
    _totalDistance = 0.0;
    _lastStepTime = DateTime.now().millisecondsSinceEpoch;
    _isWarmup = true;

    _isCheckingFall = false;
    _fallCheckStartTime = 0;

    print("🚀 Start tracking");

    Future.delayed(const Duration(seconds: 2), () {
      _isWarmup = false;
      print("✅ Sensor stabilized");
    });

    _sensorSubscription =
        accelerometerEventStream(
          samplingPeriod: SensorInterval.gameInterval,
        ).listen((event) {
          if (_isProcessing) return;

          // 1. TÍNH TOÁN LỰC
          double rawMag = sqrt(
            event.x * event.x + event.y * event.y + event.z * event.z,
          );
          double dynamicMag = (rawMag - 9.81).abs();

          double smoothMag = (_prevMag * 0.7) + (dynamicMag * 0.3);
          _prevMag = smoothMag;

          int currentTime = DateTime.now().millisecondsSinceEpoch;

          // 2. BỘ ĐẾM BƯỚC CHÂN (GIỮ NGUYÊN 100% NHƯ BẢN CHUẨN CỦA ÔNG)
          if (!_isWarmup) {
            if (smoothMag > 1.3 && !_isStepActive) {
              if (currentTime - _lastStepTime > 300) {
                _totalSteps++;
                _totalDistance += _stepLengthWalking;
                _metricsController.add({
                  'steps': _totalSteps,
                  'distance': _totalDistance,
                });
                _lastStepTime = currentTime;
                _isStepActive = true;
              }
            } else if (smoothMag < 0.8) {
              _isStepActive = false;
            }
          }

          // 3. THEO DÕI TÉ NGÃ
          // Hạ ngưỡng kích hoạt xuống 8.0 m/s2 để ném lên nệm mềm cũng nhận ra
          if (!_isWarmup && dynamicMag > 8.0 && !_isCheckingFall) {
            _isCheckingFall = true;
            _fallCheckStartTime = currentTime;
          }

          // 4. CHUẨN BỊ DỮ LIỆU CHO AI
          _buffer.add(event.x / 9.81);
          _buffer.add(event.y / 9.81);
          _buffer.add(event.z / 9.81);

          if (_buffer.length >= 384) {
            _runInference();
          }
        });
  }

  // =============================
  // STOP
  // =============================
  void stopTracking() {
    _sensorSubscription?.cancel();
    _buffer.clear();
  }

  // =============================
  // INFERENCE
  // =============================
  Future<void> _runInference() async {
    if (_interpreter == null || _labels == null || _isWarmup) return;
    _isProcessing = true;

    try {
      var input = [_reshapeBuffer(_buffer, 128, 3)];
      var output = List.generate(1, (_) => List.filled(5, 0.0));

      _interpreter!.run(input, output);
      List<double> probabilities = List<double>.from(output[0]);

      int maxIdx = 0;
      double maxProb = probabilities[0];

      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIdx = i;
        }
      }

      String detectedActivity = _labels![maxIdx];

      // XÓA BỎ RUNNING: Bất kỳ lúc nào AI ra Running, ta ép nó thành Walking
      if (detectedActivity == "Running") {
        detectedActivity = "Walking";
      }

      int currentTime = DateTime.now().millisecondsSinceEpoch;

      double minMag = 999.0;
      double maxMag = 0.0;
      for (int i = 0; i < 128; i++) {
        double x = _buffer[i * 3];
        double y = _buffer[i * 3 + 1];
        double z = _buffer[i * 3 + 2];
        double mag = sqrt(x * x + y * y + z * z);
        if (mag < minMag) minMag = mag;
        if (mag > maxMag) maxMag = mag;
      }
      double amplitude = maxMag - minMag;

      // ==========================================================
      // XỬ LÝ TÉ NGÃ SAU KHI NÉM
      // ==========================================================
      if (_isCheckingFall) {
        if (currentTime - _fallCheckStartTime < 4000) {
          // Đợi 4 giây để quá trình nhào lộn / rớt kết thúc hoàn toàn
          detectedActivity = "Analyzing...";
        } else {
          // Hết 4 giây, phân tích xem ĐIỆN THOẠI CÓ ĐANG NẰM IM KHÔNG
          if (amplitude < 0.5) {
            // Nằm im bất động (lực rung < 0.5G) -> Chính xác là đã ngã!
            _fallAlertController.add(true);
            detectedActivity = "Fall";
          } else {
            // Có người cầm máy lên, đang rung lắc -> Hủy báo ngã!
            detectedActivity = (currentTime - _lastStepTime < 1500)
                ? "Walking"
                : "Standing";
          }
          _isCheckingFall = false; // Xong chu trình
        }
      }

      // ==========================================================
      // LỌC ĐI / ĐỨNG / NGỒI (KHI KHÔNG CÓ NGÃ)
      // ==========================================================
      if (!_isCheckingFall &&
          detectedActivity != "Analyzing..." &&
          detectedActivity != "Fall") {
        if (amplitude < 0.8 && detectedActivity == "Walking") {
          double currentY = _buffer[127 * 3 + 1];
          if (currentY < -0.6) {
            detectedActivity = "Standing";
          } else {
            detectedActivity = "Sitting";
          }
        }

        if ((currentTime - _lastStepTime < 1500) && amplitude > 1.0) {
          detectedActivity = "Walking";
        }
      }

      if (maxProb > 0.5 && !detectedActivity.contains("Fall")) {
        _activityController.add(detectedActivity);
      }
    } catch (e) {
      print("❌ inference error: $e");
    } finally {
      _buffer.removeRange(0, 192);
      _isProcessing = false;
    }
  }

  List<List<double>> _reshapeBuffer(List<double> list, int rows, int cols) {
    List<List<double>> result = [];
    for (int i = 0; i < rows; i++) {
      result.add(list.sublist(i * cols, (i + 1) * cols));
    }
    return result;
  }

  void dispose() {
    stopTracking();
    _interpreter?.close();
    _activityController.close();
    _fallAlertController.close();
    _metricsController.close();
  }
}
