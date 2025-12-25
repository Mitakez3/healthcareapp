import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class VnpayService {
  // CẤU HÌNH VNPAY DEMO (Giữ nguyên để chạy test)
  static const String vnp_TmnCode = "WP2E0FPZ";
  static const String vnp_HashSecret = "INPQ7RJ8EIVA5I0ANVTPI9E31FR49L0X";
  static const String vnp_Url =
      "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html";

  // Hàm tạo link thanh toán
  Future<void> createPaymentUrl(double amount) async {
    final date = DateTime.now();
    final ipAddr = '127.0.0.1';

    final params = <String, String>{
      'vnp_Version': '2.1.0',
      'vnp_Command': 'pay',
      'vnp_TmnCode': vnp_TmnCode,
      'vnp_Locale': 'vn',
      'vnp_CurrCode': 'VND',
      'vnp_TxnRef': date.millisecondsSinceEpoch.toString(),
      'vnp_OrderInfo': 'ThanhToanDemo',
      'vnp_OrderType': 'other',
      'vnp_Amount': (amount * 100).toStringAsFixed(0),
      'vnp_ReturnUrl': 'https://www.google.com/',
      'vnp_IpAddr': ipAddr,
      'vnp_CreateDate': DateFormat('yyyyMMddHHmmss').format(date),
    };

    var sortedParamKeys = params.keys.toList()..sort();
    var signData = StringBuffer();
    var query = StringBuffer();

    for (var i = 0; i < sortedParamKeys.length; i++) {
      if (i > 0) {
        signData.write('&');
        query.write('&');
      }
      var key = sortedParamKeys[i];
      var value = params[key];
      var encodedKey = Uri.encodeQueryComponent(key);
      var encodedValue = Uri.encodeQueryComponent(value!);
      signData.write('$encodedKey=$encodedValue');
      query.write('$encodedKey=$encodedValue');
    }

    var key = utf8.encode(vnp_HashSecret);
    var bytes = utf8.encode(signData.toString());
    var hmacSha512 = Hmac(sha512, key);
    var digest = hmacSha512.convert(bytes);

    var paymentUrl = '$vnp_Url?${query.toString()}&vnp_SecureHash=$digest';

    final uri = Uri.parse(paymentUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      // MỞ TRANG WEB XONG THÌ GIẢ LẬP LÀ ĐÃ THANH TOÁN THÀNH CÔNG
      _updateUserPremiumStatus();
    } else {
      print("Không thể mở link thanh toán");
    }
  }

  // Hàm cập nhật trạng thái VIP lên Firebase
  Future<void> _updateUserPremiumStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final ref = FirebaseDatabase.instance.ref('users/${user.uid}/profile');
      // Cập nhật hoặc thêm mới trường isPremium
      await ref.update({
        'isPremium': true,
        'lastPaymentDate': DateTime.now().toIso8601String(),
      });
      print("Đã kích hoạt chế độ Không quảng cáo!");
    }
  }
}
