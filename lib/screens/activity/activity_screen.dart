import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
// 1. IMPORT QUAN TRỌNG ĐỂ SỬA LỖI
import 'package:intl/date_symbol_data_local.dart';
import 'leaderboard_screen.dart';

// 2. CHUYỂN SANG STATEFUL WIDGET
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  // 3. KHỞI TẠO DỮ LIỆU TIẾNG VIỆT KHI MÀN HÌNH BẮT ĐẦU
  @override
  void initState() {
    super.initState();
    initializeDateFormatting('vi', null);
  }

  String _getFriendlyTime(int timestamp) {
    if (timestamp == 0) return "";

    final DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final DateTime now = DateTime.now();
    final DateFormat timeFormatter = DateFormat('HH:mm');
    final String timeString = timeFormatter.format(date);

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return "Hôm nay, $timeString";
    }

    final DateTime yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return "Hôm qua, $timeString";
    }

    return "${date.day}/${date.month}, $timeString";
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final DatabaseReference dbRef = FirebaseDatabase.instance.ref();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          "Vận động",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(FontAwesomeIcons.trophy, color: Colors.orange),
            tooltip: "Bảng xếp hạng",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LeaderboardScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: user != null
            ? dbRef.child('users/${user.uid}').onValue
            : const Stream.empty(),
        builder: (context, snapshot) {
          int steps = 0;
          int distance = 0;
          int calories = 0;
          List<Map<String, dynamic>> historyList = [];

          // Mảng chứa dữ liệu 7 ngày
          List<double> weeklyChartData = List.filled(7, 0.0);
          List<String> weekDays = List.filled(7, "");

          // Parse dữ liệu
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final data = snapshot.data!.snapshot.value as Map;

            // Parse Health Data
            final health = data['health_data'] ?? {};
            int lastUpdated = (health['timestamp'] as num?)?.toInt() ?? 0;
            bool isToday = false;
            if (lastUpdated > 0) {
              final DateTime date = DateTime.fromMillisecondsSinceEpoch(
                lastUpdated,
              );
              final DateTime now = DateTime.now();
              isToday =
                  (date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day);
            }

            if (isToday) {
              steps = (health['steps'] as num?)?.toInt() ?? 0;
              calories = (health['calories'] as num?)?.toInt() ?? 0;
              distance = (health['distance'] as num?)?.toInt() ?? 0;
            }

            // Parse Daily Steps (Biểu đồ)
            final dailyStepsMap = data['daily_steps'] ?? {};
            DateTime now = DateTime.now();

            for (int i = 0; i < 7; i++) {
              DateTime day = now.subtract(Duration(days: 6 - i));
              String key = DateFormat('yyyy-MM-dd').format(day);

              // Lấy thứ (T2, T3...)
              try {
                weekDays[i] = DateFormat('E', 'vi').format(day);
              } catch (e) {
                // Fallback nếu lỗi khởi tạo chưa chạy xong kịp
                weekDays[i] = DateFormat('E').format(day);
              }

              // Chuẩn hóa tên thứ tiếng Việt
              if (weekDays[i] == "Th 2" || weekDays[i] == "Mon")
                weekDays[i] = "T2";
              if (weekDays[i] == "Th 3" || weekDays[i] == "Tue")
                weekDays[i] = "T3";
              if (weekDays[i] == "Th 4" || weekDays[i] == "Wed")
                weekDays[i] = "T4";
              if (weekDays[i] == "Th 5" || weekDays[i] == "Thu")
                weekDays[i] = "T5";
              if (weekDays[i] == "Th 6" || weekDays[i] == "Fri")
                weekDays[i] = "T6";
              if (weekDays[i] == "Th 7" || weekDays[i] == "Sat")
                weekDays[i] = "T7";
              if (weekDays[i] == "CN" || weekDays[i] == "Sun")
                weekDays[i] = "CN";

              if (dailyStepsMap[key] != null) {
                weeklyChartData[i] = (dailyStepsMap[key] as num).toDouble();
              } else if (i == 6 && isToday) {
                weeklyChartData[i] = steps.toDouble();
              }
            }

            // Parse Activity History
            final historyData = data['activity_history'];
            if (historyData != null) {
              if (historyData is List) {
                for (var item in historyData) {
                  if (item != null)
                    historyList.add(Map<String, dynamic>.from(item));
                }
              } else if (historyData is Map) {
                historyData.forEach((key, value) {
                  historyList.add(Map<String, dynamic>.from(value));
                });
              }
              historyList = historyList.reversed.toList();
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWeeklyChartCard(weeklyChartData, weekDays),
                const SizedBox(height: 20),

                const Text(
                  "Thống kê hôm nay",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        "Calorie",
                        "$calories",
                        "cal",
                        FontAwesomeIcons.fire,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildStatCard(
                        "Thời gian",
                        "${(steps * 0.01).toInt()}",
                        "phút",
                        FontAwesomeIcons.stopwatch,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        "Khoảng cách",
                        "$distance",
                        "m",
                        FontAwesomeIcons.route,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildStatCard(
                        "Số bước",
                        "$steps",
                        "bước",
                        FontAwesomeIcons.shoePrints,
                        Colors.teal,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                const Text(
                  "Lịch sử hoạt động",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                if (historyList.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Center(
                      child: Text(
                        "Chưa có lịch sử hoạt động",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Column(
                    children: historyList.map((item) {
                      dynamic rawTime = item['time'];
                      String timeDisplay = "";
                      if (rawTime is num) {
                        timeDisplay = _getFriendlyTime(rawTime.toInt());
                      } else {
                        timeDisplay = rawTime.toString();
                      }

                      return _buildActivityItem(
                        item['title'] ?? "Hoạt động",
                        timeDisplay,
                        item['stat']?.toString() ?? "",
                        _getTypeIcon(item['type']),
                        _getTypeColor(item['type']),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case 'run':
        return FontAwesomeIcons.personRunning;
      case 'walk':
        return FontAwesomeIcons.personWalking;
      case 'cycle':
        return FontAwesomeIcons.bicycle;
      case 'yoga':
        return FontAwesomeIcons.spa;
      default:
        return FontAwesomeIcons.bolt;
    }
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'run':
        return Colors.orange;
      case 'walk':
        return Colors.teal;
      case 'cycle':
        return Colors.blue;
      case 'yoga':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildWeeklyChartCard(List<double> data, List<String> days) {
    double maxVal = 1000;
    if (data.isNotEmpty) {
      maxVal = data.reduce((curr, next) => curr > next ? curr : next);
    }
    if (maxVal < 1000) maxVal = 1000;

    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Bước chân 7 ngày qua",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
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
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              days[index],
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        }
                        return const Text("");
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(data.length, (index) {
                  return _makeGradientBar(index, data[index], maxVal * 1.2);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeGradientBar(int x, double y, double backgroundMax) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          gradient: const LinearGradient(
            colors: [Color(0xFF00BFA5), Color(0xFF64FFDA)],
          ),
          width: 14,
          borderRadius: BorderRadius.circular(8),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: backgroundMax,
            color: Colors.grey.shade100,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            "$unit • $title",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String time,
    String stat,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            stat,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
