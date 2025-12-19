import 'dart:io';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref();

  // KHÓA API GEMINI
  static const String apiKey = 'AIzaSyByrk3WkHBH2Iq8bS9F1DfIr39s0JCk1EA';

  void _updateWater(int glasses) {
    if (user != null) {
      dbRef.child('users/${user!.uid}/nutrition_stats').update({
        'water_glasses': glasses
      });
    }
  }

  void _updateCalorieGoal(int newGoal) {
    if (user != null) {
      dbRef.child('users/${user!.uid}/nutrition_stats').update({
        'calories_goal': newGoal
      });
    }
  }

  void _showEditGoalDialog(int currentGoal) {
    TextEditingController goalController = TextEditingController(text: currentGoal.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Đặt mục tiêu mới 🎯"),
        content: TextField(
          controller: goalController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Số Calo mục tiêu (kcal)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () {
              int? newGoal = int.tryParse(goalController.text);
              if (newGoal != null && newGoal > 0) {
                _updateCalorieGoal(newGoal);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5)),
            child: const Text("Lưu", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 50);

    if (image != null) {
      _analyzeFoodImage(File(image.path));
    }
  }

  Future<void> _analyzeFoodImage(File imageFile) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
      );

      final imageBytes = await imageFile.readAsBytes();
      final prompt = Content.multi([
        TextPart("Bạn là chuyên gia dinh dưỡng. Hãy nhìn ảnh món ăn này và trả về dữ liệu theo định dạng chính xác sau (không thêm text thừa):\n"
            "Tên món: [Tên món ăn]\n"
            "Calo: [Số lượng calo ước tính, chỉ ghi số]\n"
            "Đánh giá: [Tốt/Khá/Không tốt]\n"
            "Lời khuyên: [Lời khuyên ngắn gọn dưới 20 từ]\n"
            "Icon: [Chọn 1 trong: fastfood, local_cafe, wb_sunny, wb_twilight]"),
        DataPart('image/jpeg', imageBytes),
      ]);

      final response = await model.generateContent([prompt]);
      Navigator.pop(context);

      if (response.text != null) {
        _processAIResponse(response.text!);
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi phân tích: $e")));
    }
  }

  void _processAIResponse(String text) {
    String name = "Món ăn lạ";
    int calories = 0;
    String verdict = "Chưa rõ";
    String advice = "";
    String iconType = "fastfood";

    try {
      final lines = text.split('\n');
      for (var line in lines) {
        if (line.contains("Tên món:")) name = line.split(":")[1].trim();
        if (line.contains("Calo:")) calories = int.tryParse(line.split(":")[1].trim().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        if (line.contains("Đánh giá:")) verdict = line.split(":")[1].trim();
        if (line.contains("Lời khuyên:")) advice = line.split(":")[1].trim();
        if (line.contains("Icon:")) iconType = line.split(":")[1].trim();
      }
    } catch (e) {
      print("Lỗi parse: $e");
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Kết quả phân tích 📸"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Món: $name", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Row(children: [const Icon(Icons.local_fire_department, color: Colors.orange), const SizedBox(width: 5), Text("$calories kcal", style: const TextStyle(fontWeight: FontWeight.bold))]),
            const SizedBox(height: 5),
            Row(children: [const Icon(Icons.health_and_safety, color: Colors.green), const SizedBox(width: 5), Text(verdict)]),
            const SizedBox(height: 10),
            Text("💡 $advice", style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _saveMealToFirebase(name, calories, iconType);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5)),
            child: const Text("Thêm vào nhật ký", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveMealToFirebase(String name, int kcal, String icon) async {
    if (user == null) return;
    final userRef = dbRef.child('users/${user!.uid}/nutrition_stats');

    final snapshot = await userRef.child('calories_consumed').get();
    int currentCal = (snapshot.value as int?) ?? 0;

    await userRef.update({
      'calories_consumed': currentCal + kcal,
    });

    String newKey = DateTime.now().millisecondsSinceEpoch.toString();
    await userRef.child('meals/$newKey').set({
      'name': name,
      'kcal': kcal,
      'icon': icon,
      'timestamp': ServerValue.timestamp,
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã thêm món ăn thành công!")));
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Chụp ảnh mới'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Chọn từ thư viện'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getFormattedTime(int? timestamp) {
    if (timestamp == null) return "Ăn nhẹ";

    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    int hour = date.hour;

    String session = "Ăn nhẹ";
    if (hour >= 5 && hour <= 10) session = "Sáng";
    else if (hour >= 11 && hour <= 14) session = "Trưa";
    else if (hour >= 17 && hour <= 21) session = "Tối";

    String dateStr = "${date.day} tháng ${date.month}";

    return "$session, $dateStr";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text("Dinh dưỡng", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Color(0xFF00BFA5)),
            onPressed: _showImageSourceActionSheet,
          ),
        ],
      ),
      body: StreamBuilder<DatabaseEvent>(
          stream: user != null ? dbRef.child('users/${user!.uid}/nutrition_stats').onValue : const Stream.empty(),
          builder: (context, snapshot) {
            int waterGlasses = 0;
            int caloriesGoal = 2000;
            int caloriesConsumed = 0;
            Map meals = {};

            if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
              final data = snapshot.data!.snapshot.value as Map;
              waterGlasses = data['water_glasses'] ?? 0;
              caloriesGoal = data['calories_goal'] ?? 2000;
              caloriesConsumed = data['calories_consumed'] ?? 0;
              meals = data['meals'] ?? {};
            }

            int caloriesLeft = caloriesGoal - caloriesConsumed;
            double percent = (caloriesConsumed / caloriesGoal).clamp(0.0, 1.0);

            var sortedMeals = meals.entries.toList()
              ..sort((a, b) {
                int tsA = (a.value['timestamp'] as num?)?.toInt() ?? 0;
                int tsB = (b.value['timestamp'] as num?)?.toInt() ?? 0;
                return tsB.compareTo(tsA); // Giảm dần
              });

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildCalorieCounter(caloriesLeft, percent, caloriesGoal),
                  const SizedBox(height: 25),
                  _buildWaterTracker(waterGlasses),
                  const SizedBox(height: 25),

                  if (meals.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text("Chưa có bữa ăn nào. Bấm Camera để thêm!", style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ...sortedMeals.map((e) {
                      final m = e.value;
                      int? ts = (m['timestamp'] as num?)?.toInt();

                      // Sử dụng hàm format mới
                      String timeDisplay = _getFormattedTime(ts);

                      return _buildMealSection(
                          m['name'] ?? "Bữa ăn",
                          "${m['kcal']} kcal",
                          timeDisplay,
                          _getIcon(m['icon']),
                          Colors.orange
                      );
                    }).toList(),
                ],
              ),
            );
          }
      ),
    );
  }

  IconData _getIcon(String? iconName) {
    if (iconName == 'wb_twilight') return Icons.wb_twilight;
    if (iconName == 'wb_sunny') return Icons.wb_sunny;
    if (iconName == 'local_cafe') return Icons.local_cafe;
    return Icons.fastfood;
  }

  Widget _buildCalorieCounter(int left, double percent, int goal) {
    bool isCompleted = left <= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Mục tiêu Calorie", style: TextStyle(fontSize: 16, color: Colors.grey)),
              IconButton(
                icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                onPressed: () => _showEditGoalDialog(goal),
              )
            ],
          ),
          const SizedBox(height: 20),
          CircularPercentIndicator(
            radius: 80.0,
            lineWidth: 12.0,
            percent: isCompleted ? 1.0 : percent,
            center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: isCompleted
                    ? [
                  const Icon(Icons.check_circle, color: Color(0xFF00BFA5), size: 40),
                  const Text("Hoàn thành!", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
                ]
                    : [
                  const Text("Còn lại", style: TextStyle(color: Colors.grey)),
                  Text("$left", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const Text("kcal", style: TextStyle(color: Colors.grey))
                ]
            ),
            progressColor: isCompleted ? Colors.green : const Color(0xFF00BFA5),
            backgroundColor: Colors.grey.shade200,
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
            animateFromLastPercent: true,
          ),

          const SizedBox(height: 20),

          if (isCompleted)
            ElevatedButton.icon(
              onPressed: () => _showEditGoalDialog(goal),
              icon: const Icon(Icons.refresh),
              label: const Text("Đặt mục tiêu mới"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMacroItem("Đạm", "80g", 0.6, Colors.purple),
                _buildMacroItem("Đường", "120g", 0.4, Colors.blue),
                _buildMacroItem("Béo", "40g", 0.3, Colors.redAccent),
              ],
            )
        ],
      ),
    );
  }

  Widget _buildMacroItem(String label, String value, double percent, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 5),
          SizedBox(width: 60, child: LinearProgressIndicator(value: percent, color: color, backgroundColor: color.withOpacity(0.2), minHeight: 6, borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildWaterTracker(int currentGlasses) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(children: [Icon(FontAwesomeIcons.glassWater, color: Colors.blue), SizedBox(width: 10), Text("Nước uống", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
              Text("${currentGlasses * 250} ml", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 15, runSpacing: 15,
            children: List.generate(14, (index) {
              bool isSelected = index < currentGlasses;
              return Icon(FontAwesomeIcons.glassWater, color: isSelected ? Colors.blueAccent : Colors.blue.withOpacity(0.2), size: 30);
            }),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingActionButton.small(heroTag: "btn_minus", onPressed: () => _updateWater(currentGlasses > 0 ? currentGlasses - 1 : 0), backgroundColor: Colors.white, child: const Icon(Icons.remove, color: Colors.blue)),
              const SizedBox(width: 20),
              FloatingActionButton.small(heroTag: "btn_plus", onPressed: () => _updateWater(currentGlasses < 14 ? currentGlasses + 1 : 14), backgroundColor: Colors.blue, child: const Icon(Icons.add, color: Colors.white)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMealSection(String name, String kcal, String headerInfo, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24)
          ),
          const SizedBox(width: 15),
          Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headerInfo.toUpperCase(),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(kcal, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
                    ],
                  ),
                ],
              )
          ),
        ],
      ),
    );
  }
}