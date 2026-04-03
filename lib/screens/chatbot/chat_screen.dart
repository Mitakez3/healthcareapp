import 'package:flutter/material.dart';
import 'package:bubble/bubble.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  _AIAssistantScreenState createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  static const apiKey = 'AIzaSyByrk3WkHBH2Iq8bS9F1DfIr39s0JCk1EA';

  // Khởi tạo model
  late final GenerativeModel _model;

  final List<Map<String, dynamic>> _messages = [
    {
      "data": 0,
      "message": "Chào bạn! Tôi là trợ lý ảo hỗ trợ sức khỏe. Tôi có thể giúp bạn gợi ý bài tập, lên lịch chạy bộ hoặc tư vấn chế độ dinh dưỡng thể thao. Bạn muốn bắt đầu rèn luyện thế nào hôm nay?"
    }
  ];

  @override
  void initState() {
    super.initState();
    // Thiết lập Model và hướng dẫn AI đóng vai chuyên gia PT
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(temperature: 0.7),
      systemInstruction: Content.system(
          "Bạn là một Huấn luyện viên thể hình và Chuyên gia dinh dưỡng thể thao ảo năng động, chuyên nghiệp. "
              "Nhiệm vụ của bạn là tư vấn các bài tập thể dục (gym, chạy bộ, yoga...), cách tăng cơ, giảm mỡ và chế độ ăn uống cho người tập luyện. "
              "TUYỆT ĐỐI KHÔNG xưng là bác sĩ, KHÔNG kê đơn thuốc và KHÔNG tư vấn các vấn đề y tế, bệnh lý. "
              "Nếu người dùng hỏi về cách chữa bệnh hoặc thuốc men, hãy từ chối khéo léo và khuyên họ đến gặp bác sĩ chuyên khoa. "
              "Hãy trả lời ngắn gọn, tạo động lực và sử dụng ngôn ngữ thân thiện, tràn đầy năng lượng."
      ),
    );
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;

    // Hiển thị tin nhắn người dùng ngay lập tức
    setState(() {
      _messages.add({"data": 1, "message": text});
      _isLoading = true;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      // Gửi tin nhắn đến API Gemini
      final content = [Content.text(text)];
      final response = await _model.generateContent(content);

      setState(() {
        _messages.add({
          "data": 0,
          "message": response.text ?? "Xin lỗi, tôi không hiểu ý bạn."
        });
        _isLoading = false;
      });
    } catch (e) {
      print("LỖI GEMINI: $e");
      setState(() {
        _messages.add({
          "data": 0,
          "message": "Lỗi kết nối: Không thể nhận phản hồi từ AI."
        });
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Huấn luyện viên AI"), backgroundColor: Colors.teal),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return Bubble(
                  margin: const BubbleEdges.only(top: 10),
                  alignment: _messages[index]['data'] == 0 ? Alignment.topLeft : Alignment.topRight,
                  nip: _messages[index]['data'] == 0 ? BubbleNip.leftTop : BubbleNip.rightTop,
                  color: _messages[index]['data'] == 0 ? Colors.grey[200] : Colors.teal[100],
                  child: Text(_messages[index]['message'], style: const TextStyle(fontSize: 16)),
                );
              },
            ),
          ),

          // Hiển thị loading khi AI đang suy nghĩ
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Huấn luyện viên đang gõ...", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
            ),

          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: _sendMessage,
                    decoration: const InputDecoration(
                        hintText: "Hỏi về bài tập, dinh dưỡng...",
                        border: InputBorder.none
                    ),
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.send, color: Colors.teal),
                    onPressed: () => _sendMessage(_controller.text)
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}