import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.expense,
      ),
    );
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showError('Vui lòng nhập đầy đủ thông tin');
      return;
    }

    if (password != confirm) {
      _showError('Mật khẩu xác nhận không khớp');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.registerWithEmail(email, password);
      // Đăng ký thành công, tự động đăng nhập và quay về AuthGate -> HomeScreen
      if (mounted) {
        Navigator.pop(context); // Đóng màn hình đăng ký
      }
    } on FirebaseAuthException catch (e) {
      String err = 'Đã có lỗi xảy ra';
      if (e.code == 'email-already-in-use')
        err = 'Email này đã được sử dụng';
      else if (e.code == 'weak-password')
        err = 'Mật khẩu quá yếu, vui lòng chọn mật khẩu dài hơn';
      else if (e.code == 'invalid-email')
        err = 'Email không hợp lệ';
      _showError(err);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Đăng Ký Tài Khoản'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Tạo tài khoản mới',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hãy bắt đầu hành trình quản lý tài chính thông minh',
                style: TextStyle(color: AppColors.textHint, fontSize: 16),
              ),
              const SizedBox(height: 48),

              // Form
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Email',
                  hintStyle: const TextStyle(color: AppColors.textHint),
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: AppColors.textHint,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Mật khẩu',
                  hintStyle: const TextStyle(color: AppColors.textHint),
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: AppColors.textHint,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Xác nhận mật khẩu',
                  hintStyle: const TextStyle(color: AppColors.textHint),
                  prefixIcon: const Icon(
                    Icons.lock_reset_outlined,
                    color: AppColors.textHint,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Nút Đăng ký
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryStart,
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryStart,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Đăng Ký',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
