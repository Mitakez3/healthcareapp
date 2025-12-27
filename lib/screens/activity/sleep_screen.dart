import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

// --- CẤU HÌNH API KEY ---
const String _apiKey = 'AIzaSyByrk3WkHBH2Iq8bS9F1DfIr39s0JCk1EA';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Biến trạng thái
  bool _isSleeping = false;
  DateTime? _startTime;
  String _elapsedTime = "00:00:00";
  Timer? _timer;
  bool _isAnalyzing = false;

  // Dữ liệu hiển thị kết quả gần nhất
  String _lastScore = "--";
  String _lastDuration = "--";
  String _aiAdvice = "Chưa có dữ liệu giấc ngủ.";

  @override
  void initState() {
    super.initState();
    _checkSleepStatus();
    _fetchLastSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 1. Kiểm tra trạng thái ngủ
  void _checkSleepStatus() async {
    if (user == null) return;
    try {
      final snapshot = await _dbRef
          .child('users/${user!.uid}/health_data/sleep_status')
          .get();
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        if (data['is_sleeping'] == true) {
          int startMillis = (data['start_time'] as num).toInt();
          setState(() {
            _isSleeping = true;
            _startTime = DateTime.fromMillisecondsSinceEpoch(startMillis);
          });
          _startTimer();
        }
      }
    } catch (e) {
      print("Lỗi check status: $e");
    }
  }

  // 2. Lấy dữ liệu gần nhất
  void _fetchLastSession() {
    if (user == null) return;
    _dbRef.child('users/${user!.uid}/health_data/sleep_latest').onValue.listen((
      event,
    ) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        if (mounted) {
          setState(() {
            _lastScore = data['score'].toString();
            _lastDuration = data['duration_text'].toString();
            _aiAdvice = data['advice'].toString();
          });
        }
      }
    });
  }

  // 3. BẮT ĐẦU NGỦ
  void _startSleep() async {
    final now = DateTime.now();
    setState(() {
      _isSleeping = true;
      _startTime = now;
    });

    await _dbRef.child('users/${user!.uid}/health_data/sleep_status').set({
      'is_sleeping': true,
      'start_time': now.millisecondsSinceEpoch,
    });

    _startTimer();
  }

  // Timer
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null) {
        final now = DateTime.now();
        final duration = now.difference(_startTime!);
        setState(() {
          _elapsedTime = _printDuration(duration);
        });
      }
    });
  }

  String _printDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  // 4. THỨC DẬY & GỌI AI
  void _wakeUp() async {
    _timer?.cancel();
    final endTime = DateTime.now();

    // Safety check
    final startTimeSafe =
        _startTime ?? endTime.subtract(const Duration(seconds: 1));
    final duration = endTime.difference(startTimeSafe);

    if (duration.inMinutes < 1) {
      _resetState();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Thời gian ngủ quá ngắn để phân tích!")),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    int minutes = duration.inMinutes;
    int score = ((minutes / 480) * 100).toInt(); // 8 tiếng = 100đ
    if (score > 100) score = 100;
    if (score < 0) score = 0;

    String durationText =
        "${duration.inHours}h ${duration.inMinutes.remainder(60)}p";

    // --- GỌI GEMINI AI ---
    String advice = "Đang phân tích...";
    try {
      final safetySettings = [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ];

      final model = GenerativeModel(
        model: 'gemini-2.5-flash', // Dùng bản 1.5 ổn định nhất
        apiKey: _apiKey,
        safetySettings: safetySettings,
      );

      String prompt =
          "Tôi vừa ngủ từ ${DateFormat('HH:mm').format(startTimeSafe)} đến ${DateFormat('HH:mm').format(endTime)} "
          "(Tổng thời gian: $durationText). "
          "Dựa trên thời gian ngủ này, hãy nhận xét ngắn gọn (dưới 30 từ) về chất lượng giấc ngủ. "
          "Ví dụ: Ngủ đủ, Ngủ quá ít, Ngủ muộn...";

      final response = await model.generateContent([Content.text(prompt)]);
      advice = response.text ?? "Giấc ngủ đã được ghi nhận.";
    } catch (e) {
      advice = "Lỗi kết nối AI, nhưng dữ liệu đã lưu.";
      print("AI Error: $e");
    }

    final sessionData = {
      'start': startTimeSafe.millisecondsSinceEpoch,
      'end': endTime.millisecondsSinceEpoch,
      'duration_minutes': minutes,
      'duration_text': durationText,
      'score': score,
      'advice': advice,
      'date': DateFormat('dd/MM/yyyy').format(endTime),
    };

    // Lưu Firebase
    await _dbRef
        .child(
          'users/${user!.uid}/health_data/sleep_history/${endTime.millisecondsSinceEpoch}',
        )
        .set(sessionData);
    await _dbRef
        .child('users/${user!.uid}/health_data/sleep_latest')
        .set(sessionData);
    await _dbRef.child('users/${user!.uid}/health_data/sleep_status').set({
      'is_sleeping': false,
    });

    if (mounted) {
      setState(() {
        _isAnalyzing = false;
        _isSleeping = false;
      });
    }
  }

  void _resetState() {
    setState(() {
      _isSleeping = false;
      _startTime = null;
      _elapsedTime = "00:00:00";
    });
    _dbRef.child('users/${user!.uid}/health_data/sleep_status').set({
      'is_sleeping': false,
    });
  }

  // --- HÀM CHẠY DEMO GIẢ LẬP ---
  void _runDemoSleep() {
    // Giả lập thời gian bắt đầu là 7 tiếng 24 phút trước
    final now = DateTime.now();
    final demoStart = now.subtract(const Duration(hours: 7, minutes: 24));

    setState(() {
      _startTime = demoStart;
      _isSleeping = true;
    });

    // Gọi hàm thức dậy ngay lập tức để tính toán
    _wakeUp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text(
          "Giấc ngủ & Hồi phục",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Đồng hồ
            Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isSleeping
                      ? Colors.tealAccent
                      : Colors.purpleAccent.withOpacity(0.5),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isSleeping
                        ? Colors.tealAccent.withOpacity(0.3)
                        : Colors.purpleAccent.withOpacity(0.3),
                    blurRadius: 30,
                  ),
                ],
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isSleeping
                      ? [Colors.teal.shade900, Colors.black]
                      : [Colors.deepPurple.shade900, Colors.black],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isSleeping) ...[
                    const Icon(
                      FontAwesomeIcons.moon,
                      color: Colors.tealAccent,
                      size: 40,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _elapsedTime,
                      style: GoogleFonts.robotoMono(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      "Đang ngủ...",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ] else ...[
                    Text(
                      _lastScore,
                      style: GoogleFonts.poppins(
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      "Điểm giấc ngủ",
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Lần cuối: $_lastDuration",
                      style: const TextStyle(
                        color: Colors.white30,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Nút bấm chính
            if (_isAnalyzing)
              const CircularProgressIndicator(color: Colors.tealAccent)
            else
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _isSleeping ? _wakeUp : _startSleep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSleeping
                        ? Colors.redAccent
                        : Colors.indigoAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  icon: Icon(
                    _isSleeping ? Icons.stop_circle : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  label: Text(
                    _isSleeping ? "Đánh thức (Dừng)" : "Bắt đầu ngủ",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 40),

            // Kết quả AI
            if (!_isSleeping && _lastScore != "--")
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(
                          FontAwesomeIcons.robot,
                          color: Colors.tealAccent,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Text(
                          "Phân tích từ AI",
                          style: TextStyle(
                            color: Colors.tealAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _aiAdvice,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.justify,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),
            // --- NÚT DEMO (Ẩn dưới cùng) ---
            TextButton(
              onPressed: _runDemoSleep,
              child: const Text(
                "⚡ Chạy Demo (7h 24p)",
                style: TextStyle(color: Colors.white24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
