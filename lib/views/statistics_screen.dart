import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/transaction_controller.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/chart_widget.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TransactionController();
  late TabController _tabController;
  late DateTime _selectedMonth;
  double _totalIncome = 0, _totalExpense = 0, _totalSavings = 0;

  List<Map<String, dynamic>> _expenseCategoryData = [];
  List<Map<String, dynamic>> _incomeCategoryData = [];
  List<Map<String, dynamic>> _savingsCategoryData = [];

  List<Map<String, dynamic>> _dailyExpenseData = [];
  List<Map<String, dynamic>> _dailyIncomeData = [];
  List<Map<String, dynamic>> _dailySavingsData = [];

  List<Map<String, dynamic>> _sixMonthExpense = [];
  List<Map<String, dynamic>> _sixMonthIncome = [];
  List<Map<String, dynamic>> _sixMonthSavings = [];

  bool _isLoading = true;
  StreamSubscription? _txSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedMonth = DateTime.now();

    // Khởi tạo stream để lắng nghe realtime
    _txSubscription = _controller.getTransactionsStream().listen((_) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    _txSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final y = _selectedMonth.year, m = _selectedMonth.month;

    final income = await _controller.getTotalIncome(y, m);
    final expense = await _controller.getTotalExpense(y, m);
    final savings = await _controller.getTotalSavings(y, m);

    final expCat = await _controller.getCategoryStats(y, m, 'expense');
    final incCat = await _controller.getCategoryStats(y, m, 'income');
    final savCat = await _controller.getCategoryStats(y, m, 'savings');

    final dailyExp = await _controller.getDailyStats(y, m, 'expense');
    final dailyInc = await _controller.getDailyStats(y, m, 'income');
    final dailySav = await _controller.getDailyStats(y, m, 'savings');

    final sixExp = await _controller.getSixMonthStats('expense');
    final sixInc = await _controller.getSixMonthStats('income');
    final sixSav = await _controller.getSixMonthStats('savings');

    setState(() {
      _totalIncome = income;
      _totalExpense = expense;
      _totalSavings = savings;

      _expenseCategoryData = expCat;
      _incomeCategoryData = incCat;
      _savingsCategoryData = savCat;

      _dailyExpenseData = dailyExp;
      _dailyIncomeData = dailyInc;
      _dailySavingsData = dailySav;

      _sixMonthExpense = sixExp;
      _sixMonthIncome = sixInc;
      _sixMonthSavings = sixSav;

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
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.pie_chart_rounded,
                      color: AppColors.primaryStart,
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Thống kê',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Month selector
                _buildMonthSelector(),
                const SizedBox(height: 16),
                // Summary
                _buildMiniSummary(),
                const SizedBox(height: 16),
                // Tab bar
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textHint,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    dividerHeight: 0,
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: const [
                      Tab(text: 'Chi tiêu'),
                      Tab(text: 'Thu nhập'),
                      Tab(text: 'Tiết kiệm'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Charts
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryStart,
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildChartView(
                        _expenseCategoryData,
                        _dailyExpenseData,
                        _sixMonthExpense,
                        'expense',
                      ),
                      _buildChartView(
                        _incomeCategoryData,
                        _dailyIncomeData,
                        _sixMonthIncome,
                        'income',
                      ),
                      _buildChartView(
                        _savingsCategoryData,
                        _dailySavingsData,
                        _sixMonthSavings,
                        'savings',
                      ),
                    ],
                  ),
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
          Text(
            'Tháng ${_selectedMonth.month}/${_selectedMonth.year}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
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

  Widget _buildMiniSummary() {
    return Row(
      children: [
        Expanded(child: _miniStat('Thu nhập', _totalIncome, AppColors.income)),
        const SizedBox(width: 8),
        Expanded(
          child: _miniStat('Chi tiêu', _totalExpense, AppColors.expense),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _miniStat('Tiết kiệm', _totalSavings, AppColors.accent),
        ),
      ],
    );
  }

  Widget _miniStat(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textHint, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            AppFormatters.formatCompact(amount.abs()),
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartView(
    List<Map<String, dynamic>> catData,
    List<Map<String, dynamic>> dailyData,
    List<Map<String, dynamic>> sixMonthData,
    String type,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pie chart
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
                const Text(
                  'Theo danh mục',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                CategoryPieChart(categoryData: catData, type: type),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Daily Bar chart
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
                const Text(
                  'Theo ngày',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                DailyBarChart(
                  dailyData: dailyData,
                  type: type,
                  year: _selectedMonth.year,
                  month: _selectedMonth.month,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 6-Month Bar chart
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
                const Text(
                  '6 tháng gần nhất',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SixMonthBarChart(sixMonthData: sixMonthData, type: type),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
