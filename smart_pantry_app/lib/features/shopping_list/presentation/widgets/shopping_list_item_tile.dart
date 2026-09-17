import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';

class ShoppingListItemTile extends StatelessWidget {
  final String name;
  final String quantity;
  final String reason;
  final bool isResolved;
  final bool movedToPantry;
  final bool isFrozen;
  final bool isReadOnly;
  final DateTime? date;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final ValueChanged<double>? onEditQuantity;

  const ShoppingListItemTile({
    super.key,
    required this.name,
    required this.quantity,
    this.reason = '',
    required this.isResolved,
    this.movedToPantry = false,
    this.isFrozen = false,
    this.isReadOnly = false,
    this.date,
    required this.onToggle,
    required this.onDelete,
    this.onIncrement,
    this.onDecrement,
    this.onEditQuantity,
  });

  void _showEditQuantityDialog(BuildContext context) {
    if (isFrozen || isReadOnly) return;
    final controller = TextEditingController(text: quantity);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Update Quantity - $name',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter new quantity:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. 5',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                Navigator.of(ctx).pop();
                onEditQuantity?.call(val);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEffectiveResolved = movedToPantry || isResolved;
    final bool canModifyQuantity = !isEffectiveResolved && !isFrozen && !isReadOnly;

    return Container(
      decoration: BoxDecoration(
        color: isEffectiveResolved
            ? AppColors.surfaceMuted.withValues(alpha: 0.6)
            : isFrozen
                ? Colors.grey.shade50
                : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEffectiveResolved
              ? AppColors.borderLight
              : isFrozen
                  ? Colors.blueGrey.shade200
                  : AppColors.border,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Transform.scale(
          scale: 1.1,
          child: Checkbox(
            value: isEffectiveResolved,
            onChanged: (val) {
              if (isReadOnly) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('View-Only Mode: Aap item check/uncheck nahi kar sakty. Admin se edit access lein.'),
                    backgroundColor: Color(0xFF1E293B),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              if (movedToPantry) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Yeh product pantry mein shift ho chuki hai aur hamesha checked hi rahegi!'),
                    backgroundColor: Color(0xFF1E293B),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              onToggle(val);
            },
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  decoration: isEffectiveResolved ? TextDecoration.lineThrough : null,
                  color: isEffectiveResolved ? AppColors.textMuted : AppColors.textPrimary,
                  fontWeight: isEffectiveResolved ? FontWeight.w500 : FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            if (isFrozen)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 10, color: Color(0xFF475569)),
                    SizedBox(width: 3),
                    Text(
                      'Frozen',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            if (movedToPantry)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Text(
                  '📦 Pantry',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            if (isResolved && !movedToPantry)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Text(
                  '✓ Bought',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              // Interactive Quantity Stepper Badge (Locked when isFrozen or isReadOnly)
              Container(
                decoration: BoxDecoration(
                  color: isResolved
                      ? AppColors.surfaceMuted
                      : canModifyQuantity
                          ? AppColors.primaryLight.withValues(alpha: 0.3)
                          : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isResolved
                        ? AppColors.border
                        : canModifyQuantity
                            ? AppColors.primary.withValues(alpha: 0.35)
                            : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Decrement Button (-)
                    if (onDecrement != null && !isReadOnly)
                      InkWell(
                        onTap: canModifyQuantity ? onDecrement : null,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                        child: Tooltip(
                          message: isFrozen
                              ? 'Frozen: Quantity cannot be changed'
                              : 'Decrease quantity (-1)',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            child: Icon(
                              Icons.remove_rounded,
                              size: 14,
                              color: canModifyQuantity ? AppColors.primaryDark : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    if (onDecrement != null && !isReadOnly)
                      Container(
                        height: 14,
                        width: 1,
                        color: isResolved ? AppColors.border : AppColors.primary.withValues(alpha: 0.25),
                      ),
                    // Quantity Text / Tap to Edit
                    InkWell(
                      onTap: canModifyQuantity && onEditQuantity != null ? () => _showEditQuantityDialog(context) : null,
                      borderRadius: BorderRadius.circular(4),
                      child: Tooltip(
                        message: isReadOnly
                            ? 'Quantity'
                            : isFrozen
                                ? 'Frozen: Quantity locked'
                                : isResolved
                                    ? 'Quantity'
                                    : 'Tap to edit quantity',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Qty: $quantity',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: canModifyQuantity ? AppColors.primaryDark : AppColors.textMuted,
                                ),
                              ),
                              if (canModifyQuantity && onEditQuantity != null) ...[
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.edit_rounded,
                                  size: 10,
                                  color: AppColors.primaryDark.withValues(alpha: 0.6),
                                ),
                              ],
                              if (isFrozen) ...[
                                const SizedBox(width: 3),
                                const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 10,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (onIncrement != null && !isReadOnly)
                      Container(
                        height: 14,
                        width: 1,
                        color: isResolved ? AppColors.border : AppColors.primary.withValues(alpha: 0.25),
                      ),
                    // Increment Button (+)
                    if (onIncrement != null && !isReadOnly)
                      InkWell(
                        onTap: canModifyQuantity ? onIncrement : null,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                        child: Tooltip(
                          message: isFrozen
                              ? 'Frozen: Quantity cannot be changed'
                              : 'Increase quantity (+1)',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            child: Icon(
                              Icons.add_rounded,
                              size: 14,
                              color: canModifyQuantity ? AppColors.primaryDark : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Date Badge
              if (date != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 11,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM yyyy').format(date!),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              if (reason.isNotEmpty)
                Text(
                  reason,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        trailing: isReadOnly
            ? const SizedBox.shrink()
            : isFrozen
                ? const Tooltip(
                    message: 'Frozen: Item cannot be deleted',
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 20),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                    tooltip: 'Delete',
                    onPressed: onDelete,
                  ),
      ),
    );
  }
}
