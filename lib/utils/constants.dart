import 'package:flutter/material.dart';

// ============================================================
// Hằng số màu sắc và theme cho ứng dụng
// ============================================================

class AppColors {
  // Gradient chính
  static const Color primaryStart = Color(0xFF6C63FF);
  static const Color primaryEnd = Color(0xFF3B82F6);

  // Nền
  static const Color background = Color(0xFF0F0F23);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceLight = Color(0xFF25253D);
  static const Color cardBackground = Color(0xFF16213E);

  // Thu nhập / Chi tiêu
  static const Color income = Color(0xFF00C853);
  static const Color incomeLight = Color(0xFF69F0AE);
  static const Color expense = Color(0xFFFF5252);
  static const Color expenseLight = Color(0xFFFF8A80);
  
  // Trạng thái
  static const Color success = Color(0xFF00C853);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0C3);
  static const Color textHint = Color(0xFF6C6C80);

  // Accent
  static const Color accent = Color(0xFFBB86FC);
  static const Color accentSecondary = Color(0xFF03DAC6);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryStart, primaryEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient incomeGradient = LinearGradient(
    colors: [Color(0xFF00C853), Color(0xFF00E676)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient expenseGradient = LinearGradient(
    colors: [Color(0xFFFF5252), Color(0xFFFF6E40)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ============================================================
// Danh mục thu chi mặc định
// ============================================================

class AppCategories {
  static const List<Map<String, dynamic>> expenseCategories = [
    {'name': 'Ăn uống', 'icon': Icons.restaurant, 'color': Color(0xFFFF6B6B)},
    {'name': 'Di chuyển', 'icon': Icons.directions_car, 'color': Color(0xFF4ECDC4)},
    {'name': 'Mua sắm', 'icon': Icons.shopping_bag, 'color': Color(0xFFFFE66D)},
    {'name': 'Giải trí', 'icon': Icons.movie, 'color': Color(0xFFA8E6CF)},
    {'name': 'Sức khỏe', 'icon': Icons.favorite, 'color': Color(0xFFFF8A5C)},
    {'name': 'Giáo dục', 'icon': Icons.school, 'color': Color(0xFF6C5CE7)},
    {'name': 'Hóa đơn', 'icon': Icons.receipt_long, 'color': Color(0xFFFD79A8)},
    {'name': 'Nhà ở', 'icon': Icons.home, 'color': Color(0xFF00B894)},
    {'name': 'Quà tặng', 'icon': Icons.card_giftcard, 'color': Color(0xFFE17055)},
    {'name': 'Khác', 'icon': Icons.more_horiz, 'color': Color(0xFF636E72)},
  ];

  static const List<Map<String, dynamic>> incomeCategories = [
    {'name': 'Lương', 'icon': Icons.account_balance_wallet, 'color': Color(0xFF00C853)},
    {'name': 'Thưởng', 'icon': Icons.stars, 'color': Color(0xFFFFD700)},
    {'name': 'Đầu tư', 'icon': Icons.trending_up, 'color': Color(0xFF2196F3)},
    {'name': 'Bán hàng', 'icon': Icons.store, 'color': Color(0xFFFF9800)},
    {'name': 'Cho thuê', 'icon': Icons.apartment, 'color': Color(0xFF9C27B0)},
    {'name': 'Khác', 'icon': Icons.more_horiz, 'color': Color(0xFF607D8B)},
  ];

  /// Lấy icon theo tên danh mục
  static IconData getIcon(String categoryName) {
    if (categoryName == 'Ống heo') return Icons.savings_rounded;
    for (var cat in [...expenseCategories, ...incomeCategories]) {
      if (cat['name'] == categoryName) return cat['icon'] as IconData;
    }
    return Icons.category;
  }

  /// Lấy màu theo tên danh mục
  static Color getColor(String categoryName) {
    if (categoryName == 'Ống heo') return AppColors.accent;
    for (var cat in [...expenseCategories, ...incomeCategories]) {
      if (cat['name'] == categoryName) return cat['color'] as Color;
    }
    return const Color(0xFF636E72);
  }
}
