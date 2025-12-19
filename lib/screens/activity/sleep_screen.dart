import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("Giấc ngủ & Hồi phục", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tổng quan điểm số
            Center(
              child: Column(
                children: [
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.purpleAccent.withOpacity(0.5), width: 4),
                      boxShadow: [
                        BoxShadow(color: Colors.purpleAccent.withOpacity(0.3), blurRadius: 20)
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("85", style: GoogleFonts.poppins(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                        const Text("Chất lượng", style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("Ngủ rất ngon! 💤", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  const Text("Bạn đã ngủ đủ 5 chu kỳ giấc ngủ.", style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Biểu đồ giấc ngủ
            const Text("Biểu đồ chu kỳ ngủ", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Container(
              height: 200,
              padding: const EdgeInsets.only(right: 20, top: 10, bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  minX: 0, maxX: 7,
                  minY: 0, maxY: 4,
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [
                        FlSpot(0, 3), FlSpot(1, 1), FlSpot(1.5, 2), FlSpot(2.5, 0), // 0: Deep, 3: Awake
                        FlSpot(3.5, 1), FlSpot(4.5, 2), FlSpot(5.5, 0), FlSpot(6, 1), FlSpot(7, 3),
                      ],
                      isCurved: true,
                      color: Colors.purpleAccent,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.purpleAccent.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _LegendItem(color: Colors.purpleAccent, label: "Sâu"),
                _LegendItem(color: Colors.white30, label: "Nhẹ"),
                _LegendItem(color: Colors.white70, label: "REM"),
              ],
            ),

            const SizedBox(height: 30),

            // Grid thông tin chi tiết
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.5,
              children: [
                _buildSleepInfoCard("Ngủ sâu", "2h 15m", FontAwesomeIcons.bed, Colors.indigoAccent),
                _buildSleepInfoCard("Ngủ nông", "4h 30m", FontAwesomeIcons.cloudMoon, Colors.blueAccent),
                _buildSleepInfoCard("Thức dậy", "15m", FontAwesomeIcons.eye, Colors.orangeAccent),
                _buildSleepInfoCard("Nhịp tim TB", "62 bpm", FontAwesomeIcons.heartPulse, Colors.pinkAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(radius: 4, backgroundColor: color),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}