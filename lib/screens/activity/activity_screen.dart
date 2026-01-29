import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
// Import quan trọng
import 'package:intl/date_symbol_data_local.dart';
import 'leaderboard_screen.dart';
import '../../services/gps_service.dart'; // Import GPS Service

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  // --- BIẾN CHO PHẦN TRACKING MỚI ---
  final GPSService _gpsService = GPSService();
  bool _isTracking = false;
  int _selectedModeIndex = 0; // 0: Walking, 1: Running, 2: Cycling

  final List<Map<String, dynamic>> _modes = [
    {"name": "Walking", "vi": "Đi bộ", "icon": FontAwesomeIcons.personWalking},
    {"name": "Running", "vi": "Chạy bộ", "icon": FontAwesomeIcons.personRunning},
    {"name": "Cycling", "vi": "Đạp xe", "icon": FontAwesomeIcons.bicycle},
  ];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('vi', null);
  }

  // Hàm xử lý nút GO
  void _onGoPressed() {
    setState(() {
      _isTracking = !_isTracking;
    });

    if (_isTracking) {
      // Bắt đầu Tracking
      // Bắt đầu Tracking
      String type = 'walk';
      String title = 'Đi bộ';

      if (_selectedModeIndex == 1) {
        type = 'run';
        title = 'Chạy bộ';
      } else if (_selectedModeIndex == 2) {
        type = 'cycle';
        title = 'Đạp xe';
      }

      _gpsService.startTracking(type: type, title: title);
      // Hiện tại code này sẽ chạy GPS mặc định.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bắt đầu ${_modes[_selectedModeIndex]['vi']}! 🚀")),
      );
    } else {
      // Dừng Tracking
      _gpsService.stopTracking();
      // Ở đây chúng ta sẽ giả lập cập nhật lại title cho record vừa xong nếu cần
      // Hoặc đơn giản là thông báo đã dừng.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã kết thúc buổi tập.")),
      );
    }
  }

  String _getFriendlyTime(int timestamp) {
    if (timestamp == 0) return "";
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final DateTime now = DateTime.now();
    final DateFormat timeFormatter = DateFormat('HH:mm');
    final String timeString = timeFormatter.format(date);

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return "Hôm nay, $timeString";
    }
    return "${date.day}/${date.month}, $timeString";
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final DatabaseReference dbRef = FirebaseDatabase.instance.ref();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      // Xóa AppBar mặc định để làm giao diện Full màn hình xanh như Zepp
      body: StreamBuilder<DatabaseEvent>(
        stream: user != null ? dbRef.child('users/${user.uid}').onValue : const Stream.empty(),
        builder: (context, snapshot) {
          int steps = 0;
          int distance = 0;
          int calories = 0;
          List<Map<String, dynamic>> historyList = [];

          // Dữ liệu Realtime cho phần Header
          double currentDistKm = 0.0;

          // Mảng chứa dữ liệu biểu đồ tuần
          List<double> weeklyChartData = List.filled(7, 0.0);
          List<String> weekDays = List.filled(7, "");

          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final data = snapshot.data!.snapshot.value as Map;
            final health = data['health_data'] ?? {};

            // Lấy dữ liệu tổng quan
            steps = (health['steps'] as num?)?.toInt() ?? 0;
            calories = (health['calories'] as num?)?.toInt() ?? 0;
            distance = (health['distance'] as num?)?.toInt() ?? 0;
            currentDistKm = distance / 1000.0;

            // Parse Lịch sử hoạt động
            final historyData = data['activity_history'];
            if (historyData != null) {
              if (historyData is List) {
                for (var item in historyData) {
                  if (item != null) historyList.add(Map<String, dynamic>.from(item));
                }
              } else if (historyData is Map) {
                historyData.forEach((key, value) {
                  historyList.add(Map<String, dynamic>.from(value));
                });
              }
              historyList = historyList.reversed.toList();
            }

            // Parse Biểu đồ (Giữ nguyên logic cũ của bạn)
            final dailyStepsMap = data['daily_steps'] ?? {};
            DateTime now = DateTime.now();
            for (int i = 0; i < 7; i++) {
              DateTime day = now.subtract(Duration(days: 6 - i));
              String key = DateFormat('yyyy-MM-dd').format(day);
              weekDays[i] = DateFormat('E', 'vi').format(day);
              if (dailyStepsMap[key] != null) {
                weeklyChartData[i] = (dailyStepsMap[key] as num).toDouble();
              } else if (i == 6) { // Hôm nay
                weeklyChartData[i] = steps.toDouble();
              }
            }
          }

          return SingleChildScrollView(
            // Không dùng padding ở đây để phần màu xanh tràn viền
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. PHẦN GIAO DIỆN MỚI (ZEPP STYLE) ---
                _buildTopTrackingSection(currentDistKm),

                // --- 2. PHẦN GIAO DIỆN CŨ (GIỮ NGUYÊN) ---
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWeeklyChartCard(weeklyChartData, weekDays),
                      const SizedBox(height: 20),

                      const Text("Thống kê hôm nay", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),

                      Row(
                        children: [
                          Expanded(child: _buildStatCard("Calorie", "$calories", "cal", FontAwesomeIcons.fire, Colors.orange)),
                          const SizedBox(width: 15),
                          Expanded(child: _buildStatCard("Thời gian", "${(steps * 0.01).toInt()}", "phút", FontAwesomeIcons.stopwatch, Colors.blue)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(child: _buildStatCard("Khoảng cách", "$distance", "m", FontAwesomeIcons.route, Colors.green)),
                          const SizedBox(width: 15),
                          Expanded(child: _buildStatCard("Số bước", "$steps", "bước", FontAwesomeIcons.shoePrints, Colors.teal)),
                        ],
                      ),

                      const SizedBox(height: 25),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Lịch sử hoạt động", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(FontAwesomeIcons.trophy, color: Colors.orange, size: 20),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardScreen())),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (historyList.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Chưa có lịch sử hoạt động", style: TextStyle(color: Colors.grey))))
                      else
                        Column(
                          children: historyList.map((item) {
                            dynamic rawTime = item['time'];
                            String timeDisplay = (rawTime is num) ? _getFriendlyTime(rawTime.toInt()) : rawTime.toString();
                            return _buildActivityItem(
                              item['title'] ?? "Hoạt động",
                              timeDisplay,
                              item['stat']?.toString() ?? "",
                              _getTypeIcon(item['type']),
                              _getTypeColor(item['type']),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 80), // Padding bottom
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET: HEADER GIAO DIỆN ZEPP LIFE ---
  Widget _buildTopTrackingSection(double currentDistKm) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF00D180), // Màu xanh Zepp Life
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            // 1. Tab Chọn chế độ (Walking / Running / Cycling)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_modes.length, (index) {
                bool isSelected = _selectedModeIndex == index;
                return GestureDetector(
                  onTap: () {
                    if (!_isTracking) setState(() => _selectedModeIndex = index);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Column(
                      children: [
                        Text(
                          _modes[index]['name'],
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(isSelected ? 1 : 0.6),
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (isSelected)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 20, height: 3,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
                          )
                      ],
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 30),

            // 2. Số đo khoảng cách lớn
            Text(
              currentDistKm.toStringAsFixed(2),
              style: GoogleFonts.oswald(fontSize: 70, color: Colors.white, fontWeight: FontWeight.w500, height: 1),
            ),
            const Text(
              "km",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 20),

            // Text phụ: "Total fitness distance"
            Text(
              "Total fitness ${_modes[_selectedModeIndex]['name'].toLowerCase()} distance >",
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),

            const SizedBox(height: 30),

            // 3. Card Map & Nút GO
            Stack(
              alignment: Alignment.topCenter,
              children: [
                // Khối nền trắng bo góc mô phỏng Map Card
                Container(
                  height: 140,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                    child: Stack(
                      children: [
                        // Ảnh Map giả lập (Placeholder)
                        Opacity(
                          opacity: 0.3,
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: Colors.grey[200],
                            child: const Center(child: Icon(Icons.map, size: 80, color: Colors.grey)),
                          ),
                        ),
                        // Thông tin GPS nhỏ
                        Positioned(
                          left: 15, top: 15,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                            child: const Row(
                              children: [
                                Icon(Icons.gps_fixed, size: 12, color: Colors.grey),
                                SizedBox(width: 5),
                                Text("GPS Ready", style: TextStyle(fontSize: 10, color: Colors.black87)),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),

                // NÚT GO TRÒN MÀU CAM (Nằm đè lên trên)
                GestureDetector(
                  onTap: _onGoPressed,
                  child: Container(
                    margin: const EdgeInsets.only(top: 80), // Đẩy xuống một chút để nằm giữa border
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5722), // Màu cam đậm
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFFF5722).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5)),
                        const BoxShadow(color: Colors.white, blurRadius: 0, spreadRadius: 4), // Viền trắng
                      ],
                    ),
                    child: Center(
                      child: _isTracking
                          ? const Icon(Icons.pause, color: Colors.white, size: 32)
                          : Text("GO", style: GoogleFonts.oswald(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- CÁC WIDGET CŨ (GIỮ NGUYÊN LOGIC) ---

  Widget _buildWeeklyChartCard(List<double> data, List<String> days) {
    double maxVal = 1000;
    if (data.isNotEmpty) maxVal = data.reduce((curr, next) => curr > next ? curr : next);
    if (maxVal < 1000) maxVal = 1000;

    return Container(
      height: 250, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Bước chân 7 ngày qua", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < days.length) {
                          return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(days[index], style: const TextStyle(fontSize: 10, color: Colors.grey)));
                        }
                        return const Text("");
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(data.length, (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: data[index],
                        gradient: const LinearGradient(colors: [Color(0xFF00BFA5), Color(0xFF64FFDA)]),
                        width: 14, borderRadius: BorderRadius.circular(8),
                        backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxVal * 1.2, color: Colors.grey.shade100),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text("$unit • $title", style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, String stat, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(time, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ],
            ),
          ),
          Text(stat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case 'run': return FontAwesomeIcons.personRunning;
      case 'walk': return FontAwesomeIcons.personWalking;
      case 'cycle': return FontAwesomeIcons.bicycle;
      case 'yoga': return FontAwesomeIcons.spa;
      default: return FontAwesomeIcons.bolt;
    }
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'run': return Colors.orange;
      case 'walk': return Colors.teal;
      case 'cycle': return Colors.blue;
      case 'yoga': return Colors.purple;
      default: return Colors.grey;
    }
  }
}