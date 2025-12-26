import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// --- CONFIG AI (GEMINI) ---
// Bạn nhớ thay API Key của bạn vào đây hoặc lấy từ file config chung
const String _apiKey = 'AIzaSyByrk3WkHBH2Iq8bS9F1DfIr39s0JCk1EA';

class BMIScreen extends StatefulWidget {
  final Map userProfile; // Truyền profile vào để lấy giới tính
  const BMIScreen({super.key, required this.userProfile});

  @override
  State<BMIScreen> createState() => _BMIScreenState();
}

class _BMIScreenState extends State<BMIScreen> {
  final _user = FirebaseAuth.instance.currentUser;
  final _dbRef = FirebaseDatabase.instance.ref();

  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  List<Map<dynamic, dynamic>> _history = [];
  bool _isLoading = false;
  String? _selectedGender; // Chỉ dùng nếu profile chưa có

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    // Lấy chiều cao/cân nặng gần nhất để điền sẵn
    if (widget.userProfile['height'] != null)
      _heightController.text = widget.userProfile['height'].toString();
    if (widget.userProfile['weight'] != null)
      _weightController.text = widget.userProfile['weight'].toString();
  }

  // 1. Lấy lịch sử từ Firebase
  void _fetchHistory() {
    if (_user == null) return;
    _dbRef.child('users/${_user!.uid}/health_data/bmi_history').onValue.listen((
      event,
    ) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        final List<Map<dynamic, dynamic>> loaded = [];
        data.forEach((key, value) {
          loaded.add({...value, 'key': key});
        });
        // Sắp xếp theo thời gian mới nhất
        loaded.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
        if (mounted) setState(() => _history = loaded);
      }
    });
  }

  // 2. Hàm tính toán và cập nhật BMI
  Future<void> _updateBMI() async {
    // Kiểm tra giới tính
    String gender = widget.userProfile['gender'] ?? _selectedGender;
    if (gender == null || gender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng chọn giới tính trước!")),
      );
      return;
    }

    double? h = double.tryParse(_heightController.text);
    double? w = double.tryParse(_weightController.text);

    if (h == null || w == null) return;

    setState(() => _isLoading = true);

    // Tính BMI
    double heightInM = h / 100;
    double bmi = w / (heightInM * heightInM);
    String bmiString = bmi.toStringAsFixed(1);

    // Chuẩn bị dữ liệu để hỏi AI
    String prompt = "";
    Map? lastEntry = _history.isNotEmpty ? _history.first : null;

    if (lastEntry == null) {
      // Lần đầu tiên
      prompt =
          "Tôi là $gender, BMI hiện tại là $bmiString. Hãy đưa ra nhận xét ngắn gọn và lời khuyên sức khỏe (dưới 30 từ).";
    } else {
      // Những lần sau: So sánh
      double lastBMI = double.parse(lastEntry['bmi'].toString());
      String diff = (bmi - lastBMI).toStringAsFixed(1);
      prompt =
          "Tôi là $gender. BMI hiện tại $bmiString (thay đổi $diff so với lần trước). Hãy nhận xét ngắn gọn về sự thay đổi này (dưới 30 từ).";
    }

    // Gọi Gemini AI
    String advice = "Đang phân tích...";
    try {
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      advice = response.text ?? "Không có lời khuyên.";
    } catch (e) {
      advice = "Lỗi kết nối AI, nhưng chỉ số của bạn đã được lưu.";
      print(e);
    }

    // Lưu vào Firebase
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final Map<String, dynamic> entry = {
      'bmi': bmiString,
      'weight': w,
      'height': h,
      'advice': advice,
      'timestamp': timestamp,
      'date': DateFormat('dd/MM/yyyy').format(DateTime.now()),
    };

    // Lưu lịch sử
    await _dbRef
        .child('users/${_user!.uid}/health_data/bmi_history/$timestamp')
        .set(entry);

    // Lưu thông tin mới nhất ra ngoài để hiện Dashboard nhanh
    await _dbRef
        .child('users/${_user!.uid}/health_data/bmi_latest')
        .set(bmiString);

    // Cập nhật Profile nếu chưa có
    if (widget.userProfile['gender'] == null) {
      await _dbRef.child('users/${_user!.uid}/profile/gender').set(gender);
    }
    await _dbRef.child('users/${_user!.uid}/profile/weight').set(w);
    await _dbRef.child('users/${_user!.uid}/profile/height').set(h);

    setState(() => _isLoading = false);
    //if (mounted) Navigator.pop(context); // Đóng dialog nhập
  }

  // 3. Hiện Dialog nhập liệu
  void _showUpdateDialog() {
    bool missingGender = widget.userProfile['gender'] == null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cập nhật chỉ số"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (missingGender)
              DropdownButtonFormField<String>(
                value: _selectedGender,
                hint: const Text("Chọn giới tính"),
                items: const [
                  DropdownMenuItem(value: "Nam", child: Text("Nam")),
                  DropdownMenuItem(value: "Nữ", child: Text("Nữ")),
                ],
                onChanged: (v) => setState(() => _selectedGender = v),
              ),
            TextField(
              controller: _heightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Chiều cao (cm)",
                suffixText: "cm",
              ),
            ),
            TextField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Cân nặng (kg)",
                suffixText: "kg",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Đóng dialog nhập
              _processUpdate(); // Gọi hàm xử lý (có loading)
            },
            child: const Text("Phân tích"),
          ),
        ],
      ),
    );
  }

  // Hàm wrapper để hiện loading khi gọi AI
  void _processUpdate() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    await _updateBMI();
    if (mounted && Navigator.canPop(context))
      Navigator.pop(context); // Tắt loading
  }

  @override
  Widget build(BuildContext context) {
    // Nếu chưa có lịch sử -> Hiện form nhập lần đầu
    if (_history.isEmpty && !_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Chỉ số BMI")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                FontAwesomeIcons.weightScale,
                size: 60,
                color: Colors.teal,
              ),
              const SizedBox(height: 20),
              const Text(
                "Chưa có dữ liệu BMI",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Hãy nhập chiều cao & cân nặng để AI phân tích",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _showUpdateDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5),
                  foregroundColor: Colors.white,
                ),
                child: const Text("Cập nhật lần đầu"),
              ),
            ],
          ),
        ),
      );
    }

    // Nếu đã có dữ liệu -> Hiện Dashboard lịch sử
    final current = _history.first;
    double bmiVal = double.parse(current['bmi'].toString());
    Color bmiColor = _getBMIColor(bmiVal);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text("Lịch sử & Phân tích BMI")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showUpdateDialog,
        backgroundColor: const Color(0xFF00BFA5),
        icon: const Icon(Icons.refresh, color: Colors.white),
        label: const Text("Cập nhật", style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // CARD TRẠNG THÁI HIỆN TẠI
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    "BMI Hiện Tại",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    current['bmi'],
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: bmiColor,
                    ),
                  ),
                  Text(
                    _getBMIStatus(bmiVal),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: bmiColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        const Icon(FontAwesomeIcons.robot, color: Colors.blue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            current['advice'] ?? "AI đang nghỉ ngơi...",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // BIỂU ĐỒ ĐƠN GIẢN (Vẽ bằng CustomPainter để không cần thư viện)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Biểu đồ thay đổi",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 15),
            Container(
              height: 200,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: CustomPaint(
                size: const Size(double.infinity, 200),
                painter: BMIChartPainter(history: _history),
              ),
            ),

            const SizedBox(height: 25),

            // DANH SÁCH LỊCH SỬ
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Lịch sử cập nhật",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final item = _history[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(FontAwesomeIcons.calendarDay, size: 18),
                  ),
                  title: Text(item['date']),
                  subtitle: Text("${item['height']}cm | ${item['weight']}kg"),
                  trailing: Text(
                    item['bmi'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  String _getBMIStatus(double bmi) {
    if (bmi < 18.5) return "Thiếu cân";
    if (bmi < 24.9) return "Bình thường";
    if (bmi < 29.9) return "Thừa cân";
    return "Béo phì";
  }

  Color _getBMIColor(double bmi) {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 24.9) return Colors.green;
    if (bmi < 29.9) return Colors.orange;
    return Colors.red;
  }
}

// CLASS VẼ BIỂU ĐỒ (Không cần thư viện ngoài)
class BMIChartPainter extends CustomPainter {
  final List<Map> history;
  BMIChartPainter({required this.history});

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;
    // Lấy tối đa 7 điểm dữ liệu gần nhất để vẽ
    final data = history.take(7).toList().reversed.toList();

    final Paint linePaint = Paint()
      ..color = const Color(0xFF00BFA5)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final Paint dotPaint = Paint()
      ..color = Colors.teal
      ..style = PaintingStyle.fill;
    final double padding = 20;

    // Tìm max/min để scale
    double maxBMI = 0;
    double minBMI = 100;
    for (var item in data) {
      double val = double.parse(item['bmi'].toString());
      if (val > maxBMI) maxBMI = val;
      if (val < minBMI) minBMI = val;
    }
    // Thêm khoảng đệm cho biểu đồ đẹp
    maxBMI += 2;
    minBMI -= 2;
    if (minBMI < 0) minBMI = 0;

    final double widthStep =
        (size.width - padding * 2) / (data.length > 1 ? data.length - 1 : 1);
    final double heightRatio = size.height / (maxBMI - minBMI);

    final Path path = Path();

    for (int i = 0; i < data.length; i++) {
      double val = double.parse(data[i]['bmi'].toString());
      double x = padding + i * widthStep;
      double y = size.height - (val - minBMI) * heightRatio;

      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);

      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
