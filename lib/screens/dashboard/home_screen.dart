import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Hôm nay", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),

            // Thẻ chính: Vận động
            _buildMainHealthCard(),

            SizedBox(height: 15),

            // Grid các chỉ số sinh trắc học
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.4,
              children: [
                _buildInfoCard("Nhịp tim", "78 bpm", Icons.favorite, Colors.red),
                _buildInfoCard("Giấc ngủ", "7h 30m", Icons.bedtime, Colors.purple),
                _buildInfoCard("Căng thẳng", "Thấp", Icons.sentiment_satisfied, Colors.green),
                _buildInfoCard("SpO2", "98%", Icons.water_drop, Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainHealthCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Số bước chân", style: TextStyle(fontSize: 16, color: Colors.grey)),
              Text("4,250", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              Text("Mục tiêu: 6,000", style: TextStyle(color: Colors.teal)),
            ],
          ),
          CircularPercentIndicator(
            radius: 50.0,
            lineWidth: 10.0,
            percent: 0.7,
            center: Icon(Icons.directions_walk, size: 30, color: Colors.teal),
            progressColor: Colors.teal,
            backgroundColor: Colors.teal.shade100,
            circularStrokeCap: CircularStrokeCap.round,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}