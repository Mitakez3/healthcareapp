import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'workout_planner_screen.dart';

class WorkoutScheduleScreen extends StatelessWidget {
  const WorkoutScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final DatabaseReference dbRef = FirebaseDatabase.instance.ref();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text("Kế hoạch tập luyện", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Nút tạo mới
          IconButton(
            icon: const Icon(Icons.edit_calendar, color: Color(0xFF00BFA5)),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const WorkoutPlannerScreen())
              );
            },
          )
        ],
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: dbRef.child('users/${user!.uid}/workout_plan').onValue,
        builder: (context, snapshot) {
          // Nếu đang tải
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Nếu chưa có dữ liệu
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return _buildEmptyState(context);
          }

          // Có dữ liệu -> Parse và hiển thị
          final data = snapshot.data!.snapshot.value as Map;
          final String goal = data['goal'] ?? "Mục tiêu";
          final String planContent = data['plan'] ?? "";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thẻ Mục tiêu
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF00BFA5), Color(0xFF64FFDA)]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: const Color(0xFF00BFA5).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Mục tiêu hiện tại", style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 5),
                      Text(goal.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

                const SizedBox(height: 25),
                const Text("Lịch trình chi tiết", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),

                // Nội dung Plan
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    planContent,
                    style: GoogleFonts.roboto(fontSize: 16, height: 1.6, color: Colors.black87),
                  ),
                ),

                const SizedBox(height: 30),

                // Nút Hoàn thành kế hoạch
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      // Xóa kế hoạch khỏi Firebase
                      await dbRef.child('users/${user.uid}/workout_plan').remove();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã hoàn thành kế hoạch!")));
                    },
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    label: const Text("Kết thúc kế hoạch này", style: TextStyle(color: Colors.green, fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(FontAwesomeIcons.clipboardList, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text("Bạn chưa có lịch tập nào", style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const WorkoutPlannerScreen()));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA5),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
            ),
            child: const Text("Tạo lịch với AI ngay", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}