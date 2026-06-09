import 'package:flutter/material.dart';
import '../models/savings_goal_model.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../models/transaction_model.dart';
import '../controllers/transaction_controller.dart';
import 'dart:async';

class SavingsGoalScreen extends StatefulWidget {
  const SavingsGoalScreen({super.key});

  @override
  State<SavingsGoalScreen> createState() => _SavingsGoalScreenState();
}

class _SavingsGoalScreenState extends State<SavingsGoalScreen> {
  final FirestoreService _dbService = FirestoreService();
  List<SavingsGoalModel> _goals = [];
  bool _isLoading = true;
  StreamSubscription? _goalSubscription;

  @override
  void initState() {
    super.initState();
    _listenToStreams();
  }

  @override
  void dispose() {
    _goalSubscription?.cancel();
    super.dispose();
  }

  void _listenToStreams() {
    setState(() => _isLoading = true);
    _goalSubscription?.cancel();
    _goalSubscription = _dbService.getSavingsGoalsStream().listen((goals) {
      if (!mounted) return;
      setState(() {
        _goals = goals;
        _isLoading = false;
      });
    });
  }

  Future<void> _showAddGoalDialog() async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Mục tiêu tiết kiệm',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Tên mục tiêu (VD: Đổi xe mới)',
                hintStyle: TextStyle(color: AppColors.textHint),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Số tiền cần đạt',
                hintStyle: TextStyle(color: AppColors.textHint),
                suffixText: '₫',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              final amount = double.tryParse(
                amountController.text.replaceAll('.', ''),
              );
              if (titleController.text.isNotEmpty &&
                  amount != null &&
                  amount > 0) {
                final newGoal = SavingsGoalModel(
                  title: titleController.text,
                  targetAmount: amount,
                  savedAmount: 0,
                  isCompleted: false,
                  createdAt: DateTime.now(),
                );
                await _dbService.addSavingsGoal(newGoal);
                Navigator.pop(ctx, true);
              }
            },
            child: const Text(
              'Tạo',
              style: TextStyle(color: AppColors.primaryStart),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddMoneyDialog(SavingsGoalModel goal) async {
    if (goal.isCompleted) return;
    final amountController = TextEditingController();

    final result = await showDialog<dynamic>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Bỏ ống heo: ${goal.title}',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          inputFormatters: [CurrencyInputFormatter()],
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Nhập số tiền góp...',
            hintStyle: TextStyle(color: AppColors.textHint),
            suffixText: '₫',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              final amount = double.tryParse(
                amountController.text.replaceAll('.', ''),
              );
              if (amount != null && amount > 0) {
                double newSavedAmount = goal.savedAmount + amount;
                bool newIsCompleted = goal.isCompleted;
                if (newSavedAmount >= goal.targetAmount) {
                  newSavedAmount = goal.targetAmount;
                  newIsCompleted = true;
                }
                final updatedGoal = goal.copyWith(
                  savedAmount: newSavedAmount,
                  isCompleted: newIsCompleted,
                );
                await _dbService.updateSavingsGoal(updatedGoal);

                // Tự động tạo giao dịch tiết kiệm
                final transaction = TransactionModel(
                  title: 'Góp tiền: ${goal.title}',
                  amount: amount,
                  type: 'savings',
                  category: 'Ống heo',
                  note: goal.title, // Lưu note làm từ khóa nhóm
                  date: DateTime.now(),
                );
                await TransactionController().addTransaction(transaction);

                Navigator.pop(ctx, updatedGoal);
              }
            },
            child: const Text(
              'Góp tiền',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null && result is SavingsGoalModel) {
      if (result.isCompleted) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                '🎉 Chúc mừng!',
                style: TextStyle(color: AppColors.income),
              ),
              content: Text(
                'Bạn đã đạt được mục tiêu ${result.title}. Giấc mơ đã thành hiện thực!',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Tuyệt vời',
                    style: TextStyle(color: AppColors.primaryStart),
                  ),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Ống heo tiết kiệm',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primaryStart),
            onPressed: _showAddGoalDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _goals.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _goals.length,
              itemBuilder: (context, index) {
                final goal = _goals[index];
                return _buildGoalCard(goal);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.savings_outlined,
            size: 80,
            color: AppColors.textHint.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có mục tiêu nào',
            style: TextStyle(color: AppColors.textHint, fontSize: 16),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showAddGoalDialog,
            icon: const Icon(Icons.add),
            label: const Text('Tạo mục tiêu đầu tiên'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryStart,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(SavingsGoalModel goal) {
    final progress = (goal.savedAmount / goal.targetAmount).clamp(0.0, 1.0);
    final bool isCompleted = goal.isCompleted;

    return Dismissible(
      key: Key('goal_${goal.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.expense.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: AppColors.expense,
          size: 28,
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Xác nhận xóa',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: Text(
              'Bạn có chắc muốn đập ống heo "${goal.title}"?',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Hủy',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Đập heo',
                  style: TextStyle(color: AppColors.expense),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        await _dbService.deleteSavingsGoal(goal.id!);
      },
      child: GestureDetector(
        onTap: () => _showAddMoneyDialog(goal),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCompleted
                  ? AppColors.income.withOpacity(0.5)
                  : AppColors.surfaceLight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      style: TextStyle(
                        color: isCompleted
                            ? AppColors.income
                            : AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isCompleted)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.income,
                      size: 22,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Đã góp',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    AppFormatters.formatCurrency(goal.targetAmount),
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormatters.formatCurrency(goal.savedAmount),
                    style: TextStyle(
                      color: isCompleted ? AppColors.income : AppColors.accent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: isCompleted ? AppColors.income : AppColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: AppColors.surfaceLight,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isCompleted ? AppColors.income : AppColors.accent,
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
