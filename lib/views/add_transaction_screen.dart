import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/transaction_controller.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../models/savings_goal_model.dart';

class AddTransactionScreen extends StatefulWidget {
  final String? initialType;
  final TransactionModel? transaction;
  const AddTransactionScreen({super.key, this.initialType, this.transaction});
  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TransactionController();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _type = 'expense';
  String _category = 'Ăn uống';
  DateTime _date = DateTime.now();
  bool _isSaving = false;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool get _isEditing => widget.transaction != null;

  bool _isQuickSave = false;
  bool _isImageDeleted = false;
  SavingsGoalModel? _selectedQuickSaveGoal;
  final _quickSaveAmountController = TextEditingController();
  List<SavingsGoalModel> _activeGoals = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) _type = widget.initialType!;
    if (_isEditing) {
      final t = widget.transaction!;
      _titleController.text = t.title;
      _amountController.text = t.amount.toStringAsFixed(0);
      _noteController.text = t.note;
      _type = t.type;
      _category = t.category;
      _date = t.date;
      if (t.imagePath != null) {
        // Nếu là file local (ảnh cũ chưa upload), mới khởi tạo File
        // Nếu là Firebase URL, không khởi tạo File, ta sẽ dùng widget.transaction!.imagePath để hiển thị
        if (!t.imagePath!.startsWith('http')) {
          _imageFile = File(t.imagePath!);
        }
      }
    }
    if (_type == 'income') _category = 'Lương';
    _loadActiveGoals();
  }

  Future<void> _loadActiveGoals() async {
    final goals = await FirestoreService().getAllSavingsGoals();
    if (mounted) {
      setState(() {
        _activeGoals = goals.where((g) => !g.isCompleted).toList();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _quickSaveAmountController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _categories => _type == 'income'
      ? AppCategories.incomeCategories
      : AppCategories.expenseCategories;

  Future<String?> _uploadImageToCloud(File image) async {
    return await StorageService().uploadImage(image);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Không thể tải ảnh')));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    String? finalImagePath = widget.transaction?.imagePath;
    if (_imageFile != null) {
      // Nếu file khác với URL ảnh cũ (ảnh mới chụp/chọn)
      if (!(_isEditing && _imageFile!.path == widget.transaction?.imagePath)) {
        finalImagePath = await _uploadImageToCloud(_imageFile!);

        // Nếu có ảnh cũ trên Cloud thì xóa đi cho sạch dung lượng
        if (_isEditing &&
            widget.transaction?.imagePath != null &&
            widget.transaction!.imagePath!.startsWith('http')) {
          await StorageService().deleteImage(widget.transaction!.imagePath!);
        }
      }
    } else {
      // Người dùng đã xóa ảnh
      if (_isImageDeleted) {
        if (_isEditing &&
            widget.transaction?.imagePath != null &&
            widget.transaction!.imagePath!.startsWith('http')) {
          await StorageService().deleteImage(widget.transaction!.imagePath!);
        }
        finalImagePath = null;
      }
    }

    final t = TransactionModel(
      id: widget.transaction?.id,
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text.replaceAll('.', '')),
      type: _type,
      category: _category,
      note: _noteController.text.trim(),
      date: _date,
      imagePath: finalImagePath,
    );
    if (_isEditing) {
      await _controller.updateTransaction(t);
    } else {
      await _controller.addTransaction(t);

      if (_type == 'income' && _isQuickSave && _selectedQuickSaveGoal != null) {
        final qsAmountStr = _quickSaveAmountController.text.replaceAll('.', '');
        final qsAmount = double.tryParse(qsAmountStr);
        if (qsAmount != null && qsAmount > 0) {
          final goal = _selectedQuickSaveGoal!;
          double newSavedAmount = goal.savedAmount + qsAmount;
          bool newIsCompleted = goal.isCompleted;
          if (newSavedAmount >= goal.targetAmount) {
            newSavedAmount = goal.targetAmount;
            newIsCompleted = true;
          }
          final updatedGoal = goal.copyWith(
            savedAmount: newSavedAmount,
            isCompleted: newIsCompleted,
          );
          await FirestoreService().updateSavingsGoal(updatedGoal);

          final savingsT = TransactionModel(
            title: 'Góp tiền: ${goal.title}',
            amount: qsAmount,
            type: 'savings',
            category: 'Ống heo',
            note: goal.title,
            date: _date,
          );
          await _controller.addTransaction(savingsT);
        }
      }
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Sửa giao dịch' : 'Thêm giao dịch',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.expense),
              onPressed: () async {
                final confirm = await showDialog<bool>(
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
                    content: const Text(
                      'Bạn có chắc muốn xóa giao dịch này?',
                      style: TextStyle(color: AppColors.textSecondary),
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
                          'Xóa',
                          style: TextStyle(color: AppColors.expense),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  if (widget.transaction!.imagePath != null) {
                    await StorageService().deleteImage(
                      widget.transaction!.imagePath!,
                    );
                  }
                  await _controller.deleteTransaction(widget.transaction!.id!);
                  if (mounted) Navigator.pop(context, true);
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type selector
              _buildTypeSelector(),
              const SizedBox(height: 24),
              // Amount
              _buildLabel('Số tiền'),
              const SizedBox(height: 8),
              _buildAmountField(),
              const SizedBox(height: 20),
              // Title
              _buildLabel('Tiêu đề'),
              const SizedBox(height: 8),
              _buildTextField(
                _titleController,
                'Nhập tiêu đề giao dịch',
                Icons.edit_rounded,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Vui lòng nhập tiêu đề'
                    : null,
              ),
              const SizedBox(height: 20),
              // Category
              _buildLabel('Danh mục'),
              const SizedBox(height: 12),
              _buildCategorySelector(),
              const SizedBox(height: 20),
              // Date
              _buildLabel('Ngày'),
              const SizedBox(height: 8),
              _buildDatePicker(),
              const SizedBox(height: 20),
              // Note
              _buildLabel('Ghi chú (tùy chọn)'),
              const SizedBox(height: 8),
              _buildTextField(
                _noteController,
                'Thêm ghi chú...',
                Icons.note_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              // Image
              _buildImagePicker(),
              // Quick Save
              _buildQuickSaveSection(),
              const SizedBox(height: 32),
              // Save button
              _buildSaveButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: _typeTab(
              'expense',
              'Chi tiêu',
              Icons.arrow_upward_rounded,
              AppColors.expense,
            ),
          ),
          Expanded(
            child: _typeTab(
              'income',
              'Thu nhập',
              Icons.arrow_downward_rounded,
              AppColors.income,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSaveSection() {
    if (_type != 'income' || _activeGoals.isEmpty || _isEditing)
      return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Divider(color: AppColors.surfaceLight),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.savings_rounded, color: AppColors.accent, size: 24),
                SizedBox(width: 10),
                Text(
                  'Trích một phần vào ống heo',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Switch(
              value: _isQuickSave,
              onChanged: (val) {
                setState(() {
                  _isQuickSave = val;
                  if (val && _selectedQuickSaveGoal == null) {
                    _selectedQuickSaveGoal = _activeGoals.first;
                  }
                });
              },
              activeColor: AppColors.accent,
            ),
          ],
        ),
        if (_isQuickSave) ...[
          const SizedBox(height: 16),
          _buildLabel('Chọn ống heo'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<SavingsGoalModel>(
                value: _selectedQuickSaveGoal,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
                ),
                items: _activeGoals.map((goal) {
                  return DropdownMenuItem<SavingsGoalModel>(
                    value: goal,
                    child: Text(
                      goal.title,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  );
                }).toList(),
                onChanged: (val) =>
                    setState(() => _selectedQuickSaveGoal = val),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLabel('Số tiền trích'),
          const SizedBox(height: 8),
          _buildTextField(
            _quickSaveAmountController,
            'Nhập số tiền...',
            Icons.attach_money_rounded,
            keyboardType: TextInputType.number,
            validator: (v) {
              if (!_isQuickSave) return null;
              if (v == null || v.trim().isEmpty) return 'Vui lòng nhập số tiền';
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _typeTab(String type, String label, IconData icon, Color color) {
    final isSelected = _type == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _type = type;
          _category = _categories.first['name'] as String;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: color.withOpacity(0.3)) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? color : AppColors.textHint,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppColors.textHint,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    final color = _type == 'income' ? AppColors.income : AppColors.expense;
    return TextFormField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      inputFormatters: [CurrencyInputFormatter()],
      style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: TextStyle(
          color: color.withOpacity(0.3),
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        suffixText: '₫',
        suffixStyle: TextStyle(
          color: color.withOpacity(0.7),
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(
          _type == 'income' ? Icons.add : Icons.remove,
          color: color,
          size: 24,
        ),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Vui lòng nhập số tiền';
        if (double.tryParse(v) == null || double.parse(v) <= 0)
          return 'Số tiền không hợp lệ';
        return null;
      },
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    int maxLines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: keyboardType == TextInputType.number
          ? [CurrencyInputFormatter()]
          : null,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
        prefixIcon: maxLines == 1
            ? Icon(icon, color: AppColors.textHint, size: 20)
            : null,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.surfaceLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.primaryStart,
            width: 1.5,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: maxLines > 1 ? 14 : 0,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _categories.map((cat) {
        final name = cat['name'] as String;
        final icon = cat['icon'] as IconData;
        final color = cat['color'] as Color;
        final isSelected = _category == name;
        return GestureDetector(
          onTap: () => setState(() => _category = name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.15) : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? color.withOpacity(0.5)
                    : AppColors.surfaceLight,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected ? color : AppColors.textHint,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  name,
                  style: TextStyle(
                    color: isSelected ? color : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
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
        if (picked != null) setState(() => _date = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              color: AppColors.primaryStart,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              AppFormatters.formatDate(_date),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Hóa đơn (tùy chọn)'),
        const SizedBox(height: 12),
        if (!_isImageDeleted &&
            (_imageFile != null ||
                (widget.transaction?.imagePath != null &&
                    widget.transaction!.imagePath!.startsWith('http'))))
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _imageFile != null
                    ? Image.file(
                        _imageFile!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        widget.transaction!.imagePath!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, progress) =>
                            progress == null
                            ? child
                            : const SizedBox(
                                height: 200,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                        errorBuilder: (ctx, err, stack) => const SizedBox(
                          height: 200,
                          child: Center(
                            child: Icon(
                              Icons.broken_image,
                              color: AppColors.textHint,
                              size: 50,
                            ),
                          ),
                        ),
                      ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _imageFile = null;
                      _isImageDeleted = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, size: 20),
                  label: const Text('Chụp ảnh'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryStart,
                    side: const BorderSide(color: AppColors.primaryStart),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, size: 20),
                  label: const Text('Thư viện'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryStart,
                    side: const BorderSide(color: AppColors.primaryStart),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryStart,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: AppColors.primaryStart.withOpacity(0.4),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                _isEditing ? 'Cập nhật' : 'Lưu giao dịch',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
