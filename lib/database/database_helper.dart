import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../models/savings_goal_model.dart';

// ============================================================
// SQLite Database Helper - Singleton Pattern
// Quản lý tất cả thao tác CRUD với database (Giai đoạn 1)
// ============================================================

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  /// Lấy instance database, tạo mới nếu chưa tồn tại
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Khởi tạo database
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'expense_tracker.db');
    return await openDatabase(
      path,
      version: 2, // Đã nâng cấp lên version 2 cho Giai đoạn 1
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Tạo bảng khi database được tạo lần đầu
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        note TEXT DEFAULT '',
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        image_path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        month_year TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE savings_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        target_amount REAL NOT NULL,
        saved_amount REAL NOT NULL,
        is_completed INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// Nâng cấp database từ version cũ
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Thêm cột image_path vào bảng transactions
      await db.execute('ALTER TABLE transactions ADD COLUMN image_path TEXT');
      
      // Tạo bảng budgets
      await db.execute('''
        CREATE TABLE budgets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount REAL NOT NULL,
          month_year TEXT NOT NULL
        )
      ''');

      // Tạo bảng savings_goals
      await db.execute('''
        CREATE TABLE savings_goals (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          target_amount REAL NOT NULL,
          saved_amount REAL NOT NULL,
          is_completed INTEGER NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }
  }

  // ===================== CRUD cho Transactions =====================

  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await database;
    return await db.insert(
      'transactions',
      transaction.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'date DESC, created_at DESC',
    );
    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<TransactionModel?> getTransactionById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return TransactionModel.fromMap(maps.first);
  }

  Future<List<TransactionModel>> getTransactionsByMonth(int year, int month) async {
    final db = await database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date DESC',
    );
    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<int> updateTransaction(TransactionModel transaction) async {
    final db = await database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<TransactionModel>> searchTransactions(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'title LIKE ? OR note LIKE ? OR category LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'date DESC',
    );
    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  // ===================== CRUD cho Budgets =====================

  Future<BudgetModel?> getBudgetByMonth(String monthYear) async {
    final db = await database;
    final maps = await db.query(
      'budgets',
      where: 'month_year = ?',
      whereArgs: [monthYear],
    );
    if (maps.isEmpty) return null;
    return BudgetModel.fromMap(maps.first);
  }

  Future<int> setBudget(BudgetModel budget) async {
    final db = await database;
    // Kiểm tra xem tháng này đã có ngân sách chưa
    final existing = await getBudgetByMonth(budget.monthYear);
    if (existing != null) {
      return await db.update(
        'budgets',
        budget.toMap()..remove('id'),
        where: 'month_year = ?',
        whereArgs: [budget.monthYear],
      );
    } else {
      return await db.insert(
        'budgets',
        budget.toMap()..remove('id'),
      );
    }
  }

  // ===================== CRUD cho Savings Goals =====================

  Future<int> insertSavingsGoal(SavingsGoalModel goal) async {
    final db = await database;
    return await db.insert(
      'savings_goals',
      goal.toMap()..remove('id'),
    );
  }

  Future<List<SavingsGoalModel>> getAllSavingsGoals() async {
    final db = await database;
    final maps = await db.query(
      'savings_goals',
      orderBy: 'is_completed ASC, created_at DESC', // Chưa hoàn thành lên trước
    );
    return maps.map((map) => SavingsGoalModel.fromMap(map)).toList();
  }

  Future<int> updateSavingsGoal(SavingsGoalModel goal) async {
    final db = await database;
    return await db.update(
      'savings_goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<int> deleteSavingsGoal(int id) async {
    final db = await database;
    return await db.delete(
      'savings_goals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ===================== Thống kê =====================

  Future<double> getTotalIncomeByMonth(int year, int month) async {
    final db = await database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();

    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE type = 'income' AND date >= ? AND date <= ?",
      [startDate, endDate],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalExpenseByMonth(int year, int month) async {
    final db = await database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();

    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE type = 'expense' AND date >= ? AND date <= ?",
      [startDate, endDate],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalSavingsByMonth(int year, int month) async {
    final db = await database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();

    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE type = 'savings' AND date >= ? AND date <= ?",
      [startDate, endDate],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getSixMonthStats(String type) async {
    final db = await database;
    final now = DateTime.now();
    // 5 tháng trước + tháng hiện tại = 6 tháng
    final startDate = DateTime(now.year, now.month - 5, 1).toIso8601String();
    final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59).toIso8601String();

    return await db.rawQuery(
      '''SELECT substr(date, 1, 7) as month_year, SUM(amount) as total
         FROM transactions 
         WHERE type = ? AND date >= ? AND date <= ?
         GROUP BY month_year
         ORDER BY month_year ASC''',
      [type, startDate, endDate],
    );
  }

  Future<List<Map<String, dynamic>>> getCategoryStats(
      int year, int month, String type) async {
    final db = await database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();

    return await db.rawQuery(
      '''SELECT category, SUM(amount) as total, COUNT(*) as count
         FROM transactions 
         WHERE type = ? AND date >= ? AND date <= ?
         GROUP BY category
         ORDER BY total DESC''',
      [type, startDate, endDate],
    );
  }

  Future<List<Map<String, dynamic>>> getDailyStats(
      int year, int month, String type) async {
    final db = await database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();

    return await db.rawQuery(
      '''SELECT substr(date, 1, 10) as day, SUM(amount) as total
         FROM transactions 
         WHERE type = ? AND date >= ? AND date <= ?
         GROUP BY day
         ORDER BY day ASC''',
      [type, startDate, endDate],
    );
  }

  Future<void> deleteAllTransactions() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('budgets');
    await db.delete('savings_goals');
  }

  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}
