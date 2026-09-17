import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_pantry_app/core/constants/app_colors.dart';
import 'package:smart_pantry_app/features/auth/providers/auth_provider.dart';
import 'package:smart_pantry_app/features/shopping_list/providers/shopping_list_provider.dart';
import 'package:smart_pantry_app/features/inventory/providers/inventory_provider.dart';
import 'package:smart_pantry_app/features/inventory/presentation/widgets/ingredient_card.dart';
import 'package:smart_pantry_app/features/inventory/presentation/widgets/consume_item_dialog.dart';
import 'package:smart_pantry_app/features/inventory/presentation/widgets/add_to_shopping_dialog.dart';
import 'package:smart_pantry_app/features/inventory/services/low_stock_alarm_service.dart';
import 'package:smart_pantry_app/features/inventory/data/models/ingredient_model.dart';
import 'package:smart_pantry_app/features/inventory/presentation/widgets/monthly_stock_register_sheet.dart';
import 'package:smart_pantry_app/core/animations/scroll_reveal.dart';

class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedFilter = 'All'; // All, Expiring Soon, Fresh
  int _viewMode = 0; // 0: Cards, 1: Monthly Register Sheet
  StreamSubscription? _alarmSub;

  @override
  void initState() {
    super.initState();
    final alarm = LowStockAlarmService();
    alarm.startPeriodicMonitor(() => ref.read(inventoryControllerProvider).valueOrNull ?? []);
    _alarmSub = alarm.onAlarmTriggered.listen((items) {
      if (mounted) {
        _showAlarmDialog(items);
      }
    });
  }

  @override
  void dispose() {
    _alarmSub?.cancel();
    super.dispose();
  }

  final List<String> _categories = [
    'All',
    'Produce',
    'Dairy',
    'Meat',
    'Bakery',
    'Pantry',
    'Spices',
  ];

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final currentUser = authState.valueOrNull;
    final isReadOnly = currentUser?.isReadOnly ?? false;

    final inventoryState = ref.watch(inventoryControllerProvider);
    final allItems = inventoryState.valueOrNull ?? [];
    final lowStockItems = allItems.where((e) => e.quantity <= (e.lowStockThreshold ?? 3.0)).toList();

    // Filter items
    final filteredItems = allItems.where((item) {
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.category.toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesCategory = _selectedCategory == 'All' ||
          item.category.toLowerCase() == _selectedCategory.toLowerCase();

      final days = item.daysLeft ?? 99;
      final matchesStatus = _selectedFilter == 'All' ||
          (_selectedFilter == 'Expiring Soon' && days <= 3) ||
          (_selectedFilter == 'Fresh' && days > 3);

      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 600 ? 14 : 24,
                vertical: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(context, allItems.length, isReadOnly),
                  const SizedBox(height: 16),

                  // Low Stock 2-Hour Alarm Banner (Active if quantity <= 3)
                  if (lowStockItems.isNotEmpty) ...[
                    _buildLowStockAlarmBanner(context, lowStockItems, isReadOnly).scrollScaleUp(
                      duration: const Duration(milliseconds: 600),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_viewMode == 1)
                    Expanded(
                      child: MonthlyStockRegisterSheet(items: allItems),
                    )
                  else ...[
                    // Search and Filter Bar
                    _buildSearchBar(),
                    const SizedBox(height: 14),

                    // Category Pills
                    _buildCategoryFilterPills(),
                    const SizedBox(height: 14),

                    // Urgency / Status Filters
                    _buildStatusFilterRow(allItems),
                    const SizedBox(height: 16),

                    // Inventory Items List
                    Expanded(
                      child: filteredItems.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                              padding: const EdgeInsets.only(bottom: 88),
                              itemCount: filteredItems.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                return IngredientCard(
                                  name: item.name,
                                  category: item.category,
                                  quantity: '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}',
                                  unit: item.unit,
                                  daysLeft: item.daysLeft,
                                  dailyUsage: item.dailyUsage,
                                  lowStockThreshold: item.lowStockThreshold,
                                  onConsume: isReadOnly ? null : () => ConsumeItemDialog.show(context, item),
                                  onEdit: isReadOnly ? null : () {
                                    context.push('/inventory/edit/${item.id}');
                                  },
                                  onDelete: isReadOnly ? null : () => _confirmDelete(context, item.id!, item.name),
                                  onAddToShopping: isReadOnly ? null : () => AddToShoppingDialog.show(context, item),
                                ).scrollSlideUp(
                                  delay: Duration(milliseconds: (index % 8) * 45),
                                  duration: const Duration(milliseconds: 500),
                                );
                              },
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: isReadOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/inventory/add'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Item'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
    );
  }

  Widget _buildHeader(BuildContext context, int totalCount, bool isReadOnly) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 650;

        final titleWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 4,
              children: [
                Text(
                  'My Pantry Inventory',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                        fontSize: isCompact ? 20 : null,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$totalCount items',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Track expiration dates, quantities, and organize your ingredients.',
              style: TextStyle(
                fontSize: isCompact ? 12 : 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        );

        final controlsWidget = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildViewTabBtn('Monthly Sheet', 1, Icons.table_chart_rounded),
                  const SizedBox(width: 4),
                  _buildViewTabBtn('Card Grid', 0, Icons.grid_view_rounded),
                ],
              ),
            ),
            if (isReadOnly)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility_rounded, size: 15, color: Color(0xFFB45309)),
                    SizedBox(width: 5),
                    Text(
                      'Just View Mode (Sirf Dekh Sakty Hain 👁️)',
                      style: TextStyle(
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              )
            else if (!isCompact)
              ElevatedButton.icon(
                onPressed: () => context.push('/inventory/add'),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Item'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleWidget,
              const SizedBox(height: 12),
              controlsWidget,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleWidget),
            const SizedBox(width: 16),
            controlsWidget,
          ],
        );
      },
    );
  }

  Widget _buildViewTabBtn(String label, int tabIndex, IconData icon) {
    final isSelected = _viewMode == tabIndex;
    return InkWell(
      onTap: () => setState(() => _viewMode = tabIndex),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? AppColors.primaryDark : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Search ingredients by name or category (e.g. Milk, Spinach)...',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCategoryFilterPills() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (val) {
                if (val) setState(() => _selectedCategory = cat);
              },
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusFilterRow(List allItems) {
    final expiringCount = allItems.where((e) => (e.daysLeft ?? 99) <= 3).length;

    return Row(
      children: [
        _buildFilterBadge('All', 'All (${allItems.length})'),
        const SizedBox(width: 8),
        _buildFilterBadge(
          'Expiring Soon',
          'Expiring Soon ($expiringCount)',
          activeColor: AppColors.error,
        ),
        const SizedBox(width: 8),
        _buildFilterBadge('Fresh', 'Fresh (${allItems.length - expiringCount})'),
      ],
    );
  }

  Widget _buildFilterBadge(String filterKey, String label, {Color? activeColor}) {
    final isSelected = _selectedFilter == filterKey;
    final color = activeColor ?? AppColors.primary;

    return InkWell(
      onTap: () => setState(() => _selectedFilter = filterKey),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No ingredients found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try adjusting your search query or category filters.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _selectedCategory = 'All';
                _selectedFilter = 'All';
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reset Filters'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Ingredient?'),
        content: Text('Are you sure you want to remove "$name" from your pantry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              ref.read(inventoryControllerProvider.notifier).deleteIngredient(id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed "$name" from pantry.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockAlarmBanner(BuildContext context, List<IngredientModel> lowItems, bool isReadOnly) {
    final itemSummary = lowItems.map((e) => '${e.name} (${e.quantity % 1 == 0 ? e.quantity.toInt() : e.quantity} ${e.unit})').join(', ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 680;

          final testAlarmBtn = ElevatedButton.icon(
            onPressed: () {
              LowStockAlarmService().triggerAlarm(lowItems);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: const Icon(Icons.volume_up_rounded, size: 16),
            label: const Text(
              'Test Alarm 🔊',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          );

          final restockAllBtn = isReadOnly
              ? null
              : OutlinedButton.icon(
                  onPressed: () {
                    for (final item in lowItems) {
                      ref.read(shoppingListControllerProvider.notifier).addItem(
                        item.name,
                        item.quantity <= 0 ? 1.0 : item.quantity,
                        'Low stock restock alert',
                      );
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added ${lowItems.length} low stock items to Shopping List!'),
                        backgroundColor: AppColors.primaryDark,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF92400E),
                    side: const BorderSide(color: Color(0xFFD97706)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                  label: const Text(
                    'Restock All',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                );

          final bellIcon = Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Color(0xFFD97706),
              size: 22,
            ),
          );

          final titleText = Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '🚨 Low Stock Alarm Active (Qty <= 3)',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF92400E),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Repeats every 2 hours',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          );

          final summaryText = Text(
            itemSummary,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF78350F),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bellIcon,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleText,
                          const SizedBox(height: 4),
                          summaryText,
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: testAlarmBtn),
                    if (restockAllBtn != null) ...[
                      const SizedBox(width: 8),
                      Expanded(child: restockAllBtn),
                    ],
                  ],
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              bellIcon,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleText,
                    const SizedBox(height: 4),
                    summaryText,
                  ],
                ),
              ),
              const SizedBox(width: 12),
              testAlarmBtn,
              if (restockAllBtn != null) ...[
                const SizedBox(width: 8),
                restockAllBtn,
              ],
            ],
          );
        },
      ),
    );
  }

  void _showAlarmDialog(List<IngredientModel> items) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.alarm_on_rounded, color: AppColors.warning, size: 28),
            SizedBox(width: 10),
            Text(
              'Low Stock Alarm Alert!',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ghar ka saman khatam hone wala hai! Following items reach 3 or less quantity:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Column(
                  children: items.map((e) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          e.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                        ),
                        Text(
                          '${e.quantity % 1 == 0 ? e.quantity.toInt() : e.quantity} ${e.unit} left',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: const [
                  Icon(Icons.timer_outlined, size: 16, color: AppColors.textSecondary),
                  SizedBox(width: 6),
                  Text(
                    'Alarm schedule: Har 2 ghante baad remind karega.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Snooze (2 Hours)'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              for (final item in items) {
                ref.read(shoppingListControllerProvider.notifier).addItem(
                  item.name,
                  item.quantity <= 0 ? 1.0 : item.quantity,
                  'Low stock restock',
                );
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added ${items.length} items to Shopping List!'),
                  backgroundColor: AppColors.primaryDark,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
            label: const Text('Add All to Shopping List'),
          ),
        ],
      ),
    );
  }
}
