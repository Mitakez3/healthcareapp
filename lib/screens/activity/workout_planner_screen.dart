import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'workout_schedule_screen.dart';

class WorkoutPlannerScreen extends StatefulWidget {
  const WorkoutPlannerScreen({super.key});

  @override
  State<WorkoutPlannerScreen> createState() => _WorkoutPlannerScreenState();
}

class _WorkoutPlannerScreenState extends State<WorkoutPlannerScreen> {
  final TextEditingController _goalController = TextEditingController();
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref();

  bool _isLoading = false;
  String? _resultPlan;

  static const String apiKey = 'AIzaSyByrk3WkHBH2Iq8bS9F1DfIr39s0JCk1EA';

  Future<void> _generatePlan() async {
    if (_goalController.text.isEmpty) return;
    setState(() { _isLoading = true; _resultPlan = null; });

    try {
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
      final prompt = "Tôi muốn tập luyện với mục tiêu: '${_goalController.text}'. "
          "Hãy lập kế hoạch 3-5 ngày ngắn gọn. Định dạng trả về có Emoji đầu dòng. "
          "Không cần phần mở đầu/kết bài, chỉ cần nội dung chính.";

      final response = await model.generateContent([Content.text(prompt)]);

      setState(() {
        _resultPlan = response.text;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; _resultPlan = "Lỗi kết nối AI."; });
    }
  }

  Future<void> _saveToFirebase() async {
    if (user == null || _resultPlan == null) return;

    try {
      // Lưu vào node: users/{uid}/workout_plan
      await dbRef.child('users/${user!.uid}/workout_plan').set({
        'goal': _goalController.text,
        'plan': _resultPlan,
        'created_at': ServerValue.timestamp,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã lưu lịch tập!")));
        // Chuyển ngay sang màn hình xem lịch
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const WorkoutScheduleScreen())
        );
      }
    } catch (e) {
      print("Lỗi lưu: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text("Tạo lịch tập mới"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _goalController,
              decoration: InputDecoration(
                hintText: "Nhập mục tiêu (VD: Giảm 2kg, Yoga...)",
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF00BFA5)),
                  onPressed: _generatePlan,
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_isLoading)
              const CircularProgressIndicator()
            else if (_resultPlan != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                child: Column(
                  children: [
                    Text(_resultPlan!, style: GoogleFonts.roboto(fontSize: 15, height: 1.5)),
                    const SizedBox(height: 20),
                    // Nút Lưu vào Firebase
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveToFirebase,
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text("Lưu & Theo dõi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5)),
                      ),
                    )
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}