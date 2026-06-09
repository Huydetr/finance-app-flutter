import '../services/firestore_service.dart';
import '../models/transaction_model.dart';
import 'package:intl/intl.dart';

// ============================================================
// Controller quản lý logic nghiệp vụ cho giao dịch thu chi
// ============================================================

class TransactionController {
  final FirestoreService _dbService = FirestoreService();

  // ===================== CRUD =====================

  /// Thêm giao dịch mới
  Future<int> addTransaction(TransactionModel transaction) async {
    return await _dbService.addTransaction(transaction);
  }

  /// Lấy tất cả giao dịch
  Future<List<TransactionModel>> getAllTransactions() async {
    return await _dbService.getAllTransactions();
  }

  /// Lấy Stream tất cả giao dịch realtime
  Stream<List<TransactionModel>> getTransactionsStream() {
    return _dbService.getTransactionsStream();
  }

  /// Lấy giao dịch theo tháng
  Future<List<TransactionModel>> getTransactionsByMonth(int year, int month) async {
    return await _dbService.getTransactionsByMonth(year, month);
  }

  /// Cập nhật giao dịch
  Future<int> updateTransaction(TransactionModel transaction) async {
    return await _dbService.updateTransaction(transaction);
  }

  /// Xóa giao dịch
  Future<int> deleteTransaction(int id) async {
    return await _dbService.deleteTransaction(id);
  }

  /// Tìm kiếm giao dịch
  Future<List<TransactionModel>> searchTransactions(String query) async {
    return await _dbService.searchTransactions(query);
  }

  // ===================== Thống kê =====================

  /// Lấy tổng thu nhập tháng
  Future<double> getTotalIncome(int year, int month) async {
    final list = await getTransactionsByMonth(year, month);
    return list.where((t) => t.isIncome).fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  /// Lấy tổng chi tiêu tháng
  Future<double> getTotalExpense(int year, int month) async {
    final list = await getTransactionsByMonth(year, month);
    return list.where((t) => t.isExpense).fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  /// Lấy tổng tiết kiệm tháng
  Future<double> getTotalSavings(int year, int month) async {
    final list = await getTransactionsByMonth(year, month);
    return list.where((t) => t.isSavings).fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  /// Tính số dư = Thu nhập - Chi tiêu - Tiết kiệm
  Future<double> getBalance(int year, int month) async {
    final income = await getTotalIncome(year, month);
    final expense = await getTotalExpense(year, month);
    final savings = await getTotalSavings(year, month);
    return income - expense - savings;
  }

  /// Lấy thống kê 6 tháng gần nhất (Bar Chart)
  Future<List<Map<String, dynamic>>> getSixMonthStats(String type) async {
    return await _dbService.getSixMonthStats(type);
  }

  /// Lấy thống kê theo danh mục
  Future<List<Map<String, dynamic>>> getCategoryStats(
      int year, int month, String type) async {
    final list = await getTransactionsByMonth(year, month);
    final filtered = list.where((t) => t.type == type);
    
    Map<String, double> categorySums = {};
    for (var t in filtered) {
      categorySums[t.category] = (categorySums[t.category] ?? 0) + t.amount;
    }

    return categorySums.entries.map((e) => {
      'category': e.key,
      'total': e.value,
    }).toList();
  }

  /// Lấy thống kê theo ngày
  Future<List<Map<String, dynamic>>> getDailyStats(
      int year, int month, String type) async {
    final list = await getTransactionsByMonth(year, month);
    final filtered = list.where((t) => t.type == type);

    Map<String, double> dailySums = {};
    for (var t in filtered) {
      String dateStr = DateFormat('yyyy-MM-dd').format(t.date);
      dailySums[dateStr] = (dailySums[dateStr] ?? 0) + t.amount;
    }

    var result = dailySums.entries.map((e) => {
      'day': e.key,
      'total': e.value,
    }).toList();
    
    result.sort((a, b) => (a['day'] as String).compareTo(b['day'] as String));
    return result;
  }

  /// Lấy giao dịch gần đây (giới hạn số lượng)
  Future<List<TransactionModel>> getRecentTransactions({int limit = 5}) async {
    final all = await getAllTransactions();
    return all.take(limit).toList();
  }

  /// Xóa tất cả dữ liệu
  Future<void> deleteAllData() async {
    await _dbService.deleteAllTransactions();
  }
}
