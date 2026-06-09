import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

// ============================================================
// Các hàm tiện ích định dạng tiền tệ và ngày tháng
// ============================================================

class AppFormatters {
  /// Định dạng số tiền theo VND
  /// Ví dụ: 1500000 -> "1.500.000 ₫"
  static String formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    return '${formatter.format(amount.abs())} ₫';
  }

  /// Định dạng số tiền có dấu +/-
  /// Ví dụ: Thu nhập 500000 -> "+500.000 ₫", Chi tiêu 300000 -> "-300.000 ₫"
  static String formatCurrencyWithSign(double amount, String type) {
    final formatted = formatCurrency(amount);
    if (type == 'income') return '+$formatted';
    return '-$formatted';
  }

  /// Định dạng ngày theo dd/MM/yyyy
  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Định dạng ngày đầy đủ
  static String formatDateFull(DateTime date) {
    return DateFormat('EEEE, dd/MM/yyyy', 'vi').format(date);
  }

  /// Định dạng tháng/năm
  static String formatMonthYear(DateTime date) {
    return DateFormat('MM/yyyy').format(date);
  }

  /// Định dạng ngày ngắn gọn
  static String formatDateShort(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Hôm nay';
    if (dateOnly == today.subtract(const Duration(days: 1))) return 'Hôm qua';
    if (dateOnly == today.add(const Duration(days: 1))) return 'Ngày mai';

    return DateFormat('dd/MM').format(date);
  }

  /// Rút gọn số tiền lớn
  /// Ví dụ: 1500000 -> "1.5M"
  static String formatCompact(double amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)}B';
    } else if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}

/// Formatter tự động chèn dấu phẩy ngăn cách hàng nghìn khi nhập liệu
/// Ví dụ: 1000 -> 1,000
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    
    // Loại bỏ tất cả các ký tự không phải là số
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    
    // Format với dấu chấm ngăn cách hàng nghìn (chuẩn Việt Nam)
    final intValue = int.parse(digits);
    final formatter = NumberFormat('#,###', 'en_US');
    final newText = formatter.format(intValue).replaceAll(',', '.');
    
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
