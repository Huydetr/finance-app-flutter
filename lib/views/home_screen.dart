import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/transaction_controller.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/summary_card.dart';
import '../widgets/transaction_card.dart';
import 'add_transaction_screen.dart';
import 'transaction_list_screen.dart';
import 'statistics_screen.dart';
import 'settings_screen.dart';
import 'budget_screen.dart';
import 'savings_goal_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TransactionController _controller = TransactionController();
  double _totalIncome = 0, _totalExpense = 0, _balance = 0;
  List<TransactionModel> _recentTransactions = [];
  bool _isLoading = true;
  late DateTime _selectedMonth;
  int _currentIndex = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  StreamSubscription? _txSubscription;
  List<TransactionModel> _allTransactions = [];

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _listenToTransactions();
    _checkFinancialHealth();
  }

  Future<void> _checkFinancialHealth() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1);
    final prevMonthStr =
        '${previousMonth.year}-${previousMonth.month.toString().padLeft(2, '0')}';

    final lastSeen = prefs.getString('last_seen_health_popup');

    if (lastSeen != prevMonthStr) {
      final income = await _controller.getTotalIncome(
        previousMonth.year,
        previousMonth.month,
      );
      final expense = await _controller.getTotalExpense(
        previousMonth.year,
        previousMonth.month,
      );
      final savings = await _controller.getTotalSavings(
        previousMonth.year,
        previousMonth.month,
      );

      if (income > 0 || expense > 0 || savings > 0) {
        if (mounted) {
          _showHealthPopup(previousMonth.month, income, expense, savings);
        }
      }

      await prefs.setString('last_seen_health_popup', prevMonthStr);
    }
  }

  void _showHealthPopup(
    int month,
    double income,
    double expense,
    double savings,
  ) {
    final balance = income - expense - savings;
    final isGood = balance >= 0;

    String message = '';
    if (balance < 0) {
      message =
          'Cảnh báo! Bạn đã chi tiêu vượt mức thu nhập trong tháng $month. Hãy cân đối lại ngân sách nhé!';
    } else if (savings > 0) {
      message =
          'Tuyệt vời! Tháng $month bạn đã quản lý chi tiêu rất tốt và còn trích ra được một khoản tiết kiệm. Cứ phát huy nhé!';
    } else {
      message =
          'Tháng $month bạn quản lý tài chính khá ổn định, nhưng hãy cố gắng đặt ra một mục tiêu tiết kiệm nhỏ cho tháng sau nhé!';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(
              isGood ? Icons.celebration_rounded : Icons.warning_amber_rounded,
              color: isGood ? AppColors.success : AppColors.expense,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Tổng kết Tháng $month',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatRow('Thu nhập', income, AppColors.income),
            const SizedBox(height: 8),
            _buildStatRow('Chi tiêu', expense, AppColors.expense),
            const SizedBox(height: 8),
            _buildStatRow('Tiết kiệm', savings, AppColors.accent),
            const Divider(color: AppColors.surfaceLight, height: 24),
            _buildStatRow(
              'Số dư',
              balance,
              isGood ? AppColors.income : AppColors.expense,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryStart,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Bắt đầu tháng mới',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textHint, fontSize: 14),
        ),
        Text(
          AppFormatters.formatCurrency(amount),
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _txSubscription?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _listenToTransactions() {
    setState(() => _isLoading = true);
    _txSubscription = _controller.getTransactionsStream().listen((
      transactions,
    ) {
      if (!mounted) return;
      _allTransactions = transactions;
      _recalculateStats();
      if (_fadeController.status == AnimationStatus.dismissed) {
        _fadeController.forward(from: 0);
      }
    });
  }

  void _recalculateStats() {
    final y = _selectedMonth.year, m = _selectedMonth.month;
    final monthlyTxs = _allTransactions
        .where((t) => t.date.year == y && t.date.month == m)
        .toList();

    double income = 0;
    double expense = 0;
    double savings = 0;

    for (var t in monthlyTxs) {
      if (t.isIncome)
        income += t.amount;
      else if (t.isExpense)
        expense += t.amount;
      else if (t.isSavings)
        savings += t.amount;
    }

    setState(() {
      _totalIncome = income;
      _totalExpense = expense;
      _balance = income - expense - savings;
      _recentTransactions = _allTransactions.take(10).toList();
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
    _recalculateStats();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildDashboard(),
      const TransactionListScreen(),
      const BudgetScreen(),
      const StatisticsScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: screens[_currentIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          );
          // Real-time stream handles data sync
        },
        backgroundColor: AppColors.primaryStart,
        elevation: 8,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.surfaceLight, width: 0.5),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          if (i == 0) _recalculateStats();
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.primaryStart,
        unselectedItemColor: AppColors.textHint,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Tổng quan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'Giao dịch',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Ngân sách',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_rounded),
            label: 'Thống kê',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async { _recalculateStats(); },
        color: AppColors.primaryStart,
        backgroundColor: AppColors.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildMonthSelector(),
                const SizedBox(height: 20),
                SummaryCard(
                  totalIncome: _totalIncome,
                  totalExpense: _totalExpense,
                  balance: _balance,
                  monthYear: AppFormatters.formatMonthYear(_selectedMonth),
                ),
                const SizedBox(height: 28),
                _buildQuickActions(),
                const SizedBox(height: 28),
                _buildRecentTransactions(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final h = DateTime.now().hour;
    final greeting = h < 12
        ? 'Chào buổi sáng!'
        : h < 18
        ? 'Chào buổi chiều!'
        : 'Chào buổi tối!';
    final icon = h < 12
        ? Icons.wb_sunny_rounded
        : h < 18
        ? Icons.wb_cloudy_rounded
        : Icons.nightlight_round;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  greeting,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Quản lý thu chi',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        GestureDetector(
          onDoubleTap: () async {
            // Dev test: Show current month stats
            final income = await _controller.getTotalIncome(
              DateTime.now().year,
              DateTime.now().month,
            );
            final expense = await _controller.getTotalExpense(
              DateTime.now().year,
              DateTime.now().month,
            );
            final savings = await _controller.getTotalSavings(
              DateTime.now().year,
              DateTime.now().month,
            );
            _showHealthPopup(DateTime.now().month, income, expense, savings);
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
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
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedMonth,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppColors.primaryStart,
                      surface: AppColors.surface,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setState(() => _selectedMonth = picked);
                _recalculateStats();
              }
            },
            child: Row(
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

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _actionBtn(
            Icons.arrow_downward_rounded,
            'Thu nhập',
            AppColors.incomeGradient,
            () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const AddTransactionScreen(initialType: 'income'),
                ),
              );
              // Real-time stream handles data sync
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionBtn(
            Icons.arrow_upward_rounded,
            'Chi tiêu',
            AppColors.expenseGradient,
            () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const AddTransactionScreen(initialType: 'expense'),
                ),
              );
              // Real-time stream handles data sync
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionBtn(
            Icons.savings_rounded,
            'Ống heo',
            AppColors.primaryGradient,
            () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavingsGoalScreen()),
              );
              // Real-time stream handles data sync
            },
          ),
        ),
      ],
    );
  }

  Widget _actionBtn(
    IconData icon,
    String label,
    LinearGradient gradient,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Giao dịch gần đây',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _currentIndex = 1),
              child: const Text(
                'Xem tất cả',
                style: TextStyle(
                  color: AppColors.primaryStart,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: AppColors.primaryStart),
          )
        else if (_recentTransactions.isEmpty)
          _buildEmptyState()
        else
          ...List.generate(
            _recentTransactions.length > 5 ? 5 : _recentTransactions.length,
            (i) => TransactionCard(
              transaction: _recentTransactions[i],
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddTransactionScreen(
                      transaction: _recentTransactions[i],
                    ),
                  ),
                );
                // Real-time stream handles data sync
              },
              onDelete: () async {
                await _controller.deleteTransaction(_recentTransactions[i].id!);
                // Real-time stream handles data sync
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Đã xóa giao dịch'),
                      backgroundColor: AppColors.surface,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_rounded,
            color: AppColors.textHint.withOpacity(0.5),
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Chưa có giao dịch nào',
            style: TextStyle(color: AppColors.textHint, fontSize: 15),
          ),
          const SizedBox(height: 4),
          const Text(
            'Nhấn + để thêm giao dịch đầu tiên',
            style: TextStyle(color: AppColors.textHint, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
