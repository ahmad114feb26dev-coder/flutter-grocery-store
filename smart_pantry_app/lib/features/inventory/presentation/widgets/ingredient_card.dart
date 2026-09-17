import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class IngredientCard extends StatelessWidget {
  final String name;
  final String category;
  final String quantity;
  final String unit;
  final int? daysLeft;
  final double? dailyUsage;
  final double? lowStockThreshold;
  final VoidCallback? onConsume;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddToShopping;

  const IngredientCard({
    super.key,
    required this.name,
    this.category = 'Other',
    required this.quantity,
    required this.unit,
    this.daysLeft,
    this.dailyUsage,
    this.lowStockThreshold,
    this.onConsume,
    this.onEdit,
    this.onDelete,
    this.onAddToShopping,
  });

  @override
  Widget build(BuildContext context) {
    final days = daysLeft ?? 99;
    final isExpired = days <= 0;
    final isUrgent = days <= 2;
    final isWarning = days <= 5;

    final parsedQty = double.tryParse(quantity) ?? 0.0;
    final threshold = lowStockThreshold ?? 3.0;
    final isLowStock = parsedQty <= threshold && parsedQty > 0.0;
    final isDepleted = parsedQty <= 0.0;

    final Color statusColor = isExpired
        ? AppColors.error
        : isUrgent
            ? AppColors.warning
            : isWarning
                ? const Color(0xFFD97706)
                : AppColors.success;

    final Color statusBg = isExpired
        ? AppColors.errorLight
        : isUrgent
            ? AppColors.warningLight
            : isWarning
                ? const Color(0xFFFEF3C7)
                : AppColors.successLight;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDepleted
              ? AppColors.error.withValues(alpha: 0.6)
              : isLowStock
                  ? const Color(0xFFF59E0B)
                  : isUrgent
                      ? statusColor.withValues(alpha: 0.5)
                      : AppColors.border,
          width: isLowStock || isDepleted || isUrgent ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 560;

          // Common Badges
          Widget buildBadges() {
            return Wrap(
              spacing: 6,
              runSpacing: 5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Quantity pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'Qty: $quantity $unit',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                // Daily usage & stock estimation chip
                if (dailyUsage != null && dailyUsage! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.speed_rounded,
                          size: 13,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          () {
                            final rate = dailyUsage! % 1 == 0 ? dailyUsage!.toInt() : dailyUsage;
                            final q = double.tryParse(quantity);
                            String stockInfo = '';
                            if (q != null && dailyUsage! > 0) {
                              final days = (q / dailyUsage!).toStringAsFixed(
                                  (q / dailyUsage!) % 1 == 0 ? 0 : 1);
                              stockInfo = ' (~$days d stock)';
                            }
                            return '$rate $unit/day$stockInfo';
                          }(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Low Stock Alert badge (when quantity <= threshold)
                if (isLowStock)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.alarm_on_rounded, size: 12, color: Color(0xFFD97706)),
                        const SizedBox(width: 4),
                        Text(
                          'Low Stock (<=${threshold % 1 == 0 ? threshold.toInt() : threshold})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Out of stock badge (when quantity <= 0)
                if (isDepleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Out of Stock',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                // Expiry status chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isExpired
                            ? Icons.cancel_outlined
                            : isUrgent
                                ? Icons.alarm
                                : Icons.check_circle_outline,
                        size: 13,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getExpiryText(days),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          if (isCompact) {
            // ==========================================
            // COMPACT MOBILE LAYOUT (No clipped text)
            // ==========================================
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Category Icon + Item Title & Category + Quick Use Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.getCategoryBg(category),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        AppColors.getCategoryIcon(category),
                        color: AppColors.getCategoryColor(category),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onConsume != null && !isDepleted) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: onConsume,
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFFEF3C7),
                          foregroundColor: const Color(0xFFB45309),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 14),
                        label: const Text(
                          'Use',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // Middle: All Badges with generous width
                buildBadges(),

                // Bottom Action Toolbar (Cart, Edit, Delete)
                if (onAddToShopping != null || onEdit != null || onDelete != null) ...[
                  const SizedBox(height: 6),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (onAddToShopping != null)
                        IconButton(
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 19),
                          color: AppColors.textSecondary,
                          tooltip: 'Add to shopping list',
                          visualDensity: VisualDensity.compact,
                          onPressed: onAddToShopping,
                        ),
                      if (onEdit != null)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 19),
                          color: AppColors.textSecondary,
                          tooltip: 'Edit item',
                          visualDensity: VisualDensity.compact,
                          onPressed: onEdit,
                        ),
                      if (onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 19),
                          color: AppColors.error,
                          tooltip: 'Delete item',
                          visualDensity: VisualDensity.compact,
                          onPressed: onDelete,
                        ),
                    ],
                  ),
                ],
              ],
            );
          }

          // ==========================================
          // WIDE DESKTOP / TABLET LAYOUT
          // ==========================================
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Category Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.getCategoryBg(category),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  AppColors.getCategoryIcon(category),
                  color: AppColors.getCategoryColor(category),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),

              // Main Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    buildBadges(),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onConsume != null && !isDepleted)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: TextButton.icon(
                        onPressed: onConsume,
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFFEF3C7),
                          foregroundColor: const Color(0xFFB45309),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 15),
                        label: const Text(
                          'Use',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ),
                  if (onAddToShopping != null)
                    IconButton(
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                      color: AppColors.textSecondary,
                      tooltip: 'Add to shopping list',
                      onPressed: onAddToShopping,
                    ),
                  if (onEdit != null)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      color: AppColors.textSecondary,
                      tooltip: 'Edit item',
                      onPressed: onEdit,
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      color: AppColors.error,
                      tooltip: 'Delete item',
                      onPressed: onDelete,
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _getExpiryText(int days) {
    if (days < 0) return 'Expired ${days.abs()}d ago';
    if (days == 0) return 'Expires today';
    if (days == 1) return 'Expires tomorrow';
    return '$days days left';
  }
}
