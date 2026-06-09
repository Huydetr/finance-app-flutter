class SavingsGoalModel {
  final int? id;
  final String title;
  final double targetAmount;
  final double savedAmount;
  final bool isCompleted;
  final DateTime createdAt;

  SavingsGoalModel({
    this.id,
    required this.title,
    required this.targetAmount,
    this.savedAmount = 0.0,
    this.isCompleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'target_amount': targetAmount,
      'saved_amount': savedAmount,
      'is_completed': isCompleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SavingsGoalModel.fromMap(Map<String, dynamic> map) {
    return SavingsGoalModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      targetAmount: (map['target_amount'] as num).toDouble(),
      savedAmount: (map['saved_amount'] as num).toDouble(),
      isCompleted: map['is_completed'] == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  SavingsGoalModel copyWith({
    int? id,
    String? title,
    double? targetAmount,
    double? savedAmount,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return SavingsGoalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
