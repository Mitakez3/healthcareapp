import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  void _loadCurrentData() async {
    if (user != null) {
      final snapshot = await FirebaseDatabase.instance.ref('users/${user!.uid}/profile').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        _nameController.text = data['fullName'] ?? user!.displayName ?? "";
        _phoneController.text = data['phone'] ?? "";
        setState(() {});
      }
    }
  }

  void _saveProfile() async {
    if (user == null) return;
    setState(() => _isLoading = true);

    await FirebaseDatabase.instance.ref('users/${user!.uid}/profile').update({
      'fullName': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
    });

    await user!.updateDisplayName(_nameController.text.trim());

    setState(() => _isLoading = false);
    if(mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chỉnh sửa thông tin"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Họ và tên", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: "Số điện thoại", border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5)),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Lưu thay đổi", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}