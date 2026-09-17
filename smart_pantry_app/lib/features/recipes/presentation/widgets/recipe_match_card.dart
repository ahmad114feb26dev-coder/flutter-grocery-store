import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class RecipeMatchCard extends StatelessWidget {
  final String title;
  final double matchPercentage;
  final int prepTime;
  final String cuisine;
  final List<String> missingIngredients;
  final List<Map<String, String>> substitutes;
  final VoidCallback onTap;
  final VoidCallback? onAddMissingToShopping;

  const RecipeMatchCard({
    super.key,
    required this.title,
    required this.matchPercentage,
    required this.prepTime,
    required this.cuisine,
    required this.missingIngredients,
    required this.substitutes,
    required this.onTap,
    this.onAddMissingToShopping,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFullMatch = matchPercentage >= 99.9;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFullMatch ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border,
          width: isFullMatch ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Match Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.restaurant_menu_rounded, size: 13, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      cuisine,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.timer_outlined, size: 14, color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$prepTime mins',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isFullMatch ? AppColors.successLight : AppColors.secondaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFullMatch ? Icons.check_circle_rounded : Icons.pie_chart_rounded,
                            size: 14,
                            color: isFullMatch ? AppColors.primaryDark : AppColors.secondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isFullMatch ? 'Ready to Cook' : '${matchPercentage.toStringAsFixed(0)}% Match',
                            style: TextStyle(
                              color: isFullMatch ? AppColors.primaryDark : const Color(0xFFB45309),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Missing items or Substitutes
                if (!isFullMatch) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: 12),
                  if (missingIngredients.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.remove_shopping_cart_outlined, size: 14, color: AppColors.error),
                        const SizedBox(width: 6),
                        const Text(
                          'Missing items: ',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.error),
                        ),
                        Expanded(
                          child: Text(
                            missingIngredients.join(', '),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (onAddMissingToShopping != null)
                          TextButton.icon(
                            onPressed: onAddMissingToShopping,
                            icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
                            label: const Text('Add Missing', style: TextStyle(fontSize: 11)),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryDark,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (substitutes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.swap_horiz_rounded, size: 15, color: AppColors.accent),
                        const SizedBox(width: 6),
                        const Text(
                          'Substitute available: ',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent),
                        ),
                        Text(
                          substitutes.map((s) => '${s['original']} ➔ ${s['usedSubstitute']}').join(', '),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
