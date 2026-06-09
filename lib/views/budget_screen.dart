import 'package:flutter/material.dart';
import '../models/budget_model.dart';
import '../services/firestore_service.dart';
import '../controllers/transaction_controller.dart';
import '../utils/constants.dart';
import 'dart:async';
import '../utils/formatters.dart';
import '../models/transaction_model.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final FirestoreService _dbService = FirestoreService();
  final TransactionController _txController = TransactionController();
  BudgetModel? _currentBudget;
  double _totalExpense = 0.0;
  double _totalSavings = 0.0;
  List<Map<String, dynamic>> _savingsList = [];
  bool _isLoading = true;
  late DateTime _selectedMonth;
  StreamSubscription? _txSubscription;
  StreamSubscription? _budgetSubscription;
  List<TransactionModel> _allTransactions = [];

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    _listenToStreams();
  }

  @override
  void dispose() {
    _txSubscription?.cancel();
    _budgetSubscription?.cancel();
    super.dispose();
  }

  void _listenToStreams() {
    setState(() => _isLoading = true);

    _txSubscription?.cancel();
    _txSubscription = _txController.getTransactionsStream().listen((
      transactions,
    ) {
      if (!mounted) return;
      _allTransactions = transactions;
      _recalculateStats();
    });

    _subscribeToBudget();
  }

  void _subscribeToBudget() {
    _budgetSubscription?.cancel();
    final monthYear = AppFormatters.formatMonthYear(_selectedMonth);
    _budgetSubscription = _dbService.getBudgetStreamByMonth(monthYear).listen((
      budget,
    ) {
      if (!mounted) return;
      setState(() {
        _currentBudget = budget;
      });
    });
  }

  void _recalculateStats() {
    final y = _selectedMonth.year, m = _selectedMonth.month;
    final txList = _allTransactions
        .where((t) => t.date.year == y && t.date.month == m)
        .toList();

    double expense = 0.0;
    double savings = 0.0;
    final savingsTxs = <TransactionModel>[];

    for (var t in txList) {
      if (t.isExpense) expense += t.amount;
      if (t.isSavings) {
        savings += t.amount;
        savingsTxs.add(t);
      }
    }

    Map<String, double> savingsSums = {};
    for (var t in savingsTxs) {
      savingsSums[t.note] = (savingsSums[t.note] ?? 0) + t.amount;
    }

    final savingsList = savingsSums.entries
        .map((e) => {'goal': e.key, 'total': e.value})
        .toList();

    setState(() {
      _totalExpense = expense;
      _totalSavings = savings;
      _savingsList = savingsList;
      _isLoading = false;
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
    _subscribeToBudget();
    _recalculateStats();
  }

  Future<void> _showSetBudgetDialog() async {
    final controller = TextEditingController(
      text: _currentBudget != null
          ? _currentBudget!.amount.toStringAsFixed(0)
          : '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Thiết lập ngân sách',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [CurrencyInputFormatter()],
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Nhập số tiền...',
            hintStyle: TextStyle(color: AppColors.textHint),
            suffixText: '₫',
          ),
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
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text(
              'Lưu',
              style: TextStyle(color: AppColors.primaryStart),
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final amount = double.tryParse(result.replaceAll('.', ''));
      if (amount != null && amount > 0) {
        final newBudget = BudgetModel(
          id: _currentBudget?.id,
          amount: amount,
          monthYear: AppFormatters.formatMonthYear(_selectedMonth),
        );
        await _dbService.setBudget(newBudget);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.primaryStart,
                  size: 24,
                ),
                SizedBox(width: 10),
                Text(
                  'Ngân sách tháng',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildMonthSelector(),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildBudgetContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => _changeMonth(-1),
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: AppColors.textSecondary,
            ),
          ),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.primaryStart,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Tháng ${_selectedMonth.month}/${_selectedMonth.year}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => _changeMonth(1),
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetContent() {
    if (_currentBudget == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 60,
              color: AppColors.textHint.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa thiết lập ngân sách',
              style: TextStyle(color: AppColors.textHint, fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showSetBudgetDialog,
              icon: const Icon(Icons.add),
              label: const Text('Thiết lập ngay'),
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

    final double totalUsed = _totalExpense + _totalSavings;
    final double progress = (totalUsed / _currentBudget!.amount).clamp(
      0.0,
      1.0,
    );
    Color progressColor = AppColors.success;
    if (progress > 0.9) {
      progressColor = AppColors.expense; // Đỏ
    } else if (progress > 0.7) {
      progressColor = Colors.orange; // Vàng
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ngân sách tháng',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: _showSetBudgetDialog,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryStart.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: AppColors.primaryStart,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  AppFormatters.formatCurrency(_currentBudget!.amount),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Đã chi (Thực tế)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '- ${AppFormatters.formatCurrency(_totalExpense)}',
                      style: const TextStyle(
                        color: AppColors.expense,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (_savingsList.isNotEmpty) const SizedBox(height: 8),
                ..._savingsList.map((s) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bỏ ống heo [${s['goal']}]',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '- ${AppFormatters.formatCurrency((s['total'] as num).toDouble())}',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(color: AppColors.surfaceLight, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tổng cộng (Đã dùng)',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      AppFormatters.formatCurrency(totalUsed),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 14,
                    backgroundColor: AppColors.surfaceLight,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Đã dùng ${(progress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: progressColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Còn lại: ${AppFormatters.formatCurrency((_currentBudget!.amount - totalUsed).clamp(0, double.infinity))}',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
