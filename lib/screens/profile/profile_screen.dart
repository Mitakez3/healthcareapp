import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'edit_profile_screen.dart';
import 'health_data_screen.dart';
import '../../services/vnpay_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // --- LOGIC ĐĂNG XUẤT ---
  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Đăng xuất"),
        content: const Text("Bạn có chắc chắn muốn đăng xuất?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _signOut(context);
              },
              child: const Text("Đồng ý", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  // --- LOGIC ỦNG HỘ & THANH TOÁN ---
  void _handleSupportClick(BuildContext context, String uid) async {
    // 1. Kiểm tra xem user đã là VIP (isPremium) chưa
    final snapshot = await FirebaseDatabase.instance
        .ref('users/$uid/profile/isPremium')
        .get();

    bool isPremium = false;
    if (snapshot.exists && snapshot.value == true) {
      isPremium = true;
    }

    if (!isPremium) {
      // TRƯỜNG HỢP 1: Chưa VIP -> Bắt buộc 100k để tắt quảng cáo
      if (context.mounted) {
        _showConfirmDialog(
            context,
            "Ủng hộ nhà phát triển",
            "Ủng hộ 100.000đ để tắt quảng cáo trọn đời và hỗ trợ chúng tôi phát triển ứng dụng tốt hơn!",
            100000);
      }
    } else {
      // TRƯỜNG HỢP 2: Đã VIP -> Cho nhập số tiền tùy ý
      if (context.mounted) {
        _showCustomDonationDialog(context);
      }
    }
  }

  void _showConfirmDialog(
      BuildContext context, String title, String content, double amount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Để sau")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Gọi Service thanh toán VNPay
              VnpayService().createPaymentUrl(amount);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA5),
                foregroundColor: Colors.white),
            child: const Text("Thanh toán 100k"),
          )
        ],
      ),
    );
  }

  void _showCustomDonationDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Cảm ơn bạn! ❤️", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                "Bạn đã là thành viên VIP. Bạn có muốn ủng hộ thêm không?"),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: "Nhập số tiền (VND)",
                  suffixText: "đ",
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00BFA5)))),
            )
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Đóng")),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                double amount = double.tryParse(controller.text) ?? 0;
                if (amount >= 10000) {
                  // Tối thiểu 10k
                  Navigator.pop(ctx);
                  VnpayService().createPaymentUrl(amount);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Vui lòng nhập tối thiểu 10.000đ")));
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA5),
                foregroundColor: Colors.white),
            child: const Text("Ủng hộ"),
          )
        ],
      ),
    );
  }

  // --- GIAO DIỆN CHÍNH ---
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text("Hồ sơ cá nhân",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),

            // PHẦN HEADER: AVATAR + TÊN + TRẠNG THÁI VIP
            StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance
                    .ref('users/${user!.uid}/profile')
                    .onValue,
                builder: (context, snapshot) {
                  String displayName =
                      user.displayName ?? "Người dùng Health AI";
                  bool isPremium = false; // Biến kiểm tra VIP

                  if (snapshot.hasData &&
                      snapshot.data!.snapshot.value != null) {
                    final data = snapshot.data!.snapshot.value as Map;
                    displayName = data['fullName'] ?? displayName;
                    // Lấy trạng thái VIP từ Firebase
                    if (data['isPremium'] == true) {
                      isPremium = true;
                    }
                  }

                  return Container(
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        // Avatar
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5))
                              ],
                              image: const DecorationImage(
                                  image: NetworkImage(
                                      'https://i.pravatar.cc/150?img=12'),
                                  fit: BoxFit.cover)),
                        ),
                        const SizedBox(height: 15),

                        // Tên + Icon VIP
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(displayName,
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold)),

                            // Nếu là Premium thì hiện vương miện
                            if (isPremium) ...[
                              const SizedBox(width: 8),
                              const Icon(FontAwesomeIcons.crown,
                                  color: Colors.amber, size: 20),
                            ]
                          ],
                        ),

                        Text(user.email ?? "",
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey.shade600)),

                        // Badge hiển thị trạng thái tài khoản
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                              color: isPremium
                                  ? Colors.amber.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: isPremium
                                      ? Colors.amber
                                      : Colors.grey.shade300)),
                          child: Text(
                            isPremium ? "Thành viên VIP" : "Thành viên thường",
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isPremium
                                    ? Colors.orange[800]
                                    : Colors.grey[600]),
                          ),
                        )
                      ],
                    ),
                  );
                }),

            const SizedBox(height: 30),

            // MENU CHỨC NĂNG
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildProfileItem(Icons.person_outline, "Chỉnh sửa thông tin",
                      () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const EditProfileScreen()));
                  }),

                  _buildProfileItem(
                      FontAwesomeIcons.heartPulse, "Dữ liệu sức khỏe", () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const HealthDataScreen()));
                  }),

                  // --- NÚT MỚI THÊM VÀO ---
                  _buildProfileItem(
                      Icons.volunteer_activism, "Ủng hộ nhà phát triển", () {
                    _handleSupportClick(context, user.uid);
                  }),
                  // ------------------------

                  _buildProfileItem(
                      Icons.settings_outlined, "Cài đặt ứng dụng", () {}),
                  _buildProfileItem(
                      Icons.help_outline, "Trợ giúp & Hỗ trợ", () {}),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // NÚT ĐĂNG XUẤT
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () => _showLogoutDialog(context),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                  icon: const Icon(Icons.logout),
                  label: const Text("Đăng xuất",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // WIDGET CON: MỘT DÒNG MENU
  Widget _buildProfileItem(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ]),
      child: ListTile(
        leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFF00BFA5).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: const Color(0xFF00BFA5), size: 22)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        trailing:
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      ),
    );
  }
}
