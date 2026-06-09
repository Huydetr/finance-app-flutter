class BudgetModel {
  final int? id;
  final double amount;
  final String monthYear; // Định dạng: "MM/yyyy"

  BudgetModel({
    this.id,
    required this.amount,
    required this.monthYear,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'month_year': monthYear,
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      monthYear: map['month_year'] as String,
    );
  }

  BudgetModel copyWith({
    int? id,
    double? amount,
    String? monthYear,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      monthYear: monthYear ?? this.monthYear,
    );
  }
}
