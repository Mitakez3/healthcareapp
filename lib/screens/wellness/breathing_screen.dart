import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // 4s hít vào, 4s thở ra
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleBreathing() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _controller.forward();
      } else {
        _controller.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.teal),
        title: const Text("Thư giãn", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isPlaying
                  ? (_controller.status == AnimationStatus.forward ? "Hít vào..." : "Thở ra...")
                  : "Sẵn sàng?",
              style: GoogleFonts.lato(fontSize: 28, fontWeight: FontWeight.w300, color: Colors.teal.shade800),
            ),
            const SizedBox(height: 50),

            // Vòng tròn Animation
            Stack(
              alignment: Alignment.center,
              children: [
                // Vòng mờ bên ngoài
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Container(
                      width: 200 * _scaleAnimation.value,
                      height: 200 * _scaleAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.teal.withOpacity(0.2),
                      ),
                    );
                  },
                ),
                // Vòng đậm bên trong
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Container(
                      width: 180 * _scaleAnimation.value,
                      height: 180 * _scaleAnimation.value,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Colors.teal.shade300, Colors.teal.shade100],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
                          ]
                      ),
                      child: Center(
                        child: Icon(
                          _isPlaying ? Icons.spa : Icons.play_arrow_rounded,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 60),

            // Nút điều khiển
            SizedBox(
              width: 180,
              height: 50,
              child: ElevatedButton(
                onPressed: _toggleBreathing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text(
                  _isPlaying ? "Dừng lại" : "Bắt đầu",
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Thực hiện 5 phút mỗi ngày để giảm căng thẳng",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}