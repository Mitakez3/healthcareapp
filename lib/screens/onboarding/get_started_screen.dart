import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../auth/auth_screen.dart';

class OnboardingContent {
  final String image;
  final String title;
  final String desc;

  OnboardingContent({
    required this.image,
    required this.title,
    required this.desc,
  });
}

class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key});

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen> {
  late PageController _pageController;
  int _pageIndex = 0;

  final List<OnboardingContent> _contents = [
    OnboardingContent(
      image: 'https://cdn-icons-png.flaticon.com/512/4497/4497898.png',
      title: "Sức khỏe toàn diện\ntrong tầm tay",
      desc: "Theo dõi chỉ số sức khỏe, nhịp tim và huyết áp mọi lúc mọi nơi.",
    ),
    OnboardingContent(
      image: 'https://cdn-icons-png.flaticon.com/512/2928/2928144.png',
      title: "Chế độ dinh dưỡng\nhợp lý",
      desc: "Gợi ý thực đơn cá nhân hóa và theo dõi calo tiêu thụ hàng ngày.",
    ),
    OnboardingContent(
      image: 'https://cdn-icons-png.flaticon.com/512/4712/4712035.png',
      title: "Trợ lý AI\nthông minh 24/7",
      desc: "Giải đáp thắc mắc y tế và đưa ra lời khuyên hữu ích tức thì.",
    ),
  ];

  @override
  void initState() {
    _pageController = PageController(initialPage: 0);
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const primaryColor = Color(0xFF00BFA5);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Slider Hình ảnh và Nội dung
            Expanded(
              flex: 5,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _contents.length,
                onPageChanged: (index) {
                  setState(() {
                    _pageIndex = index;
                  });
                },
                itemBuilder: (context, index) => _buildSlide(size, _contents[index]),
              ),
            ),

            // Điều hướng
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _contents.length,
                            (index) => buildDot(index, context, primaryColor),
                      ),
                    ),
                    const Spacer(),

                    // Button Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Nút Quay lại
                        _pageIndex == 0
                            ? const SizedBox(width: 100)
                            : TextButton(
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.ease,
                            );
                          },
                          child: Text(
                            "Quay lại",
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                          ),
                        ),

                        // Nút Tiếp theo hoặc Bắt đầu
                        SizedBox(
                          height: 50,
                          width: 140,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_pageIndex == _contents.length - 1) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                                );
                              } else {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.ease,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              _pageIndex == _contents.length - 1 ? "Bắt đầu" : "Tiếp theo",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(Size size, OnboardingContent content) {
    return Container(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 300,
                width: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00BFA5).withOpacity(0.1),
                ),
              ),
              CachedNetworkImage(
                imageUrl: content.image,
                height: 250,
                fit: BoxFit.contain,
                placeholder: (context, url) => const SizedBox(
                    height: 50,
                    width: 50,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2))
                ),
                errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Text(
            content.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            content.desc,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Container buildDot(int index, BuildContext context, Color color) {
    return Container(
      height: 8,
      width: _pageIndex == index ? 24 : 8,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _pageIndex == index ? color : Colors.grey.shade300,
      ),
    );
  }
}