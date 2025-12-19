import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'edit_profile_screen.dart';
import 'health_data_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          TextButton(onPressed: () { Navigator.pop(ctx); _signOut(context); }, child: const Text("Đồng ý", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    const primaryColor = Color(0xFF00BFA5);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text("Hồ sơ cá nhân", style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true, elevation: 0),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance.ref('users/${user!.uid}/profile').onValue,
                builder: (context, snapshot) {
                  String displayName = user.displayName ?? "Người dùng Health AI";
                  if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                    final data = snapshot.data!.snapshot.value as Map;
                    displayName = data['fullName'] ?? displayName;
                  }

                  return Container(
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Container(
                          width: 110, height: 110,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4),
                              image: const DecorationImage(image: NetworkImage('https://i.pravatar.cc/150?img=12'), fit: BoxFit.cover)),
                        ),
                        const SizedBox(height: 15),
                        Text(displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        Text(user.email ?? "", style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                      ],
                    ),
                  );
                }
            ),

            const SizedBox(height: 30),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildProfileItem(Icons.person_outline, "Chỉnh sửa thông tin", () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen()));
                  }),

                  _buildProfileItem(FontAwesomeIcons.heartPulse, "Dữ liệu sức khỏe", () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const HealthDataScreen()));
                  }),

                  _buildProfileItem(Icons.settings_outlined, "Cài đặt ứng dụng", () {}),
                  _buildProfileItem(Icons.help_outline, "Trợ giúp & Hỗ trợ", () {}),
                ],
              ),
            ),

            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton.icon(
                  onPressed: () => _showLogoutDialog(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  icon: const Icon(Icons.logout), label: const Text("Đăng xuất", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 5))]),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF00BFA5).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: const Color(0xFF00BFA5), size: 22)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      ),
    );
  }
}