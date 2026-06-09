import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../controllers/transaction_controller.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _controller = TransactionController();
  bool _isReminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadReminderSettings();
  }

  Future<void> _loadReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isReminderEnabled = prefs.getBool('isReminderEnabled') ?? false;
      final hour = prefs.getInt('reminderHour') ?? 20;
      final minute = prefs.getInt('reminderMinute') ?? 0;
      _reminderTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  Future<void> _toggleReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isReminderEnabled = value;
    });
    await prefs.setBool('isReminderEnabled', value);

    if (value) {
      await NotificationService().requestPermission();
      await NotificationService().scheduleDailyReminder(
        _reminderTime.hour,
        _reminderTime.minute,
      );
    } else {
      await NotificationService().cancelReminder();
    }
  }

  Future<void> _selectReminderTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryStart,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _reminderTime) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _reminderTime = picked;
      });
      await prefs.setInt('reminderHour', picked.hour);
      await prefs.setInt('reminderMinute', picked.minute);

      if (_isReminderEnabled) {
        await NotificationService().scheduleDailyReminder(
          picked.hour,
          picked.minute,
        );
      }
    }
  }

  Future<void> _exportData() async {
    try {
      final transactions = await _controller.getAllTransactions();
      if (transactions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Không có dữ liệu để xuất'),
              backgroundColor: AppColors.surface,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        return;
      }

      List<List<dynamic>> rows = [];
      // Header
      rows.add([
        "ID",
        "Tiêu đề",
        "Số tiền",
        "Loại",
        "Danh mục",
        "Ngày",
        "Ghi chú",
      ]);

      for (var t in transactions) {
        rows.add([
          t.id,
          t.title,
          t.amount,
          t.type == 'income' ? 'Thu nhập' : 'Chi tiêu',
          t.category,
          AppFormatters.formatDateShort(t.date),
          t.note,
        ]);
      }

      String csv = ListToCsvConverter().convert(rows);

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/bao_cao_thu_chi.csv';
      final file = File(path);

      // Ghi file với BOM để Excel hỗ trợ tiếng Việt
      await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...csv.codeUnits]);

      await Share.shareXFiles([XFile(path)], text: 'Báo cáo thu chi cá nhân');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xuất dữ liệu: $e'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.settings_rounded,
                  color: AppColors.primaryStart,
                  size: 24,
                ),
                SizedBox(width: 10),
                Text(
                  'Cài đặt',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            // App info
            _buildSection('Thông tin ứng dụng', [
              _buildInfoTile(
                Icons.info_outline_rounded,
                'Tên ứng dụng',
                'Quản Lý Thu Chi',
              ),
              _buildInfoTile(Icons.code_rounded, 'Phiên bản', '1.0.0'),
              _buildInfoTile(
                Icons.school_rounded,
                'Đồ án',
                'Lập trình di động',
              ),
            ]),
            const SizedBox(height: 20),
            // Account
            _buildSection('Tài khoản', [
              _buildActionTile(
                Icons.logout_rounded,
                'Đăng xuất',
                'Đăng xuất khỏi thiết bị này',
                AppColors.expense,
                () async {
                  await AuthService().signOut();
                },
              ),
            ]),
            const SizedBox(height: 20),
            // Reminders
            _buildSection('Thông báo', [
              _buildToggleTile(
                Icons.notifications_active_rounded,
                'Nhắc nhở hàng ngày',
                'Nhắc bạn ghi chép thu chi',
                _isReminderEnabled,
                _toggleReminder,
              ),
              if (_isReminderEnabled)
                _buildActionTile(
                  Icons.access_time_rounded,
                  'Giờ nhắc nhở',
                  _reminderTime.format(context),
                  AppColors.primaryStart,
                  _selectReminderTime,
                ),
            ]),
            const SizedBox(height: 20),
            // Data management
            _buildSection('Quản lý dữ liệu', [
              _buildActionTile(
                Icons.download_rounded,
                'Xuất dữ liệu CSV',
                'Lưu toàn bộ giao dịch ra file Excel',
                AppColors.primaryStart,
                _exportData,
              ),
              _buildActionTile(
                Icons.delete_sweep_rounded,
                'Xóa tất cả dữ liệu',
                'Xóa toàn bộ giao dịch đã lưu',
                AppColors.expense,
                () => _confirmDeleteAll(),
              ),
            ]),
            const SizedBox(height: 20),
            // About
            _buildSection('Hướng dẫn sử dụng', [
              _buildInfoTile(
                Icons.swipe_left_rounded,
                'Xóa giao dịch',
                'Vuốt sang trái để xóa',
              ),
              _buildInfoTile(
                Icons.touch_app_rounded,
                'Sửa giao dịch',
                'Nhấn vào giao dịch để sửa',
              ),
              _buildInfoTile(
                Icons.add_circle_outline_rounded,
                'Thêm giao dịch',
                'Nhấn nút + ở giữa',
              ),
              _buildInfoTile(
                Icons.refresh_rounded,
                'Làm mới',
                'Kéo xuống để làm mới',
              ),
            ]),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceLight),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primaryStart.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primaryStart, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textHint, fontSize: 12),
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textHint, fontSize: 12),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: color.withOpacity(0.5),
      ),
    );
  }

  Widget _buildToggleTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primaryStart,
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primaryStart.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primaryStart, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textHint, fontSize: 12),
      ),
    );
  }

  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '⚠️ Xác nhận xóa',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Bạn có chắc muốn xóa TẤT CẢ dữ liệu? Hành động này không thể hoàn tác!',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              await _controller.deleteAllData();
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Đã xóa tất cả dữ liệu'),
                    backgroundColor: AppColors.surface,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            },
            child: const Text(
              'Xóa tất cả',
              style: TextStyle(
                color: AppColors.expense,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
