import 'dart:math'; // Thêm thư viện này để random quảng cáo
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'vnpay_service.dart';

// 1. Tạo một class để quản lý thông tin quảng cáo cho gọn
class AdItem {
  final String imageUrl; // Link ảnh
  final String linkUrl; // Link trang web sản phẩm
  final String title; // Tên sản phẩm (hiện bên dưới ảnh)

  AdItem({required this.imageUrl, required this.linkUrl, required this.title});
}

class AdService {
  // KHU VỰC CHỈNH SỬA QUẢNG CÁO (THÊM/XÓA Ở ĐÂY)
  static final List<AdItem> _ads = [
    // Quảng cáo 1
    AdItem(
      title: "Sữa hạt 9 loại hạt Vinamilk ít đường",
      imageUrl:
          "https://down-vn.img.susercontent.com/file/vn-11134207-7r98o-lwy53fnah9zt7f@resize_w900_nl.webp", // Thay link ảnh thật vào đây
      linkUrl:
          "https://shopee.vn/Th%C3%B9ng-24-h%E1%BB%99p-S%E1%BB%AFa-h%E1%BA%A1t-9-lo%E1%BA%A1i-h%E1%BA%A1t-Vinamilk-%C3%ADt-%C4%91%C6%B0%E1%BB%9Dng-h%E1%BB%99p-180ml-i.975865932.20677798610?extraParams=%7B%22display_model_id%22%3A231408848648%2C%22model_selection_logic%22%3A3%7D&sp_atk=5f07fb91-52cd-4b0e-bfef-c5a4e2aeb874&xptdk=5f07fb91-52cd-4b0e-bfef-c5a4e2aeb874",
    ),

    // Quảng cáo 2
    AdItem(
      title: "Đồng Hồ Thông Minh HUAWEI WATCH FIT 4",
      imageUrl:
          "https://down-vn.img.susercontent.com/file/vn-11134207-7ra0g-m9su0s54na82de@resize_w900_nl.webp",
      linkUrl:
          "https://shopee.vn/%C4%90%E1%BB%93ng-H%E1%BB%93-Th%C3%B4ng-Minh-HUAWEI-WATCH-FIT-4-Series-M%E1%BB%8Fng-Nh%E1%BA%B9-Th%E1%BB%83-Thao-S%E1%BB%A9c-Kh%E1%BB%8Fe-L%C3%AAn-%C4%90%E1%BA%BFn-10-Ng%C3%A0y-S%E1%BB%AD-D%E1%BB%A5ng-ECG*-i.600507109.40451930644?extraParams=%7B%22display_model_id%22%3A248448070947%2C%22model_selection_logic%22%3A3%7D&rModelId=248448070947&sp_atk=ccb50be1-c7c3-40f1-b060-a87c51b08f62&vItemId=41310634728&vModelId=300894377513&vShopId=1506174776&xptdk=ccb50be1-c7c3-40f1-b060-a87c51b08f62",
    ),
  ];

  static int _transitionCount = 0;
  static const int _showAdEvery = 5;

  // Hàm gọi mỗi khi chuyển tab
  static Future<void> checkAndShowAd(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Kiểm tra VIP
    final snapshot = await FirebaseDatabase.instance
        .ref('users/${user.uid}/profile/isPremium')
        .get();

    bool isPremium = false;
    if (snapshot.exists && snapshot.value == true) {
      isPremium = true;
    }

    if (isPremium) return; // Nếu VIP rồi thì thôi

    _transitionCount++;
    print("Đếm chuyển trang: $_transitionCount");

    if (_transitionCount >= _showAdEvery) {
      _transitionCount = 0;
      if (context.mounted && _ads.isNotEmpty) {
        // --- LOGIC RANDOM: CHỌN NGẪU NHIÊN 1 QUẢNG CÁO TRONG DANH SÁCH ---
        final randomAd = _ads[Random().nextInt(_ads.length)];
        _showAdDialog(context, randomAd);
      }
    }
  }

  // Giao diện Popup Quảng cáo (Đã sửa để nhận dữ liệu động)
  static void _showAdDialog(BuildContext context, AdItem ad) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),

            // ẢNH QUẢNG CÁO
            GestureDetector(
              onTap: () async {
                final uri = Uri.parse(ad.linkUrl);
                // Thêm mode: LaunchMode.externalApplication để mở hẳn trình duyệt Chrome/Shopee App
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  // Fallback: Cố gắng mở ngay cả khi canLaunchUrl trả về false (đôi khi cần thiết trên 1 số máy)
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      ad.imageUrl,
                      height: 350,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      // Hình thay thế nếu link ảnh lỗi
                      errorBuilder: (context, error, stackTrace) => Container(
                          height: 350,
                          color: Colors.grey[300],
                          child: const Center(
                              child: Icon(Icons.broken_image,
                                  size: 50, color: Colors.grey))),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      ad.title, // Hiển thị tên sản phẩm
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            const Text("Quảng cáo tài trợ",
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  VnpayService().createPaymentUrl(100000);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45),
                ),
                icon: const Icon(Icons.favorite),
                label: const Text("Ủng hộ 100k để tắt quảng cáo"),
              ),
            )
          ],
        ),
      ),
    );
  }
}
