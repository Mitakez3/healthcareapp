import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

// --- IMPORT CÁC MÀN HÌNH CHỨC NĂNG ---
import '../activity/sleep_screen.dart';
import '../activity/workout_schedule_screen.dart'; // Chứa cả Planner
import '../health/bmi_screen.dart';
import '../../services/gps_service.dart';

// Style Zepp Life
class ZeppStyle {
  static const Color primaryOrange = Color(0xFFFF6B00);
  static const Color lightOrange = Color(0xFFFF9E40);
  static const Color bgGrey = Color(0xFFF5F5F5);
  static const Color textDark = Color(0xFF333333);
  static const Color sleepPurple = Color(0xFF7E57C2);
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final GPSService _gpsService = GPSService();

  bool _isTracking = false;

  void _toggleTracking() {
    setState(() {
      _isTracking = !_isTracking;
    });
    if (_isTracking) {
      _gpsService.startTracking();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🚀 GPS Tracking: Đã bật!")));
    } else {
      _gpsService.stopTracking();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã dừng theo dõi.")));
    }
  }

  // Hàm tính PAI dựa trên dữ liệu thật
  int _calculateRealPAI(int steps, double sleep) {
    double stepScore = (steps / 6000) * 50;
    double sleepScore = (sleep / 8.0) * 50;
    int total = (stepScore + sleepScore).toInt();
    return total > 100 ? 100 : total;
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Scaffold(body: Center(child: Text("Vui lòng đăng nhập")));

    return Scaffold(
      backgroundColor: ZeppStyle.bgGrey,
      body: StreamBuilder<DatabaseEvent>(
        stream: _dbRef.child('users/${user!.uid}').onValue,
        builder: (context, snapshot) {
          // --- 1. KHỞI TẠO GIÁ TRỊ MẶC ĐỊNH ---
          String firstName = "User";
          int steps = 0, calories = 0;
          double distanceKm = 0.0;
          double sleepHours = 0.0;
          String stress = "Chưa có";
          double weight = 0.0;
          double height = 0.0;
          List<Map<String, dynamic>> workouts = [];
          Map userProfile = {}; // Lưu profile để truyền sang BMI Screen

          // --- 2. PARSE DỮ LIỆU TỪ FIREBASE ---
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final data = snapshot.data!.snapshot.value as Map;
            final profile = data['profile'] ?? {};
            final health = data['health_data'] ?? {};

            userProfile = profile; // Lưu lại map profile

            // Thông tin cá nhân
            firstName = (profile['fullName'] ?? user!.displayName ?? "User").trim().split(" ").last;

            // Lấy Cân nặng & Chiều cao từ Profile (Đồng bộ với BMI Screen)
            weight = (profile['weight'] as num?)?.toDouble() ?? 0.0;
            height = (profile['height'] as num?)?.toDouble() ?? 0.0;

            // Health Data (Dữ liệu thật)
            steps = (health['steps'] as num?)?.toInt() ?? 0;
            calories = (health['calories'] as num?)?.toInt() ?? 0;
            int distMeters = (health['distance'] as num?)?.toInt() ?? 0;
            distanceKm = distMeters / 1000;

            // Lấy dữ liệu ngủ mới nhất nếu có
            if (health['sleep_latest'] != null) {
              // Nếu có dữ liệu phiên ngủ chi tiết
              int sleepMins = (health['sleep_latest']['duration_minutes'] as num?)?.toInt() ?? 0;
              sleepHours = sleepMins / 60.0;
            } else {
              // Fallback dữ liệu cũ
              sleepHours = (health['sleep_hours'] as num?)?.toDouble() ?? 0.0;
            }

            stress = health['stress_level'] ?? "Bình thường";

            // Lịch sử tập luyện
            final historyData = data['activity_history'];
            workouts = _parseHistory(historyData);
          }

          // Tính toán PAI thật
          int paiScore = _calculateRealPAI(steps, sleepHours);

          return Stack(
            children: [
              // Header Cam Gradient
              Container(
                height: 220,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [ZeppStyle.lightOrange, ZeppStyle.primaryOrange],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
              ),

              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Xin chào
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Health AI", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                                Text("Chào, $firstName 👋", style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            GestureDetector(
                              onTap: _toggleTracking,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                                child: Icon(_isTracking ? Icons.stop_circle : Icons.play_arrow_rounded, color: Colors.white, size: 32),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 1. STEPS (Dữ liệu thật)
                      _buildStepsCard(steps, distanceKm, calories),
                      const SizedBox(height: 12),

                      // 2. SLEEP (Bấm vào để mở SleepScreen)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const SleepScreen()));
                        },
                        child: _buildSleepCard(sleepHours),
                      ),
                      const SizedBox(height: 12),

                      // 3. PAI (AI Score)
                      _buildPAICard(paiScore),
                      const SizedBox(height: 12),

                      // 4. WORKOUT HISTORY (Bấm vào để mở WorkoutSchedule/Planner)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const WorkoutScheduleScreen()));
                        },
                        child: _buildWorkoutHistoryCard(workouts),
                      ),
                      const SizedBox(height: 12),

                      // 5. WEIGHT & BODY SCORE (Bấm vào để mở BMIScreen)
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => BMIScreen(userProfile: userProfile)));
                              },
                              child: _buildWeightCard(weight),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => BMIScreen(userProfile: userProfile)));
                              },
                              child: _buildBodyScoreCard(paiScore),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 6. STRESS
                      _buildStressCard(stress),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- HÀM XỬ LÝ DỮ LIỆU LỊCH SỬ ---
  List<Map<String, dynamic>> _parseHistory(dynamic historyData) {
    List<Map<String, dynamic>> list = [];
    if (historyData != null) {
      if (historyData is List) {
        for (var item in historyData) {
          if (item != null) list.add(Map<String, dynamic>.from(item));
        }
      } else if (historyData is Map) {
        historyData.forEach((key, value) {
          list.add(Map<String, dynamic>.from(value));
        });
      }
    }
    // Sắp xếp mới nhất lên đầu & lấy 2 cái
    list.sort((a, b) => (b['time'] ?? 0).compareTo(a['time'] ?? 0));
    return list.take(2).toList();
  }

  // --- UI COMPONENTS ---

  Widget _buildStepsCard(int steps, double distKm, int calories) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Bước chân", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ZeppStyle.textDark)),
          const SizedBox(height: 15),
          Row(
            children: [
              CircularPercentIndicator(
                radius: 55.0, lineWidth: 10.0,
                percent: (steps / 6000).clamp(0.0, 1.0),
                center: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(FontAwesomeIcons.shoePrints, color: ZeppStyle.primaryOrange, size: 20),
                    const SizedBox(height: 5),
                    Text("$steps", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: ZeppStyle.textDark)),
                  ],
                ),
                progressColor: ZeppStyle.primaryOrange, backgroundColor: Colors.orange.shade100, circularStrokeCap: CircularStrokeCap.round,
              ),
              const SizedBox(width: 25),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMiniInfo("Khoảng cách", "${distKm.toStringAsFixed(2)} km"),
                  const SizedBox(height: 15),
                  _buildMiniInfo("Calo tiêu thụ", "$calories kcal"),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMiniInfo(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      Text(value, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
    ]);
  }

  Widget _buildSleepCard(double hours) {
    int h = hours.floor();
    int m = ((hours - h) * 60).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Giấc ngủ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Text(DateFormat('dd/MM').format(DateTime.now()), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(FontAwesomeIcons.solidMoon, color: ZeppStyle.sleepPurple, size: 20),
              const SizedBox(width: 10),
              Text("${h}h ${m}m", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(10, (index) => Container(
                width: 20,
                height: 20.0 + (index * 5 % 30),
                decoration: BoxDecoration(color: ZeppStyle.sleepPurple.withOpacity(index % 2 == 0 ? 1 : 0.4), borderRadius: BorderRadius.circular(4)),
              )),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPAICard(int score) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 70, height: 70,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Colors.orangeAccent, Colors.deepOrange])),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("$score", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                  const Text("PAI", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Điểm sức khỏe AI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 5),
                Text(score > 80 ? "Tuyệt vời! Duy trì nhé." : "Cần vận động thêm!", style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildWorkoutHistoryCard(List<Map<String, dynamic>> workouts) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Lịch sử tập luyện", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: ZeppStyle.primaryOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Text("Lập kế hoạch +", style: TextStyle(fontSize: 12, color: ZeppStyle.primaryOrange, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (workouts.isEmpty)
            const Center(child: Text("Chưa có dữ liệu. Bấm để lập lịch tập ngay!", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)))
          else
            ...workouts.map((w) {
              DateTime date = DateTime.fromMillisecondsSinceEpoch(w['time']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const CircleAvatar(backgroundColor: Color(0xFFFFF3E0), radius: 18, child: Icon(Icons.directions_run, color: Colors.orange, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(w['title'] ?? "Vận động", style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(DateFormat('dd/MM HH:mm').format(date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Text(w['stat'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildWeightCard(double weight) {
    return Container(
      height: 130, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Cân nặng", style: TextStyle(fontWeight: FontWeight.w600)),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("$weight", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const Text("kg", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  if (weight == 0) const Text("(Bấm cập nhật)", style: TextStyle(fontSize: 10, color: Colors.blue)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBodyScoreCard(int pai) {
    return Container(
      height: 130, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("BMI Status", style: TextStyle(fontWeight: FontWeight.w600)),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(pai > 50 ? Icons.sentiment_satisfied_alt : Icons.sentiment_neutral, color: pai > 50 ? Colors.green : Colors.amber, size: 36),
                  const SizedBox(height: 5),
                  Text("Chi tiết >", style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStressCard(String stress) {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Mức độ Stress", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 15),
          Center(
            child: Text(stress, style: TextStyle(color: stress == "Cao" ? Colors.red : Colors.green, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 5),
          const Center(child: Text("Đo lần cuối: Vừa xong", style: TextStyle(color: Colors.grey, fontSize: 12))),
        ],
      ),
    );
  }
}