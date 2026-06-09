import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/transaction_controller.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';
import '../widgets/transaction_card.dart';
import 'add_transaction_screen.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});
  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final _controller = TransactionController();
  StreamSubscription? _txSubscription;
  List<TransactionModel> _transactions = [];
  List<TransactionModel> _filtered = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterType = 'all'; // all, income, expense
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _listenToTransactions();
  }

  @override
  void dispose() {
    _txSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _listenToTransactions() {
    setState(() => _isLoading = true);
    _txSubscription = _controller.getTransactionsStream().listen((data) {
      if (!mounted) return;
      setState(() {
        _transactions = data;
        _applyFilters();
        _isLoading = false;
      });
    });
  }

  void _applyFilters() {
    _filtered = _transactions.where((t) {
      if (_filterType != 'all' && t.type != _filterType) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return t.title.toLowerCase().contains(q) ||
            t.category.toLowerCase().contains(q) ||
            t.note.toLowerCase().contains(q);
      }
      return true;
    }).toList();
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
                      Icons.receipt_long_rounded,
                      color: AppColors.primaryStart,
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Danh sách giao dịch',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Search bar
                TextField(
                  controller: _searchController,
                  onChanged: (v) {
                    setState(() {
                      _searchQuery = v;
                      _applyFilters();
                    });
                  },
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm giao dịch...',
                    hintStyle: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textHint,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: AppColors.textHint,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _applyFilters();
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('Tất cả', 'all'),
                      const SizedBox(width: 8),
                      _filterChip('Thu nhập', 'income'),
                      const SizedBox(width: 8),
                      _filterChip('Chi tiêu', 'expense'),
                      const SizedBox(width: 8),
                      _filterChip('Tiết kiệm', 'savings'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryStart,
                    ),
                  )
                : _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          color: AppColors.textHint.withOpacity(0.5),
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Không tìm thấy giao dịch',
                          style: TextStyle(
                            color: AppColors.textHint,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      _listenToTransactions();
                    },
                    color: AppColors.primaryStart,
                    backgroundColor: AppColors.surface,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => TransactionCard(
                        transaction: _filtered[i],
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddTransactionScreen(
                                transaction: _filtered[i],
                              ),
                            ),
                          );
                          // Real-time stream handles data sync
                        },
                        onDelete: () async {
                          await _controller.deleteTransaction(_filtered[i].id!);
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
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String type) {
    final isSelected = _filterType == type;
    Color chipColor;
    if (type == 'income')
      chipColor = AppColors.income;
    else if (type == 'expense')
      chipColor = AppColors.expense;
    else if (type == 'savings')
      chipColor = AppColors.accent;
    else
      chipColor = AppColors.primaryStart;

    return GestureDetector(
      onTap: () {
        setState(() {
          _filterType = type;
          _applyFilters();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withOpacity(0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? chipColor.withOpacity(0.5)
                : AppColors.surfaceLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? chipColor : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
