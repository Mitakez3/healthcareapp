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
      "message": "Chào bạn! Tôi là trợ lý sức khỏe. Bạn cần tư vấn về thuốc, ăn uống hay tập luyện?"
    }
  ];

  @override
  void initState() {
    super.initState();
    // Thiết lập Model và hướng dẫn AI đóng vai bác sĩ/chuyên gia
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(temperature: 0.7),
      systemInstruction: Content.system(
          "Bạn là một trợ lý sức khỏe ảo thông minh, thân thiện. "
              "Hãy trả lời ngắn gọn, tập trung vào y tế, dinh dưỡng và tập luyện. "
              "Nếu câu hỏi không liên quan đến sức khỏe, hãy khéo léo từ chối."
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
      appBar: AppBar(title: const Text("Trợ lý AI"), backgroundColor: Colors.teal),
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
              child: Text("Trợ lý đang nhập...", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
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
                        hintText: "Hỏi về sức khỏe...",
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