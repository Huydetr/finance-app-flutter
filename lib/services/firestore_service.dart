import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../models/savings_goal_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Lấy User ID hiện tại
  String? get _userId => _auth.currentUser?.uid;

  // Trả về tham chiếu đến Collection transactions của User hiện tại
  CollectionReference<Map<String, dynamic>>? get _transactionsRef {
    final uid = _userId;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('transactions');
  }

  // Trả về tham chiếu đến Collection budgets của User hiện tại
  CollectionReference<Map<String, dynamic>>? get _budgetsRef {
    final uid = _userId;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('budgets');
  }

  // Trả về tham chiếu đến Collection savings_goals của User hiện tại
  CollectionReference<Map<String, dynamic>>? get _savingsGoalsRef {
    final uid = _userId;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('savings_goals');
  }

  /// Thêm giao dịch mới
  Future<int> addTransaction(TransactionModel transaction) async {
    final ref = _transactionsRef;
    if (ref == null) throw Exception('Vui lòng đăng nhập để lưu dữ liệu');

    // Tạo ID kiểu int (dùng timestamp) để tương thích ngược với SQLite
    final int newId = DateTime.now().millisecondsSinceEpoch;
    
    final newTransaction = transaction.copyWith(id: newId);
    
    // Dùng id string để làm Document ID trên Firestore
    await ref.doc(newId.toString()).set(newTransaction.toMap());
    
    return newId;
  }

  /// Lấy tất cả giao dịch (Future)
  Future<List<TransactionModel>> getAllTransactions() async {
    final ref = _transactionsRef;
    if (ref == null) return [];

    final snapshot = await ref.orderBy('date', descending: true).get();
    return snapshot.docs.map((doc) => TransactionModel.fromMap(doc.data())).toList();
  }

  /// Lấy tất cả giao dịch (Stream realtime)
  Stream<List<TransactionModel>> getTransactionsStream() {
    final ref = _transactionsRef;
    if (ref == null) return const Stream.empty();

    return ref.orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TransactionModel.fromMap(doc.data())).toList();
    });
  }

  /// Cập nhật giao dịch
  Future<int> updateTransaction(TransactionModel transaction) async {
    final ref = _transactionsRef;
    if (ref == null) throw Exception('Vui lòng đăng nhập để lưu dữ liệu');

    if (transaction.id == null) return 0;

    await ref.doc(transaction.id.toString()).update(transaction.toMap());
    return transaction.id!;
  }

  /// Xóa giao dịch
  Future<int> deleteTransaction(int id) async {
    final ref = _transactionsRef;
    if (ref == null) throw Exception('Vui lòng đăng nhập để lưu dữ liệu');

    await ref.doc(id.toString()).delete();
    return id;
  }

  /// Tìm kiếm giao dịch
  Future<List<TransactionModel>> searchTransactions(String query) async {
    final all = await getAllTransactions();
    final lowerQuery = query.toLowerCase();
    return all.where((t) {
      return t.title.toLowerCase().contains(lowerQuery) ||
             t.note.toLowerCase().contains(lowerQuery) ||
             t.category.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Lấy giao dịch theo tháng
  Future<List<TransactionModel>> getTransactionsByMonth(int year, int month) async {
    final all = await getAllTransactions();
    return all.where((t) => t.date.year == year && t.date.month == month).toList();
  }

  /// Lấy thống kê 6 tháng gần nhất
  Future<List<Map<String, dynamic>>> getSixMonthStats(String type) async {
    final all = await getAllTransactions();
    final now = DateTime.now();
    List<Map<String, dynamic>> results = [];

    for (int i = 5; i >= 0; i--) {
      int targetMonth = now.month - i;
      int targetYear = now.year;
      if (targetMonth <= 0) {
        targetMonth += 12;
        targetYear -= 1;
      }

      double total = 0;
      final monthlyData = all.where((t) => t.date.year == targetYear && t.date.month == targetMonth);
      
      for (var t in monthlyData) {
        if (t.type == type) total += t.amount;
      }

      String monthStr = targetMonth.toString().padLeft(2, '0');
      results.add({
        'month_year': '$targetYear-$monthStr',
        'total': total,
      });
    }

    return results;
  }

  /// Xóa tất cả dữ liệu (Transactions)
  Future<void> deleteAllTransactions() async {
    final ref = _transactionsRef;
    if (ref == null) return;

    final snapshot = await ref.get();
    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ===================== BUDGET =====================

  Future<void> setBudget(BudgetModel budget) async {
    final ref = _budgetsRef;
    if (ref == null) throw Exception('Vui lòng đăng nhập');

    // Dùng monthYear làm Document ID để đảm bảo mỗi tháng chỉ có 1 budget
    await ref.doc(budget.monthYear.replaceAll('/', '-')).set(budget.toMap());
  }

  Future<BudgetModel?> getBudgetByMonth(String monthYear) async {
    final ref = _budgetsRef;
    if (ref == null) return null;

    final doc = await ref.doc(monthYear.replaceAll('/', '-')).get();
    if (doc.exists) {
      return BudgetModel.fromMap(doc.data()!);
    }
    return null;
  }

  /// Lấy Budget theo tháng (Stream realtime)
  Stream<BudgetModel?> getBudgetStreamByMonth(String monthYear) {
    final ref = _budgetsRef;
    if (ref == null) return const Stream.empty();

    return ref.doc(monthYear.replaceAll('/', '-')).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return BudgetModel.fromMap(doc.data()!);
      }
      return null;
    });
  }

  // ===================== SAVINGS GOAL =====================

  Future<int> addSavingsGoal(SavingsGoalModel goal) async {
    final ref = _savingsGoalsRef;
    if (ref == null) throw Exception('Vui lòng đăng nhập');

    final newId = DateTime.now().millisecondsSinceEpoch;
    final newGoal = goal.copyWith(id: newId);
    await ref.doc(newId.toString()).set(newGoal.toMap());
    return newId;
  }

  Future<List<SavingsGoalModel>> getAllSavingsGoals() async {
    final ref = _savingsGoalsRef;
    if (ref == null) return [];

    final snapshot = await ref.orderBy('created_at', descending: true).get();
    return snapshot.docs.map((doc) => SavingsGoalModel.fromMap(doc.data())).toList();
  }

  /// Lấy tất cả Savings Goals (Stream realtime)
  Stream<List<SavingsGoalModel>> getSavingsGoalsStream() {
    final ref = _savingsGoalsRef;
    if (ref == null) return const Stream.empty();

    return ref.orderBy('created_at', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => SavingsGoalModel.fromMap(doc.data())).toList();
    });
  }

  Future<int> updateSavingsGoal(SavingsGoalModel goal) async {
    final ref = _savingsGoalsRef;
    if (ref == null) throw Exception('Vui lòng đăng nhập');

    if (goal.id == null) return 0;
    await ref.doc(goal.id.toString()).update(goal.toMap());
    return goal.id!;
  }

  Future<int> deleteSavingsGoal(int id) async {
    final ref = _savingsGoalsRef;
    if (ref == null) throw Exception('Vui lòng đăng nhập');

    await ref.doc(id.toString()).delete();
    return id;
  }
}
