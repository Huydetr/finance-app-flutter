// ============================================================
// Model giao dịch thu chi
// ============================================================

class TransactionModel {
  final int? id;
  final String title;
  final double amount;
  final String type; // 'income' hoặc 'expense'
  final String category;
  final String note;
  final DateTime date;
  final DateTime createdAt;
  final String? imagePath; // Thêm trường imagePath cho Giai đoạn 1

  TransactionModel({
    this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    this.note = '',
    required this.date,
    DateTime? createdAt,
    this.imagePath,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Kiểm tra giao dịch là thu nhập
  bool get isIncome => type == 'income';

  /// Kiểm tra giao dịch là chi tiêu
  bool get isExpense => type == 'expense';

  /// Kiểm tra giao dịch là tiết kiệm
  bool get isSavings => type == 'savings';

  /// Chuyển đổi sang Map để lưu vào SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type,
      'category': category,
      'note': note,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'image_path': imagePath, // Mới thêm
    };
  }

  /// Tạo TransactionModel từ Map (đọc từ SQLite)
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      category: map['category'] as String,
      note: map['note'] as String? ?? '',
      date: DateTime.parse(map['date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      imagePath: map['image_path'] as String?, // Mới thêm
    );
  }

  /// Tạo bản sao với các thuộc tính thay đổi
  TransactionModel copyWith({
    int? id,
    String? title,
    double? amount,
    String? type,
    String? category,
    String? note,
    DateTime? date,
    DateTime? createdAt,
    String? imagePath,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      note: note ?? this.note,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  @override
  String toString() {
    return 'TransactionModel(id: $id, title: $title, amount: $amount, type: $type, category: $category, imagePath: $imagePath)';
  }
}
