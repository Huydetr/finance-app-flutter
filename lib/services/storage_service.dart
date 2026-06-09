import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as p;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Lấy User ID hiện tại
  String? get _userId => _auth.currentUser?.uid;

  /// Tải ảnh lên Firebase Storage và trả về URL tải xuống
  Future<String?> uploadImage(File imageFile) async {
    final uid = _userId;
    if (uid == null) throw Exception('Vui lòng đăng nhập để tải ảnh lên');

    try {
      // Tạo tên file duy nhất bằng timestamp
      final fileName = '${DateTime.now().millisecondsSinceEpoch}${p.extension(imageFile.path)}';
      
      // Đường dẫn lưu trữ: users/{uid}/receipts/{fileName}
      final ref = _storage.ref().child('users/$uid/receipts/$fileName');

      // Tải file lên
      final uploadTask = await ref.putFile(imageFile);

      // Lấy URL tải xuống
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Lỗi tải ảnh lên Storage: $e');
      return null;
    }
  }

  /// Xóa ảnh khỏi Firebase Storage dựa trên URL
  Future<void> deleteImage(String imageUrl) async {
    try {
      if (imageUrl.contains('firebasestorage.googleapis.com')) {
        final ref = _storage.refFromURL(imageUrl);
        await ref.delete();
      }
    } catch (e) {
      print('Lỗi xóa ảnh từ Storage: $e');
    }
  }
}
