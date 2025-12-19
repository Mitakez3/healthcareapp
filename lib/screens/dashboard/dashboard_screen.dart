import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../activity/sleep_screen.dart';
import '../activity/workout_schedule_screen.dart';
import '../wellness/breathing_screen.dart';
import '../../services/gps_service.dart';
import '../../app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  String get _currentDateString {
    final now = DateTime.now();
    return "Hôm nay, ${now.day} Th${now.month}";
  }

  final GPSService _gpsService = GPSService();
  bool _isTracking = false;

  void _toggleTracking() {
    setState(() {
      _isTracking = !_isTracking;
    });

    if (_isTracking) {
      _gpsService.startTracking();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã bật GPS! Hãy bắt đầu di chuyển.")));
    } else {
      _gpsService.stopTracking();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã dừng theo dõi.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Scaffold(body: Center(child: Text("Vui lòng đăng nhập")));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<DatabaseEvent>(
          stream: _dbRef.child('users/${user!.uid}').onValue,
          builder: (context, snapshot) {
            String firstName = "Bạn";
            int steps = 0, calories = 0, heartRate = 0;
            int distance = 0;
            double sleepHours = 0.0, water = 0.0;
            String stress = "Thấp";

            if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
              final data = snapshot.data!.snapshot.value as Map;
              final profile = data['profile'] ?? {};
              final health = data['health_data'] ?? {};

              firstName = (profile['fullName'] ?? user!.displayName ?? "User").trim().split(" ").last;

              steps = (health['steps'] as num?)?.toInt() ?? 0;
              calories = (health['calories'] as num?)?.toInt() ?? 0;
              heartRate = (health['heart_rate'] as num?)?.toInt() ?? 0;
              distance = (health['distance'] as num?)?.toInt() ?? 0;
              sleepHours = (health['sleep_hours'] as num?)?.toDouble() ?? 0.0;
              water = (health['water_liters'] as num?)?.toDouble() ?? 0.0;

              stress = health['stress_level'] ?? "Thấp";
            }

            return SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Xin chào, $firstName! 👋", style: AppStyles.header),
                            Text(_currentDateString, style: AppStyles.body),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 2),
                          ),
                          child: const CircleAvatar(
                            radius: 22,
                            backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=12'),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 15),
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _toggleTracking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isTracking ? Colors.redAccent : const Color(0xFF00BFA5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(_isTracking ? Icons.stop_circle : Icons.play_circle, color: Colors.white),
                        label: Text(
                          _isTracking ? "Dừng theo dõi GPS" : "Bắt đầu chạy bộ (GPS)",
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    _buildModernStepCard(steps, calories, distance),

                    const SizedBox(height: 25),
                    Text("Chỉ số cơ thể", style: AppStyles.title),
                    const SizedBox(height: 15),

                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                      children: [
                        _buildModernStatCard("Nhịp tim", "$heartRate", "bpm", FontAwesomeIcons.heartPulse, AppColors.red),

                        _buildModernStatCard(
                            "Giấc ngủ", "${sleepHours}h", "Hôm nay", FontAwesomeIcons.moon, Colors.indigo,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const SleepScreen()));
                            }
                        ),

                        _buildModernStatCard("Nước uống", "$water", "Lít", FontAwesomeIcons.glassWater, AppColors.blue),

                        _buildModernStatCard(
                            "Căng thẳng", stress, "", FontAwesomeIcons.faceSmile, AppColors.primary,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const BreathingScreen()));
                            }
                        ),

                        _buildModernStatCard(
                            "HLV Cá nhân",
                            "Lịch tập",
                            "",
                            FontAwesomeIcons.dumbbell,
                            Colors.orange,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const WorkoutScheduleScreen()));
                            }
                        ),
                      ],
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            );
          }
      ),
    );
  }

  Widget _buildModernStepCard(int steps, int cal, int dist) {
    double percent = (steps / 6000).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppStyles.cardDecoration.copyWith(
        color: AppColors.secondary,
        boxShadow: [
          BoxShadow(color: AppColors.secondary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Hoạt động", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text("$steps", style: GoogleFonts.poppins(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white, height: 1)),
                  const Text(" / 6000 bước", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ],
              ),
              CircularPercentIndicator(
                radius: 45.0,
                lineWidth: 8.0,
                percent: percent,
                backgroundColor: Colors.white10,
                progressColor: AppColors.primary,
                center: const Icon(FontAwesomeIcons.personRunning, color: Colors.white, size: 24),
                circularStrokeCap: CircularStrokeCap.round,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat(FontAwesomeIcons.fire, "$cal", "kcal"),
                Container(width: 1, height: 24, color: Colors.white24),
                _buildMiniStat(FontAwesomeIcons.locationDot, "$dist", "m"),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String val, String unit) {
    return Row(
      children: [
        Icon(icon, color: AppColors.orange, size: 16),
        const SizedBox(width: 8),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(text: "$val ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              TextSpan(text: unit, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildModernStatCard(
      String title, String value, String unit, IconData icon, Color color,
      {VoidCallback? onTap}
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppStyles.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppStyles.body.copyWith(fontSize: 13)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(value, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      if (unit.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(unit, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ),
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}