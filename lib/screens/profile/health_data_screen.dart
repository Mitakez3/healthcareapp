import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HealthDataScreen extends StatelessWidget {
  const HealthDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text("Dữ liệu sức khỏe"), centerTitle: true),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('users/${user!.uid}/health_data').onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(child: Text("Chưa có dữ liệu sức khỏe"));
          }
          final data = snapshot.data!.snapshot.value as Map;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildItem("Nhịp tim", "${data['heart_rate'] ?? 0} bpm", FontAwesomeIcons.heartPulse, Colors.red),
              _buildItem("Bước chân", "${data['steps'] ?? 0} bước", FontAwesomeIcons.personWalking, Colors.orange),
              _buildItem("Giấc ngủ", "${data['sleep_hours'] ?? 0} giờ", FontAwesomeIcons.moon, Colors.indigo),
              _buildItem("Stress", "${data['stress_level'] ?? 'N/A'}", FontAwesomeIcons.faceTired, Colors.purple),
              _buildItem("Quãng đường", "${data['distance'] ?? 0} m", FontAwesomeIcons.route, Colors.green),
              _buildItem("Calories", "${data['calories'] ?? 0} kcal", FontAwesomeIcons.fire, Colors.deepOrange),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItem(String title, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 20)),
        title: Text(title),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}