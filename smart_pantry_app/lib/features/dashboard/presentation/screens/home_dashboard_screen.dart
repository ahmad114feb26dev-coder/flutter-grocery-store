import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_pantry_app/core/constants/app_colors.dart';
import 'package:smart_pantry_app/core/utils/pdf_generator_service.dart';
import 'package:smart_pantry_app/features/auth/providers/auth_provider.dart';
import 'package:smart_pantry_app/features/inventory/data/models/ingredient_model.dart';
import 'package:smart_pantry_app/features/inventory/providers/inventory_provider.dart';
import 'package:smart_pantry_app/features/shopping_list/providers/shopping_list_provider.dart';
import 'package:smart_pantry_app/features/dashboard/presentation/screens/main_shell.dart';
import 'package:smart_pantry_app/features/dashboard/presentation/widgets/pantry_analytics_charts.dart';
import 'package:smart_pantry_app/features/inventory/presentation/widgets/consume_item_dialog.dart';
import 'package:smart_pantry_app/features/inventory/presentation/widgets/add_to_shopping_dialog.dart';
import 'package:smart_pantry_app/core/animations/scroll_reveal.dart';
import 'package:smart_pantry_app/core/responsive/responsive.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final currentUser = authState.valueOrNull;
    final isReadOnly = currentUser?.isReadOnly ?? false;

    final inventoryAsync = ref.watch(inventoryControllerProvider);
    final shoppingAsync = ref.watch(shoppingListControllerProvider);
    final archivesAsync = ref.watch(monthlyArchivesProvider);

    final inventory = inventoryAsync.valueOrNull ?? [];
    final shopping = shoppingAsync.valueOrNull ?? [];
    final archives = archivesAsync.valueOrNull ?? [];

    final pendingShopping = shopping.where((e) => !e.resolved).toList();
    
    // Sort items by expiry urgency
    final expiringItems = [...inventory]
      ..sort((a, b) => (a.daysLeft ?? 99).compareTo(b.daysLeft ?? 99));
    final urgentExpiring = expiringItems.where((e) => (e.daysLeft ?? 99) <= 3).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContainer(
            maxWidth: AppBreakpoints.maxContentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  // Top Welcome & Action Header
                  _buildHeader(context, isReadOnly).scrollSlideDown(
                    duration: const Duration(milliseconds: 550),
                  ),
                  const SizedBox(height: 24),

                  // 4 KPI Summary Cards
                  _buildMetricsGrid(
                    context,
                    totalPantry: inventory.length,
                    expiringCount: urgentExpiring.length,
                    shoppingCount: pendingShopping.length,
                    reportsCount: archives.length,
                    ref: ref,
                  ).scrollSlideUp(
                    duration: const Duration(milliseconds: 600),
                  ),
                  const SizedBox(height: 28),

                  // Office Expense Detail Showcase Banner
                  if (inventory.isNotEmpty) ...[
                    _buildOfficeExpenseBanner(context, inventory, ref).scrollSlideUp(
                      duration: const Duration(milliseconds: 650),
                      delay: const Duration(milliseconds: 80),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Expiring Soon Section
                  _buildExpiringSoonSection(context, urgentExpiring, ref, isReadOnly).scrollSlideLeft(
                    duration: const Duration(milliseconds: 700),
                    delay: const Duration(milliseconds: 100),
                  ),
                  const SizedBox(height: 28),

                  // Visual Analytics Charts (Stock Health Donut & Category Bar Charts)
                  if (inventory.isNotEmpty) ...[
                    PantryAnalyticsCharts(items: inventory).scrollScaleUp(
                      duration: const Duration(milliseconds: 700),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Products Stock Inventory Table (Color-Coded)
                  _buildProductsStockTable(context, inventory, ref, isReadOnly).scrollSlideUp(
                    duration: const Duration(milliseconds: 750),
                    delay: const Duration(milliseconds: 100),
                  ),
                  const SizedBox(height: 28),

                  // Quick Navigation Actions
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(context, 'Quick Actions', 'One-tap access to your kitchen tools'),
                      const SizedBox(height: 14),
                      _buildQuickActionCards(context, ref),
                    ],
                  ).scrollSlideUp(
                    duration: const Duration(milliseconds: 650),
                  ),
                  const SizedBox(height: 28),

                  // Recent Saved PDF Reports Section
                  _buildRecentPdfReportsSection(context, archives, ref).scrollSlideRight(
                    duration: const Duration(milliseconds: 700),
                    delay: const Duration(milliseconds: 100),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildHeader(BuildContext context, bool isReadOnly) {
    final isMobile = context.isMobile;

    final actionBtn = isReadOnly
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_rounded, size: 18, color: Color(0xFFB45309)),
                SizedBox(width: 8),
                Text(
                  'Just View Mode (Sirf Dekh Sakty Hain 👁️)',
                  style: TextStyle(
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
        : ElevatedButton.icon(
            onPressed: () => context.push('/inventory/add'),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add Grocery Item'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
          );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to Smart Pantry 🥑',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Manage your pantry freshness, track daily usage, and archive PDF statements.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          actionBtn,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to Smart Pantry 🥑',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Manage your pantry freshness, track daily usage, and archive PDF statements.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        actionBtn,
      ],
    );
  }

  Widget _buildMetricsGrid(
    BuildContext context, {
    required int totalPantry,
    required int expiringCount,
    required int shoppingCount,
    required int reportsCount,
    required WidgetRef ref,
  }) {
    final crossAxisCount = context.responsiveGridCount(
      mobile: context.screenWidth < 400 ? 1 : 2,
      tablet: 2,
      desktop: 4,
    );

    final childAspectRatio = context.responsiveValue<double>(
      mobile: crossAxisCount == 1 ? 2.6 : 1.5,
      tablet: 1.9,
      desktop: 1.6,
    );

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: context.responsiveValue<double>(mobile: 12, tablet: 14, desktop: 16),
      mainAxisSpacing: context.responsiveValue<double>(mobile: 12, tablet: 14, desktop: 16),
      childAspectRatio: childAspectRatio,
      children: [
        _buildMetricCard(
          title: 'Total In Pantry',
          value: '$totalPantry',
          subtitle: 'Active ingredients',
          icon: Icons.inventory_2_rounded,
          color: AppColors.primary,
          onTap: () => ref.read(activeNavTabProvider.notifier).state = 1,
        ).scrollSlideUp(duration: const Duration(milliseconds: 550), delay: Duration.zero),
        _buildMetricCard(
          title: 'Expiring Soon',
          value: '$expiringCount',
          subtitle: expiringCount > 0 ? 'Needs attention' : 'All fresh & safe',
          icon: Icons.warning_amber_rounded,
          color: expiringCount > 0 ? AppColors.error : AppColors.success,
          onTap: () => ref.read(activeNavTabProvider.notifier).state = 1,
        ).scrollSlideUp(duration: const Duration(milliseconds: 550), delay: const Duration(milliseconds: 70)),
        _buildMetricCard(
          title: 'Shopping List',
          value: '$shoppingCount',
          subtitle: 'Items to purchase',
          icon: Icons.shopping_cart_rounded,
          color: AppColors.secondary,
          onTap: () => ref.read(activeNavTabProvider.notifier).state = 4,
        ).scrollSlideUp(duration: const Duration(milliseconds: 550), delay: const Duration(milliseconds: 140)),
        _buildMetricCard(
          title: 'Saved PDF Reports',
          value: '$reportsCount',
          subtitle: reportsCount > 0 ? '$reportsCount statements archived' : 'No statements yet',
          icon: Icons.picture_as_pdf_rounded,
          color: const Color(0xFFE11D48),
          onTap: () => ref.read(activeNavTabProvider.notifier).state = 3,
        ).scrollSlideUp(duration: const Duration(milliseconds: 550), delay: const Duration(milliseconds: 210)),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: color.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiringSoonSection(
    BuildContext context,
    List<IngredientModel> items,
    WidgetRef ref,
    bool isReadOnly,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildSectionTitle(
                context,
                'Expiring Soon Alerts',
                'Items that should be consumed within the next few days',
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => ref.read(activeNavTabProvider.notifier).state = 1,
              child: const Text('View All in Pantry →'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'No items expiring soon! Everything in your pantry is fresh.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.take(3).length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final days = item.daysLeft ?? 0;
              final isUrgent = days <= 1;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isUrgent ? AppColors.error.withValues(alpha: 0.3) : AppColors.warning.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.getCategoryBg(item.category),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        AppColors.getCategoryIcon(item.category),
                        color: AppColors.getCategoryColor(item.category),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                  ),
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
                                  item.category,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            days <= 0
                                ? 'Expired!'
                                : days == 1
                                    ? 'Expires tomorrow'
                                    : 'Expires in $days days',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isUrgent ? AppColors.error : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.unit}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (!isReadOnly) ...[
                      const SizedBox(width: 10),
                      if (context.screenWidth < 500)
                        IconButton(
                          onPressed: () => AddToShoppingDialog.show(context, item, initialReason: 'Expiring restock'),
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 18, color: AppColors.primaryDark),
                          tooltip: 'Re-order',
                          visualDensity: VisualDensity.compact,
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () => AddToShoppingDialog.show(context, item, initialReason: 'Expiring restock'),
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                          label: const Text('Re-order'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryDark,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildQuickActionCards(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 500
                ? 2
                : 1;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: crossAxisCount == 4 ? 2.0 : 2.8,
          children: [
            _buildInteractiveActionCard(
              title: 'Pantry Inventory',
              description: 'View, edit, and organize all your ingredients',
              icon: Icons.inventory_2_rounded,
              color: AppColors.primary,
              onTap: () => ref.read(activeNavTabProvider.notifier).state = 1,
            ),
            _buildInteractiveActionCard(
              title: 'Expense Detail',
              description: 'Office expense register & daily stock usage',
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFFD97706),
              onTap: () => ref.read(activeNavTabProvider.notifier).state = 2,
            ),
            _buildInteractiveActionCard(
              title: 'Saved PDF Reports',
              description: 'Permanent archive & instant download of monthly statements',
              icon: Icons.picture_as_pdf_rounded,
              color: const Color(0xFFE11D48),
              onTap: () => ref.read(activeNavTabProvider.notifier).state = 3,
            ),
            _buildInteractiveActionCard(
              title: 'Shopping List',
              description: 'Plan your grocery run with smart checklists',
              icon: Icons.shopping_cart_rounded,
              color: AppColors.accent,
              onTap: () => ref.read(activeNavTabProvider.notifier).state = 4,
            ),
          ],
        );
      },
    );
  }

  Widget _buildInteractiveActionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: color.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentPdfReportsSection(
    BuildContext context,
    List<dynamic> archives,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildSectionTitle(
                context,
                'Saved PDF Reports & Statements 📄',
                'Instant access to past monthly expense sheets and stock closures',
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => ref.read(activeNavTabProvider.notifier).state = 3,
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Color(0xFFE11D48)),
              label: const Text('View All Archives →', style: TextStyle(color: Color(0xFFE11D48))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (archives.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFE11D48), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No Closed Monthly Statements Yet',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Once you click "Done (Close Month)" in Expense Detail, full landscape PDF statements will appear here.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => ref.read(activeNavTabProvider.notifier).state = 2,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Open Register'),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: archives.take(2).map((archive) {
                  final width = isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
                  final monthYear = archive['monthYear'] ?? 'Statement';
                  final items = (archive['items'] as List?) ?? [];
                  final stockIn = (archive['totalStockIn'] as num?)?.toDouble() ?? 0.0;
                  final used = (archive['totalUsed'] as num?)?.toDouble() ?? 0.0;
                  final balance = (archive['inHandBalance'] as num?)?.toDouble() ?? 0.0;

                  return SizedBox(
                    width: width,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFFE11D48)),
                                  const SizedBox(width: 8),
                                  Text(
                                    monthYear,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _downloadDirectPdf(archive),
                                icon: const Icon(Icons.download_rounded, size: 14),
                                label: const Text('PDF', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE11D48),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMiniStat('Stock In', stockIn % 1 == 0 ? stockIn.toInt().toString() : stockIn.toStringAsFixed(1), const Color(0xFF854D0E)),
                              _buildMiniStat('Used', used % 1 == 0 ? used.toInt().toString() : used.toStringAsFixed(1), const Color(0xFF334155)),
                              _buildMiniStat('Balance', balance % 1 == 0 ? balance.toInt().toString() : balance.toStringAsFixed(1), const Color(0xFF047857)),
                              _buildMiniStat('Items', '${items.length}', AppColors.textPrimary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Future<void> _downloadDirectPdf(dynamic archive) async {
    final monthYear = archive['monthYear'] ?? 'Statement';
    final totalStockIn = (archive['totalStockIn'] as num?)?.toDouble();
    final totalUsed = (archive['totalUsed'] as num?)?.toDouble();
    final inHandBalance = (archive['inHandBalance'] as num?)?.toDouble();

    final rawItems = (archive['items'] as List?) ?? [];
    final items = rawItems.map((item) {
      return IngredientModel(
        id: item['id']?.toString() ?? item['_id']?.toString() ?? '',
        name: item['name'] ?? '',
        category: item['category'] ?? 'Other',
        quantity: (item['stockIn'] as num?)?.toDouble() ?? 0.0,
        stockIn: (item['stockIn'] as num?)?.toDouble() ?? 0.0,
        totalUsed: (item['totalUsed'] as num?)?.toDouble() ?? 0.0,
        dailyUsageLogs: (item['dailyUsageLogs'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ) ?? {},
        unit: item['unit'] ?? 'Unit',
        expiryDate: DateTime.now().add(const Duration(days: 30)),
      );
    }).toList();

    await PdfGeneratorService.generateAndDownloadPdf(
      monthYear: monthYear,
      items: items,
      totalStockIn: totalStockIn,
      totalUsed: totalUsed,
      inHandBalance: inHandBalance,
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontSize: context.responsiveFontSize(18, tablet: 20, desktop: 22),
                letterSpacing: -0.3,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildProductsStockTable(
    BuildContext context,
    List<IngredientModel> items,
    WidgetRef ref,
    bool isReadOnly,
  ) {
    return _ProductsStockSection(
      items: items,
      ref: ref,
      isReadOnly: isReadOnly,
    );
  }

  Widget _buildOfficeExpenseBanner(
    BuildContext context,
    List<IngredientModel> items,
    WidgetRef ref,
  ) {
    double totalStockIn = 0;
    double totalUsed = 0;
    double inHandBalance = 0;
    int deficitCount = 0;

    for (final item in items) {
      totalStockIn += item.effectiveStockIn;
      totalUsed += item.effectiveUsed;
      inHandBalance += item.inHandBalance;
      if (item.inHandBalance < 0) deficitCount++;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;

        if (isNarrow) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Office Expense Detail & Stock Register',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${items.length} Items',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildOfficeMiniPill('Stock In', totalStockIn.toStringAsFixed(1), const Color(0xFF854D0E)),
                    _buildOfficeMiniPill('Total Used', totalUsed.toStringAsFixed(1), const Color(0xFF334155)),
                    _buildOfficeMiniPill('Balance', inHandBalance.toStringAsFixed(1), const Color(0xFF047857)),
                    if (deficitCount > 0)
                      _buildOfficeMiniPill('Deficit', '$deficitCount Shortage', const Color(0xFFDC2626)),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => ref.read(activeNavTabProvider.notifier).state = 2,
                    icon: const Icon(Icons.table_chart_rounded, size: 16),
                    label: const Text('Open Expense Detail →'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 1,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'Office Expense Detail & Stock Register',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF92400E),
                            letterSpacing: -0.3,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${items.length} Items',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Stock In: ${totalStockIn.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF854D0E)),
                        ),
                        Text(
                          'Used: ${totalUsed.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                        Text(
                          'Balance: ${inHandBalance.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF047857)),
                        ),
                        if (deficitCount > 0)
                          Text(
                            '($deficitCount Shortage)',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => ref.read(activeNavTabProvider.notifier).state = 2,
                icon: const Icon(Icons.table_chart_rounded, size: 18),
                label: const Text(
                  'Open Expense Detail →',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildOfficeMiniPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

/// Adaptive Product Stock Inventory Section (Responsive Cards for mobile, DataTable for desktop)
class _ProductsStockSection extends StatefulWidget {
  final List<IngredientModel> items;
  final WidgetRef ref;
  final bool isReadOnly;

  const _ProductsStockSection({
    required this.items,
    required this.ref,
    required this.isReadOnly,
  });

  @override
  State<_ProductsStockSection> createState() => _ProductsStockSectionState();
}

class _ProductsStockSectionState extends State<_ProductsStockSection> {
  bool _preferTableView = false;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final isReadOnly = widget.isReadOnly;
    final ref = widget.ref;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 680;
        final showCards = isMobile && !_preferTableView;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Responsive Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Products Stock Status',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Color-coded quantities, daily usage, and stock duration',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
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
                    if (isMobile && items.isNotEmpty)
                      IconButton(
                        onPressed: () => setState(() => _preferTableView = !_preferTableView),
                        icon: Icon(
                          _preferTableView ? Icons.grid_view_rounded : Icons.table_chart_rounded,
                          size: 18,
                          color: AppColors.primaryDark,
                        ),
                        tooltip: _preferTableView ? 'Switch to Cards View' : 'Switch to Table View',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          padding: const EdgeInsets.all(8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    if (isMobile && items.isNotEmpty) const SizedBox(width: 4),
                    TextButton(
                      onPressed: () => ref.read(activeNavTabProvider.notifier).state = 1,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(isMobile ? 'Manage →' : 'Manage Inventory →'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Color Legend Chips (Concise)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildLegendChip('🟢 Sufficient', const Color(0xFFECFDF5), const Color(0xFF059669), const Color(0xFFA7F3D0)),
                _buildLegendChip('🟡 Moderate', const Color(0xFFFFFBEB), const Color(0xFFD97706), const Color(0xFFFDE68A)),
                _buildLegendChip('🔴 Low Stock', const Color(0xFFFEF2F2), const Color(0xFFDC2626), const Color(0xFFFCA5A5)),
                _buildLegendChip('⚪ Out of Stock', const Color(0xFFF1F5F9), const Color(0xFF64748B), const Color(0xFFCBD5E1)),
              ],
            ),
            const SizedBox(height: 14),

            if (items.isEmpty)
              _buildEmptyState(context, isReadOnly)
            else if (showCards)
              _buildMobileCards(context, items, isReadOnly)
            else
              _buildDesktopTable(context, items, isReadOnly, isMobile),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isReadOnly) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 36, color: AppColors.textSecondary),
          const SizedBox(height: 10),
          const Text(
            'No products in pantry yet.',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add grocery items using the button above to track your inventory in real time.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          if (!isReadOnly) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => context.push('/inventory/add'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add First Item'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileCards(BuildContext context, List<IngredientModel> items, bool isReadOnly) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        final qty = item.quantity;
        final threshold = item.lowStockThreshold ?? 3.0;
        final isOut = qty <= 0;
        final isLow = qty <= threshold && qty > 0;
        final isMod = qty > threshold && qty <= (threshold + 2);

        final Color statusBg = isOut
            ? const Color(0xFFF1F5F9)
            : isLow
                ? const Color(0xFFFEF2F2)
                : isMod
                    ? const Color(0xFFFFFBEB)
                    : const Color(0xFFECFDF5);

        final Color statusBorder = isOut
            ? const Color(0xFFCBD5E1)
            : isLow
                ? const Color(0xFFFCA5A5)
                : isMod
                    ? const Color(0xFFFDE68A)
                    : const Color(0xFFA7F3D0);

        final Color statusText = isOut
            ? const Color(0xFF64748B)
            : isLow
                ? const Color(0xFFDC2626)
                : isMod
                    ? const Color(0xFFD97706)
                    : const Color(0xFF059669);

        final String statusLabel = isOut
            ? 'Out of Stock'
            : isLow
                ? '🚨 Low Stock'
                : isMod
                    ? '⚡ Moderate'
                    : '✅ Sufficient';

        final formattedQty = qty % 1 == 0 ? '${qty.toInt()}' : '$qty';

        String durationLabel = '-';
        if (item.dailyUsage != null && item.dailyUsage! > 0 && qty > 0) {
          final days = (qty / item.dailyUsage!).round();
          durationLabel = '~$days din chalega';
        } else if (item.daysLeft != null) {
          durationLabel = '${item.daysLeft} din expiry';
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: statusBorder.withValues(alpha: 0.9), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Icon + Name & Category + Status Badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.getCategoryBg(item.category),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      AppColors.getCategoryIcon(item.category),
                      color: AppColors.getCategoryColor(item.category),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          item.category,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusBorder),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Middle Bar: Remaining Qty, Daily Usage, Duration
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Remaining', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          '$formattedQty ${item.unit}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: statusText),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Daily Usage', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          item.dailyUsage != null && item.dailyUsage! > 0
                              ? '${item.dailyUsage! % 1 == 0 ? item.dailyUsage!.toInt() : item.dailyUsage} ${item.unit}/d'
                              : '-',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Duration', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          durationLabel,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bottom Actions
              if (!isReadOnly) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isOut)
                      TextButton.icon(
                        onPressed: () => ConsumeItemDialog.show(context, item),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFFEF3C7),
                          foregroundColor: const Color(0xFFB45309),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 14),
                        label: const Text('Use', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                      color: AppColors.textSecondary,
                      tooltip: 'Add to Shopping List',
                      onPressed: () => AddToShoppingDialog.show(context, item, initialReason: 'Stock table restock'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(BuildContext context, List<IngredientModel> items, bool isReadOnly, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              children: [
                Icon(Icons.swipe_rounded, size: 16, color: Color(0xFF1D4ED8)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Table can be scrolled horizontally ↔️ (Swipe to view all columns)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                  ),
                ),
              ],
            ),
          ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 860),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    headingTextStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    dataRowMinHeight: 64,
                    dataRowMaxHeight: 68,
                    horizontalMargin: 20,
                    columnSpacing: 24,
                    columns: [
                      const DataColumn(label: Text('Product & Category')),
                      const DataColumn(label: Text('Remaining Quantity')),
                      const DataColumn(label: Text('Stock Level Status')),
                      const DataColumn(label: Text('Usage Rate')),
                      const DataColumn(label: Text('Duration / Expiry')),
                      DataColumn(label: Text(isReadOnly ? 'Status' : 'Quick Actions')),
                    ],
                    rows: items.map((item) {
                      final qty = item.quantity;
                      final threshold = item.lowStockThreshold ?? 3.0;
                      final isOut = qty <= 0;
                      final isLow = qty <= threshold && qty > 0;
                      final isMod = qty > threshold && qty <= (threshold + 2);

                      final Color statusBg = isOut
                          ? const Color(0xFFF1F5F9)
                          : isLow
                              ? const Color(0xFFFEF2F2)
                              : isMod
                                  ? const Color(0xFFFFFBEB)
                                  : const Color(0xFFECFDF5);

                      final Color statusBorder = isOut
                          ? const Color(0xFFCBD5E1)
                          : isLow
                              ? const Color(0xFFFCA5A5)
                              : isMod
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0xFFA7F3D0);

                      final Color statusText = isOut
                          ? const Color(0xFF64748B)
                          : isLow
                              ? const Color(0xFFDC2626)
                              : isMod
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF059669);

                      final String statusLabel = isOut
                          ? 'Out of Stock'
                          : isLow
                              ? '🚨 Low Stock (<=${threshold % 1 == 0 ? threshold.toInt() : threshold})'
                              : isMod
                                  ? '⚡ Moderate'
                                  : '✅ Sufficient';

                      final formattedQty = qty % 1 == 0 ? '${qty.toInt()}' : '$qty';

                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.getCategoryBg(item.category),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    AppColors.getCategoryIcon(item.category),
                                    color: AppColors.getCategoryColor(item.category),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      item.category,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: statusBorder),
                                  ),
                                  child: Text(
                                    '$formattedQty ${item.unit}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: statusText,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Alarm limit: <= ${threshold % 1 == 0 ? threshold.toInt() : threshold} ${item.unit}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusBorder),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: statusText,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            item.dailyUsage != null && item.dailyUsage! > 0
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: Text(
                                      '${item.dailyUsage! % 1 == 0 ? item.dailyUsage!.toInt() : item.dailyUsage} ${item.unit}/day',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1D4ED8),
                                      ),
                                    ),
                                  )
                                : const Text(
                                    '-',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  ),
                          ),
                          DataCell(
                            () {
                              if (item.dailyUsage != null && item.dailyUsage! > 0 && qty > 0) {
                                final days = (qty / item.dailyUsage!).round();
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: Text(
                                    '~$days din chalega',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                );
                              }
                              final days = item.daysLeft ?? 0;
                              return Text(
                                '$days din expiry',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              );
                            }(),
                          ),
                          DataCell(
                            isReadOnly
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.visibility_rounded, size: 12, color: Color(0xFFB45309)),
                                        SizedBox(width: 4),
                                        Text(
                                          'View Only',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFB45309),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isOut)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: TextButton.icon(
                                            onPressed: () => ConsumeItemDialog.show(context, item),
                                            style: TextButton.styleFrom(
                                              backgroundColor: const Color(0xFFFEF3C7),
                                              foregroundColor: const Color(0xFFB45309),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            icon: const Icon(Icons.remove_circle_outline_rounded, size: 15),
                                            label: const Text('Use', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                          ),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                                        color: AppColors.textSecondary,
                                        tooltip: 'Add to Shopping List',
                                        onPressed: () => AddToShoppingDialog.show(context, item, initialReason: 'Stock table restock'),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendChip(String text, Color bg, Color textColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

