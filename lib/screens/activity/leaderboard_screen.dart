import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  List<Map<String, dynamic>> _leaderboard = [];
  Map<String, dynamic>? _myRankData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      final snapshot = await _dbRef.child('users').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> tempList = [];

        // 1. Duyệt qua tất cả user để lấy dữ liệu
        data.forEach((uid, userData) {
          final health = userData['health_data'] ?? {};
          final profile = userData['profile'] ?? {};

          // Lấy khoảng cách (Nếu không có thì bằng 0)
          int distance = (health['distance'] as num?)?.toInt() ?? 0;

          // Kiểm tra xem dữ liệu có phải hôm nay không (Nếu timestamp cũ -> distance coi như = 0)
          int timestamp = (health['timestamp'] as num?)?.toInt() ?? 0;
          if (!_isToday(timestamp)) {
            distance = 0;
          }

          String name = (profile['fullName'] ?? "Người dùng").trim();
          if (name.isEmpty) name = "Người dùng ẩn danh";
          // Lấy tên cuối cho gọn (Ví dụ: Nguyễn Văn A -> A)
          String shortName = name.split(" ").last;

          tempList.add({
            'uid': uid,
            'name': shortName,
            'fullName': name,
            'distance': distance,
            'avatar':
                'https://i.pravatar.cc/150?u=$uid', // Avatar ngẫu nhiên theo UID
          });
        });

        // 2. Sắp xếp giảm dần theo quãng đường
        tempList.sort((a, b) => b['distance'].compareTo(a['distance']));

        // 3. Gán số thứ tự (Rank)
        for (int i = 0; i < tempList.length; i++) {
          tempList[i]['rank'] = i + 1;
        }

        // 4. Tìm vị trí của mình
        final myIndex = tempList.indexWhere(
          (element) => element['uid'] == _currentUid,
        );
        if (myIndex != -1) {
          _myRankData = tempList[myIndex];
        }

        setState(() {
          _leaderboard = tempList;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Lỗi tải BXH: $e");
      setState(() => _isLoading = false);
    }
  }

  bool _isToday(int timestamp) {
    if (timestamp == 0) return false;
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    // Lấy Top 10 để hiển thị danh sách chính
    final top10 = _leaderboard.take(10).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          "Bảng Xếp Hạng Ngày",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // DANH SÁCH TOP 10
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: top10.length,
                    itemBuilder: (context, index) {
                      final user = top10[index];
                      return _buildRankItem(user, index + 1);
                    },
                  ),
                ),

                // HIỂN THỊ HẠNG CỦA MÌNH (Nếu mình nằm ngoài Top 10)
                if (_myRankData != null && (_myRankData!['rank'] as int) > 10)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Thứ hạng của bạn:",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 5),
                          _buildRankItem(
                            _myRankData!,
                            _myRankData!['rank'],
                            isMe: true,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildRankItem(
    Map<String, dynamic> user,
    int rank, {
    bool isMe = false,
  }) {
    Color bgColor = Colors.white;
    Color textColor = Colors.black;
    IconData? rankIcon;
    Color iconColor = Colors.transparent;

    // Xử lý màu nền Top 3
    if (rank == 1) {
      bgColor = const Color(0xFFFFD700); // Vàng
      rankIcon = FontAwesomeIcons.crown;
      iconColor = Colors.white;
    } else if (rank == 2) {
      bgColor = const Color(0xFFC0C0C0); // Bạc
      rankIcon = FontAwesomeIcons.medal;
      iconColor = Colors.white;
    } else if (rank == 3) {
      bgColor = const Color(0xFFCD7F32); // Đồng
      rankIcon = FontAwesomeIcons.medal;
      iconColor = Colors.white;
    }

    // Nếu là bản thân thì viền màu xanh nổi bật
    if (isMe) {
      bgColor = const Color(0xFFE0F2F1); // Xanh nhạt
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
        border: isMe ? Border.all(color: Colors.teal, width: 2) : null,
      ),
      child: Row(
        children: [
          // Cột Hạng
          SizedBox(
            width: 40,
            child: rank <= 3
                ? Icon(rankIcon, color: iconColor)
                : Text(
                    "#$rank",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
          ),

          const SizedBox(width: 10),

          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(user['avatar']),
          ),

          const SizedBox(width: 15),

          // Tên
          Expanded(
            child: Text(
              user['fullName'], // Hiển thị tên đầy đủ
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Quãng đường
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${user['distance']}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: textColor,
                ),
              ),
              Text(
                "mét",
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
