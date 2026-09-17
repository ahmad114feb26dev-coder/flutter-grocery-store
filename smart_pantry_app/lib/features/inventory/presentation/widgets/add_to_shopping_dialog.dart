import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../dashboard/presentation/screens/main_shell.dart';
import '../../../shopping_list/providers/shopping_list_provider.dart';
import '../../data/models/ingredient_model.dart';

class AddToShoppingDialog extends ConsumerStatefulWidget {
  final IngredientModel ingredient;
  final double? initialQuantity;
  final String? initialReason;

  const AddToShoppingDialog({
    super.key,
    required this.ingredient,
    this.initialQuantity,
    this.initialReason,
  });

  static Future<bool?> show(
    BuildContext context,
    IngredientModel ingredient, {
    double? initialQuantity,
    String? initialReason,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AddToShoppingDialog(
        ingredient: ingredient,
        initialQuantity: initialQuantity,
        initialReason: initialReason,
      ),
    );
  }

  @override
  ConsumerState<AddToShoppingDialog> createState() => _AddToShoppingDialogState();
}

class _AddToShoppingDialogState extends ConsumerState<AddToShoppingDialog> {
  late final TextEditingController _qtyController;
  late final TextEditingController _reasonController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Default quantity: passed initialQuantity, or deficit, or 1.0
    double defaultQty = widget.initialQuantity ?? 1.0;
    if (widget.initialQuantity == null) {
      if (widget.ingredient.shoppingNeededQty > 0) {
        defaultQty = widget.ingredient.shoppingNeededQty.ceilToDouble();
      } else {
        defaultQty = 1.0;
      }
    }

    _qtyController = TextEditingController(
      text: defaultQty % 1 == 0 ? defaultQty.toInt().toString() : defaultQty.toString(),
    );
    _reasonController = TextEditingController(
      text: widget.initialReason ?? 'Pantry restock',
    );
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _stepQuantity(double delta) {
    final current = double.tryParse(_qtyController.text.trim()) ?? 1.0;
    final next = (current + delta);
    if (next > 0) {
      setState(() {
        _qtyController.text = next % 1 == 0 ? next.toInt().toString() : next.toStringAsFixed(1);
      });
    }
  }

  void _setExactQuantity(double qty) {
    setState(() {
      _qtyController.text = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
    });
  }

  Future<void> _submit() async {
    final qty = double.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid quantity greater than 0'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final reason = _reasonController.text.trim().isEmpty
          ? 'Pantry restock'
          : _reasonController.text.trim();

      await ref.read(shoppingListControllerProvider.notifier).addItem(
        widget.ingredient.name,
        qty,
        reason,
      );

      if (mounted) {
        Navigator.pop(context, true);
        final formattedQty = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $formattedQty ${widget.ingredient.unit} of "${widget.ingredient.name}" to Shopping List!'),
            backgroundColor: const Color(0xFF047857),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'View List',
              textColor: Colors.white,
              onPressed: () => ref.read(activeNavTabProvider.notifier).state = 4,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to shopping list: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.ingredient;
    final currentQty = item.quantity;
    final formattedCurrent = currentQty % 1 == 0 ? currentQty.toInt().toString() : currentQty.toStringAsFixed(1);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_shopping_cart_rounded,
                    color: Color(0xFF047857),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add to Shopping List',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Kitny purchase karne hain? Specify quantity',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Item Overview Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      size: 22,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                item.category,
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'In Pantry: $formattedCurrent ${item.unit}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF047857)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quantity Stepper Section
            const Text(
              'Quantity to Buy (Kitny Lany Hain)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF047857), width: 1.5),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _stepQuantity(-1),
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    color: AppColors.textSecondary,
                    tooltip: 'Decrease',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: '0',
                        suffixText: item.unit,
                        suffixStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _stepQuantity(1),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    color: const Color(0xFF047857),
                    tooltip: 'Increase',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Quick Preset Chips
            Wrap(
              spacing: 8,
              children: [
                _buildPresetChip('1 ${item.unit}', 1.0),
                _buildPresetChip('2 ${item.unit}', 2.0),
                _buildPresetChip('5 ${item.unit}', 5.0),
                _buildPresetChip('10 ${item.unit}', 10.0),
                if (item.shoppingNeededQty > 0 && item.shoppingNeededQty != 1 && item.shoppingNeededQty != 2 && item.shoppingNeededQty != 5 && item.shoppingNeededQty != 10)
                  _buildPresetChip(
                    'Deficit (${item.shoppingNeededQty.ceil()} ${item.unit})',
                    item.shoppingNeededQty.ceilToDouble(),
                    isHighlight: true,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Optional Reason / Note
            const Text(
              'Reason / Note (Optional)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                hintText: 'e.g. Weekly pantry restock, urgent order',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                isDense: true,
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF047857)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Dialog Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  label: Text(
                    _isSaving ? 'Adding...' : 'Add to Shopping List',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, double qty, {bool isHighlight = false}) {
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
          color: isHighlight ? const Color(0xFF047857) : AppColors.textPrimary,
        ),
      ),
      backgroundColor: isHighlight ? const Color(0xFFD1FAE5) : Colors.white,
      side: BorderSide(
        color: isHighlight ? const Color(0xFFA7F3D0) : AppColors.border,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      onPressed: () => _setExactQuantity(qty),
    );
  }
}
