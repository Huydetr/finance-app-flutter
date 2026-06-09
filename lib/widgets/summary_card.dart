import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

// ============================================================
// Widget Card tổng kết thu chi
// ============================================================

class SummaryCard extends StatelessWidget {
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final String monthYear;

  const SummaryCard({
    super.key,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.monthYear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A3E), Color(0xFF0D1B3E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primaryStart.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryStart.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tiêu đề tháng
          Text(
            'Tháng $monthYear',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          // Số dư
          Text(
            AppFormatters.formatCurrency(balance.abs()),
            style: TextStyle(
              color: balance >= 0 ? AppColors.income : AppColors.expense,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            balance >= 0 ? 'Số dư dương' : 'Số dư âm',
            style: TextStyle(
              color: balance >= 0
                  ? AppColors.income.withOpacity(0.7)
                  : AppColors.expense.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          // Thu nhập & Chi tiêu
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.arrow_downward_rounded,
                  label: 'Thu nhập',
                  amount: totalIncome,
                  color: AppColors.income,
                  gradient: AppColors.incomeGradient,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Chi tiêu',
                  amount: totalExpense,
                  color: AppColors.expense,
                  gradient: AppColors.expenseGradient,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required double amount,
    required Color color,
    required LinearGradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppFormatters.formatCurrency(amount),
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
