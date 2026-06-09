import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

// ============================================================
// Widget biểu đồ tròn theo danh mục
// ============================================================

class CategoryPieChart extends StatelessWidget {
  final List<Map<String, dynamic>> categoryData;
  final String type; // 'income' hoặc 'expense'

  const CategoryPieChart({
    super.key,
    required this.categoryData,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    if (categoryData.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text(
          'Chưa có dữ liệu',
          style: TextStyle(color: AppColors.textHint, fontSize: 14),
        ),
      );
    }

    final total = categoryData.fold<double>(
      0, (sum, item) => sum + ((item['total'] as num?)?.toDouble() ?? 0),
    );

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 50,
              sections: categoryData.asMap().entries.map((entry) {
                final data = entry.value;
                final amount = (data['total'] as num?)?.toDouble() ?? 0;
                final percentage = total > 0 ? (amount / total * 100) : 0;
                final color = AppCategories.getColor(data['category'] as String);

                return PieChartSectionData(
                  color: color,
                  value: amount,
                  title: '${percentage.toStringAsFixed(0)}%',
                  radius: 45,
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Legend
        ...categoryData.map((data) {
          final categoryName = data['category'] as String;
          final amount = (data['total'] as num?)?.toDouble() ?? 0;
          final percentage = total > 0 ? (amount / total * 100) : 0;
          final color = AppCategories.getColor(categoryName);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    categoryName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  AppFormatters.formatCurrency(amount),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ============================================================
// Widget biểu đồ cột theo ngày
// ============================================================

class DailyBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> dailyData;
  final String type;
  final int year;
  final int month;

  const DailyBarChart({
    super.key,
    required this.dailyData,
    required this.type,
    required this.year,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    if (dailyData.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text(
          'Chưa có dữ liệu',
          style: TextStyle(color: AppColors.textHint, fontSize: 14),
        ),
      );
    }

    final barColor = type == 'income' ? AppColors.income : AppColors.expense;
    final maxAmount = dailyData.fold<double>(
      0, (max, item) {
        final val = (item['total'] as num?)?.toDouble() ?? 0;
        return val > max ? val : max;
      },
    );

    // Tạo map ngày -> tổng tiền
    final Map<int, double> dayMap = {};
    for (var data in dailyData) {
      final dayStr = data['day'] as String;
      final day = int.tryParse(dayStr.substring(8, 10)) ?? 0;
      dayMap[day] = (data['total'] as num?)?.toDouble() ?? 0;
    }

    final daysInMonth = DateTime(year, month + 1, 0).day;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxAmount * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final day = group.x.toInt();
                final amount = dayMap[day] ?? 0;
                return BarTooltipItem(
                  'Ngày $day\n${AppFormatters.formatCurrency(amount)}',
                  TextStyle(
                    color: barColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final day = value.toInt();
                  if (day % 5 == 1 || day == daysInMonth) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '$day',
                        style: const TextStyle(
                          color: AppColors.textHint,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    AppFormatters.formatCompact(value),
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxAmount > 0 ? maxAmount / 4 : 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.surfaceLight,
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(daysInMonth, (index) {
            final day = index + 1;
            final amount = dayMap[day] ?? 0;
            return BarChartGroupData(
              x: day,
              barRods: [
                BarChartRodData(
                  toY: amount,
                  color: amount > 0 ? barColor : Colors.transparent,
                  width: daysInMonth > 20 ? 6 : 10,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ============================================================
// Widget biểu đồ cột 6 tháng gần nhất
// ============================================================

class SixMonthBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> sixMonthData;
  final String type;

  const SixMonthBarChart({
    super.key,
    required this.sixMonthData,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    if (sixMonthData.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text(
          'Chưa có dữ liệu',
          style: TextStyle(color: AppColors.textHint, fontSize: 14),
        ),
      );
    }

    final barColor = type == 'income' 
        ? AppColors.income 
        : (type == 'savings' ? AppColors.accent : AppColors.expense);
        
    final maxAmount = sixMonthData.fold<double>(
      0, (max, item) {
        final val = (item['total'] as num?)?.toDouble() ?? 0;
        return val > max ? val : max;
      },
    );

    final displayData = sixMonthData.length > 6 
        ? sixMonthData.sublist(sixMonthData.length - 6) 
        : sixMonthData;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxAmount * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final amount = (displayData[group.x.toInt()]['total'] as num?)?.toDouble() ?? 0;
                final monthYear = displayData[group.x.toInt()]['month_year'] as String; // YYYY-MM
                final parts = monthYear.split('-');
                final label = '${parts[1]}/${parts[0]}';
                
                String pctStr = '';
                if (group.x.toInt() > 0) {
                  final prevAmount = (displayData[group.x.toInt() - 1]['total'] as num?)?.toDouble() ?? 0;
                  if (prevAmount > 0) {
                    final diff = amount - prevAmount;
                    final pct = (diff / prevAmount) * 100;
                    if (pct > 0) {
                      pctStr = '\n▲ ${pct.toStringAsFixed(1)}%';
                    } else if (pct < 0) {
                      pctStr = '\n▼ ${pct.abs().toStringAsFixed(1)}%';
                    } else {
                      pctStr = '\n= 0%';
                    }
                  } else if (prevAmount == 0 && amount > 0) {
                    pctStr = '\n▲ 100%';
                  }
                }
                
                return BarTooltipItem(
                  'Tháng $label\n${AppFormatters.formatCurrency(amount)}$pctStr',
                  TextStyle(
                    color: barColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < displayData.length) {
                    final monthYear = displayData[index]['month_year'] as String;
                    final parts = monthYear.split('-');
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'T${parts[1]}',
                        style: const TextStyle(
                          color: AppColors.textHint,
                          fontSize: 11,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    AppFormatters.formatCompact(value),
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxAmount > 0 ? maxAmount / 4 : 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.surfaceLight,
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(displayData.length, (index) {
            final amount = (displayData[index]['total'] as num?)?.toDouble() ?? 0;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: amount,
                  color: amount > 0 ? barColor : Colors.transparent,
                  width: 20,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
