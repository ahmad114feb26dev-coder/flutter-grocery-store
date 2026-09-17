import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/ingredient_model.dart';
import '../../providers/inventory_provider.dart';
import '../../../shopping_list/providers/shopping_list_provider.dart';

class ConsumeItemDialog extends ConsumerStatefulWidget {
  final IngredientModel ingredient;

  const ConsumeItemDialog({
    super.key,
    required this.ingredient,
  });

  static Future<void> show(BuildContext context, IngredientModel ingredient) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => ConsumeItemDialog(ingredient: ingredient),
    );
  }

  @override
  ConsumerState<ConsumeItemDialog> createState() => _ConsumeItemDialogState();
}

class _ConsumeItemDialogState extends ConsumerState<ConsumeItemDialog> {
  final _usedController = TextEditingController(text: '1');
  int _selectedDay = DateTime.now().day;
  bool _autoAddToShoppingIfDepleted = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // If daily usage is configured, set default used amount to daily usage
    if (widget.ingredient.dailyUsage != null && widget.ingredient.dailyUsage! > 0) {
      final d = widget.ingredient.dailyUsage!;
      _usedController.text = '${d % 1 == 0 ? d.toInt() : d}';
    }
    _usedController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _usedController.dispose();
    super.dispose();
  }

  void _setAmount(double amt) {
    setState(() {
      _usedController.text = '${amt % 1 == 0 ? amt.toInt() : amt}';
    });
  }

  Future<void> _submit() async {
    final used = double.tryParse(_usedController.text.trim()) ?? 0.0;
    if (used <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount used greater than 0.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final originalQty = widget.ingredient.quantity;
    final remainingQty = (originalQty - used) < 0 ? 0.0 : (originalQty - used);

    setState(() => _isSaving = true);

    try {
      final id = widget.ingredient.id;
      if (id != null) {
        // Record daily usage & update in-hand balance in MongoDB
        await ref.read(inventoryControllerProvider.notifier).logUsage(
          id,
          _selectedDay,
          used,
        );

        // If depleted to 0 or negative and user checked shopping list
        if (remainingQty <= 0 && _autoAddToShoppingIfDepleted) {
          ref.read(shoppingListControllerProvider.notifier).addItem(
            widget.ingredient.name,
            originalQty > 0 ? originalQty : 1.0,
            'Auto restock (item finished/deficit)',
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Used ${used % 1 == 0 ? used.toInt() : used} ${widget.ingredient.unit}. Remaining in MongoDB: ${remainingQty % 1 == 0 ? remainingQty.toInt() : remainingQty} ${widget.ingredient.unit}',
            ),
            backgroundColor: remainingQty <= 3 ? AppColors.warning : AppColors.primaryDark,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating stock in MongoDB: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.ingredient;
    final used = double.tryParse(_usedController.text.trim()) ?? 0.0;
    final remaining = (item.quantity - used).clamp(0.0, double.infinity);
    final threshold = item.lowStockThreshold ?? 3.0;
    final isLowStock = remaining <= threshold && remaining > 0;
    final isDepleted = remaining <= 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFFD97706),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Log Grocery Usage',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Saman use karein aur stock update karein',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Item details badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Category: ${item.category}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Current Stock',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        Text(
                          '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.unit}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Quick amount presets
              const Text(
                'Kitna use hua? (Quick Select):',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (item.dailyUsage != null && item.dailyUsage! > 0)
                    ActionChip(
                      avatar: const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFF2563EB)),
                      label: Text('1 Day (${item.dailyUsage! % 1 == 0 ? item.dailyUsage!.toInt() : item.dailyUsage} ${item.unit})'),
                      backgroundColor: const Color(0xFFEFF6FF),
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                      onPressed: () => _setAmount(item.dailyUsage!),
                    ),
                  ActionChip(
                    label: Text('0.25 ${item.unit}'),
                    backgroundColor: AppColors.surfaceMuted,
                    onPressed: () => _setAmount(0.25),
                  ),
                  ActionChip(
                    label: Text('0.5 ${item.unit}'),
                    backgroundColor: AppColors.surfaceMuted,
                    onPressed: () => _setAmount(0.5),
                  ),
                  ActionChip(
                    label: Text('1 ${item.unit}'),
                    backgroundColor: AppColors.surfaceMuted,
                    onPressed: () => _setAmount(1.0),
                  ),
                  ActionChip(
                    label: Text('2 ${item.unit}'),
                    backgroundColor: AppColors.surfaceMuted,
                    onPressed: () => _setAmount(2.0),
                  ),
                  if (item.quantity > 0)
                    ActionChip(
                      label: const Text('All (Finish)'),
                      backgroundColor: const Color(0xFFFEE2E2),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      onPressed: () => _setAmount(item.quantity),
                    ),
                ],
              ),
              // Day of Month Selection
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text('Usage Date: Day $_selectedDay of Month', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const Spacer(),
                  DropdownButton<int>(
                    value: _selectedDay,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: List.generate(31, (i) => i + 1).map((d) {
                      return DropdownMenuItem<int>(
                        value: d,
                        child: Text('Day $d', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedDay = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Custom Quantity Input Field
              TextFormField(
                controller: _usedController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Amount Used (${item.unit})',
                  hintText: 'e.g. 0.5',
                  prefixIcon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.warning),
                  suffixText: item.unit,
                  suffixStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 16),

              // Real-Time Calculation & Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDepleted
                      ? const Color(0xFFFEF2F2)
                      : isLowStock
                          ? const Color(0xFFFFFBEB)
                          : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDepleted
                        ? const Color(0xFFF87171)
                        : isLowStock
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFF86EFAC),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryItem(
                          'Pehle tha',
                          '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.unit}',
                          AppColors.textSecondary,
                        ),
                        const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textSecondary),
                        _buildSummaryItem(
                          'Use hua',
                          '${used % 1 == 0 ? used.toInt() : used} ${item.unit}',
                          AppColors.warning,
                        ),
                        const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textSecondary),
                        _buildSummaryItem(
                          'Pichy reh gaya',
                          '${remaining % 1 == 0 ? remaining.toInt() : remaining.toStringAsFixed(1)} ${item.unit}',
                          isDepleted
                              ? AppColors.error
                              : isLowStock
                                  ? const Color(0xFFD97706)
                                  : AppColors.primaryDark,
                          isBold: true,
                        ),
                      ],
                    ),
                    if (isLowStock) ...[
                      const Divider(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.alarm_on_rounded, size: 16, color: Color(0xFFD97706)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '⚠️ Low Stock Alert (<=${threshold % 1 == 0 ? threshold.toInt() : threshold}): 2 ghanty baad alarm bajega!',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (isDepleted) ...[
                      const Divider(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.shopping_bag_outlined, size: 16, color: AppColors.error),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Saman khatam ho gaya! Shopping list mein add karein:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error),
                            ),
                          ),
                          Checkbox(
                            value: _autoAddToShoppingIfDepleted,
                            activeColor: AppColors.error,
                            onChanged: (val) => setState(() => _autoAddToShoppingIfDepleted = val ?? true),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDepleted ? AppColors.error : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: Text(_isSaving ? 'Updating...' : 'Save & Update Stock'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String val, Color color, {bool isBold = false}) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
