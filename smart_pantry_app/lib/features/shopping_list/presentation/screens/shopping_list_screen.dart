import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smart_pantry_app/core/constants/app_colors.dart';
import 'package:smart_pantry_app/features/shopping_list/providers/shopping_list_provider.dart';
import 'package:smart_pantry_app/features/shopping_list/presentation/widgets/shopping_list_item_tile.dart';
import 'package:smart_pantry_app/features/shopping_list/data/models/shopping_list_item_model.dart';
import 'package:smart_pantry_app/features/auth/providers/auth_provider.dart';
import 'package:smart_pantry_app/core/animations/scroll_reveal.dart';
import 'package:smart_pantry_app/core/utils/pdf_generator_service.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  String _selectedFilter = 'All'; // All, To Buy, Bought
  late final ScrollController _mobileScrollController = ScrollController();

  // Calendar / Month Filter State
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _isMonthFilterActive = true;
  DateTime _itemDate = DateTime.now();

  // Collapsible / Dropdown state per shopping list trip
  final Map<int, bool> _expandedTrips = {};

  bool _isTripExpanded(int tripNum, bool isFrozen) {
    if (_expandedTrips.containsKey(tripNum)) {
      return _expandedTrips[tripNum]!;
    }
    // Finalized lists start collapsed (false) so clicking expands the dropdown, active lists start expanded (true)
    return !isFrozen;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).refreshProfile();
      ref.invalidate(shoppingListControllerProvider);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _mobileScrollController.dispose();
    super.dispose();
  }

  void _scrollToShoppingList() {
    if (_mobileScrollController.hasClients) {
      _mobileScrollController.animateTo(
        380,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _scrollToTop() {
    if (_mobileScrollController.hasClients) {
      _mobileScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
  }

  void _resetToCurrentMonth() {
    final now = DateTime.now();
    setState(() {
      _selectedMonth = DateTime(now.year, now.month, 1);
      _itemDate = now;
    });
  }

  Future<void> _pickDateForAdd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _itemDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryDark,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _itemDate = picked;
        // Optionally align selectedMonth if month filter is active
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'SELECT MONTH & YEAR',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryDark,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  Future<void> _confirmFinalizeLock(List<ShoppingListItemModel> items, [int? tripNum]) async {
    final title = tripNum != null
        ? 'Finalize Shopping List #$tripNum 🔒'
        : 'Final Shopping (Permanent Lock)';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Color(0xFF1E293B), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️ Khabardaar: Yeh amal mustaqil (permanent) hai!',
              style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB45309), fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Ek martaba finalize hone ke baad is list ke tamam (${items.length}) items permanent lock ho jayenge:\n• Dobara kabhi unlock nahi ho sakenge\n• Quantity increase ya decrease nahi hogi\n• Item delete nahi ho sakega\n\nIs mahine dobara samaan add karne par New Shopping List #${(tripNum ?? 1) + 1} isi page par alag se shuru hogi.',
              style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Confirm & Lock List #${tripNum ?? 1} 🔒'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ids = items.where((e) => e.id != null).map((e) => e.id!).toList();
      await ref.read(shoppingListControllerProvider.notifier).toggleFreezeAll(itemIds: ids, freeze: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Shopping List #${tripNum ?? 1} finalize ho chuki hai! Ab naye items New Shopping List #${(tripNum ?? 1) + 1} mein add honge.',
            ),
            backgroundColor: const Color(0xFF1E293B),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _quickAdd({bool markAsBought = false}) {
    final text = _nameController.text.trim();
    if (text.isEmpty) return;

    final qty = double.tryParse(_qtyController.text) ?? 1.0;
    ref.read(shoppingListControllerProvider.notifier).addItem(
          text,
          qty,
          'Manually added',
          date: _itemDate,
          resolved: markAsBought,
        );

    _nameController.clear();
    _qtyController.text = '1';
    _itemDate = DateTime.now();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(markAsBought
            ? 'Added "$text" (Qty: $qty) to History as Bought!'
            : 'Added "$text" (Qty: $qty) to Shopping List!'),
        backgroundColor: AppColors.primaryDark,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shoppingState = ref.watch(shoppingListControllerProvider);
    final allItems = shoppingState.valueOrNull ?? [];

    // Filter items based on selected month (if filter active)
    final filteredByDate = _isMonthFilterActive
        ? allItems.where((item) {
            final d = item.effectiveDate;
            return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
          }).toList()
        : allItems;

    final toBuyItems = filteredByDate.where((e) => !e.resolved).toList();
    final boughtItems = filteredByDate.where((e) => e.resolved).toList();
    final unmigratedBoughtItems = boughtItems.where((e) => !e.movedToPantry).toList();
    final bool isAllFrozen = filteredByDate.isNotEmpty && filteredByDate.every((item) => item.isFrozen);
    final int maxTripNumber = filteredByDate.isEmpty
        ? 1
        : filteredByDate.map((e) => e.tripNumber).fold(1, (max, e) => e > max ? e : max);
    final activeUnfrozenItems = filteredByDate.where((e) => !e.isFrozen).toList();
    final int? activeTripNumber = activeUnfrozenItems.isNotEmpty ? activeUnfrozenItems.first.tripNumber : null;

    final currentUser = ref.watch(authControllerProvider).valueOrNull;
    final bool isReadOnly = currentUser?.isReadOnly ?? false;

    // Calculate total quantity bought in selected month
    final double totalQtyBought = boughtItems.fold(
      0.0,
      (sum, item) => sum + item.quantityNeeded,
    );

    final displayedItems = _selectedFilter == 'To Buy'
        ? toBuyItems
        : _selectedFilter == 'Bought'
            ? boughtItems
            : filteredByDate;

    // Group displayed items by tripNumber
    final Map<int, List<ShoppingListItemModel>> tripsMap = {};
    for (final item in displayedItems) {
      final trip = item.tripNumber;
      tripsMap.putIfAbsent(trip, () => []).add(item);
    }
    final sortedTripKeys = tripsMap.keys.toList()..sort((a, b) => b.compareTo(a));

    final now = DateTime.now();
    final isCurrentMonth = _selectedMonth.year == now.year && _selectedMonth.month == now.month;
    final isWideScreen = MediaQuery.of(context).size.width >= 800;

    Widget buildItemsList(bool isWide) {
      if (displayedItems.isEmpty) {
        return _buildEmptyState();
      }
      return ListView.builder(
        shrinkWrap: !isWide,
        physics: isWide ? null : const NeverScrollableScrollPhysics(),
        itemCount: sortedTripKeys.length,
        itemBuilder: (context, tripIndex) {
          final tripNum = sortedTripKeys[tripIndex];
          final tripItems = tripsMap[tripNum]!;
          final isTripFrozen = tripItems.isNotEmpty && tripItems.every((e) => e.isFrozen);
          final isExpanded = _isTripExpanded(tripNum, isTripFrozen);
          final allTripProducts = (filteredByDate.isNotEmpty ? filteredByDate : allItems)
              .where((item) => item.tripNumber == tripNum)
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTripSectionHeader(
                tripNum: tripNum,
                tripItems: tripItems,
                allTripProducts: allTripProducts.isNotEmpty ? allTripProducts : tripItems,
                isFrozen: isTripFrozen,
                isExpanded: isExpanded,
                isReadOnly: isReadOnly,
                onToggle: () {
                  setState(() {
                    _expandedTrips[tripNum] = !isExpanded;
                  });
                },
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: tripItems.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ShoppingListItemTile(
                        name: item.ingredientName,
                        quantity: '${item.quantityNeeded % 1 == 0 ? item.quantityNeeded.toInt() : item.quantityNeeded}',
                        reason: item.addedReason,
                        isResolved: item.resolved,
                        movedToPantry: item.movedToPantry,
                        isFrozen: item.isFrozen,
                        isReadOnly: isReadOnly,
                        date: item.effectiveDate,
                        onToggle: (val) {
                          if (item.id != null) {
                            if (item.movedToPantry) {
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
                            ref.read(shoppingListControllerProvider.notifier).toggleResolved(
                                  item.id!,
                                  val ?? false,
                                );
                          }
                        },
                        onDelete: () {
                          if (item.id != null) {
                            if (item.isFrozen) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Item frozen hai aur delete nahi ho sakta!'),
                                  backgroundColor: AppColors.error,
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            ref.read(shoppingListControllerProvider.notifier).deleteItem(item.id!);
                          }
                        },
                        onIncrement: () {
                          if (item.id != null) {
                            if (item.isFrozen) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('List finalized / frozen hai! Quantity change nahi ho sakti.'),
                                  backgroundColor: Color(0xFF1E293B),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            final newQty = item.quantityNeeded + 1;
                            ref.read(shoppingListControllerProvider.notifier).updateQuantity(item.id!, newQty);
                          }
                        },
                        onDecrement: () {
                          if (item.id != null) {
                            if (item.isFrozen) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('List finalized / frozen hai! Quantity change nahi ho sakti.'),
                                  backgroundColor: Color(0xFF1E293B),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            if (item.quantityNeeded > 1) {
                              final newQty = item.quantityNeeded - 1;
                              ref.read(shoppingListControllerProvider.notifier).updateQuantity(item.id!, newQty);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Minimum quantity is 1 unit'),
                                  duration: Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        onEditQuantity: (newQty) {
                          if (item.id != null && newQty > 0) {
                            if (item.isFrozen) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('List finalized / frozen hai! Quantity change nahi ho sakti.'),
                                  backgroundColor: Color(0xFF1E293B),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            ref.read(shoppingListControllerProvider.notifier).updateQuantity(item.id!, newQty);
                          }
                        },
                      ),
                    )).toList(),
                  ),
                ),
                crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
              const SizedBox(height: 8),
            ],
          ).scrollSlideUp(
            delay: Duration(milliseconds: (tripIndex % 6) * 70),
            duration: const Duration(milliseconds: 550),
          );
        },
      );
    }

    final pageContent = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width < 600 ? 12 : 24,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                  // Screen Header
                  LayoutBuilder(
                    builder: (context, headerConstraints) {
                      final isCompact = headerConstraints.maxWidth < 650;

                      final titleSection = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Grocery Shopping & History 🛒',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                      fontSize: isCompact ? 19 : 24,
                                      letterSpacing: -0.5,
                                    ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${toBuyItems.length} to buy',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Track purchases, manage restocks, and inspect previous months history.',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      );

                      final actionsSection = Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryDark),
                            tooltip: 'Refresh shopping list & permissions',
                            onPressed: () async {
                              await ref.read(authControllerProvider.notifier).refreshProfile();
                              ref.invalidate(shoppingListControllerProvider);
                            },
                          ),
                          if (!isWideScreen)
                            IconButton(
                              icon: const Icon(Icons.arrow_downward_rounded, color: AppColors.primaryDark),
                              tooltip: 'Scroll to Shopping List',
                              onPressed: _scrollToShoppingList,
                            ),
                          if (isReadOnly)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFF59E0B)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.visibility_rounded, size: 16, color: Color(0xFFB45309)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Just View Mode 👁️',
                                    style: TextStyle(
                                      color: Color(0xFF92400E),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            if (filteredByDate.isNotEmpty)
                              isAllFrozen
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.lock_rounded, size: 16, color: Color(0xFF475569)),
                                          SizedBox(width: 6),
                                          Text(
                                            'Finalized 🔒 (Locked)',
                                            style: TextStyle(
                                              color: Color(0xFF334155),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed: () => _confirmFinalizeLock(activeUnfrozenItems, activeTripNumber),
                                      icon: const Icon(Icons.lock_clock_rounded, size: 17),
                                      label: Text(activeTripNumber != null && activeTripNumber > 1
                                          ? 'Finalize List #$activeTripNumber 🔒'
                                          : 'Final Shopping 🔒'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1E293B),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                            if (unmigratedBoughtItems.isNotEmpty)
                              ElevatedButton.icon(
                                onPressed: () {
                                  ref.read(shoppingListControllerProvider.notifier).movePurchasedToPantry();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Moved ${unmigratedBoughtItems.length} purchased items directly into Pantry!'),
                                      backgroundColor: AppColors.primaryDark,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.inventory_2_rounded, size: 18),
                                label: const Text('Move Bought to Pantry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryDark,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                          ],
                        ],
                      );

                      if (isCompact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleSection,
                            const SizedBox(height: 12),
                            actionsSection,
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: titleSection),
                          const SizedBox(width: 16),
                          actionsSection,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Calendar / Month Navigation Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, navConstraints) {
                        final isCompact = navConstraints.maxWidth < 650;
                        final monthControls = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: _previousMonth,
                              icon: const Icon(Icons.chevron_left_rounded, size: 24),
                              tooltip: 'Previous Month (Pichla Mahina)',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.grey.shade100,
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: _pickMonth,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_month_rounded, size: 17, color: AppColors.primaryDark),
                                    const SizedBox(width: 6),
                                    Text(
                                      DateFormat('MMMM yyyy').format(_selectedMonth),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.primaryDark),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              onPressed: _nextMonth,
                              icon: const Icon(Icons.chevron_right_rounded, size: 24),
                              tooltip: 'Next Month (Agla Mahina)',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.grey.shade100,
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                            if (!isCurrentMonth) ...[
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: _resetToCurrentMonth,
                                icon: const Icon(Icons.today_rounded, size: 15, color: AppColors.primary),
                                label: const Text(
                                  'Current Month',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                                ),
                              ),
                            ],
                          ],
                        );

                        final filterControls = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Filter by Month:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment<bool>(
                                  value: true,
                                  label: Text('Month View', style: TextStyle(fontSize: 12)),
                                  icon: Icon(Icons.calendar_view_month_rounded, size: 16),
                                ),
                                ButtonSegment<bool>(
                                  value: false,
                                  label: Text('All Time', style: TextStyle(fontSize: 12)),
                                  icon: Icon(Icons.all_inclusive_rounded, size: 16),
                                ),
                              ],
                              selected: {_isMonthFilterActive},
                              onSelectionChanged: (val) {
                                setState(() {
                                  _isMonthFilterActive = val.first;
                                });
                              },
                              style: ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                shape: WidgetStateProperty.all(
                                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        );

                        if (isCompact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              monthControls,
                              const SizedBox(height: 10),
                              filterControls,
                            ],
                          );
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            monthControls,
                            filterControls,
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Monthly Purchase Summary KPI Strip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryDark.withValues(alpha: 0.05),
                          AppColors.primary.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildKpiItem(
                            icon: Icons.check_circle_rounded,
                            iconColor: const Color(0xFF047857),
                            title: 'Items Purchased (${DateFormat('MMM yyyy').format(_selectedMonth)})',
                            value: '${boughtItems.length}',
                            subtitle: 'Items bought',
                          ),
                          Container(margin: const EdgeInsets.symmetric(horizontal: 16), height: 36, width: 1, color: AppColors.border),
                          _buildKpiItem(
                            icon: Icons.inventory_rounded,
                            iconColor: AppColors.primaryDark,
                            title: 'Total Quantity Bought',
                            value: '${totalQtyBought % 1 == 0 ? totalQtyBought.toInt() : totalQtyBought.toStringAsFixed(1)} units',
                            subtitle: 'Total quantity',
                            highlight: true,
                          ),
                          Container(margin: const EdgeInsets.symmetric(horizontal: 16), height: 36, width: 1, color: AppColors.border),
                          _buildKpiItem(
                            icon: Icons.shopping_bag_outlined,
                            iconColor: const Color(0xFFD97706),
                            title: 'Pending To Buy',
                            value: '${toBuyItems.length}',
                            subtitle: 'Active list',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Information banner when previous list in this month is frozen
                  if (isAllFrozen && filteredByDate.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF93C5FD)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFF1D4ED8), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Shopping List #$maxTripNumber freeze ho chuki hai. Naya samaan add karne par is mahine ki "New Shopping List #${maxTripNumber + 1}" isi page par alag se shuru ho jayegi.',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Quick Add Bar with Date Selection (or View-Only Notice)
                  if (isReadOnly)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.visibility_rounded, color: Color(0xFFD97706), size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Just View Mode (Sirf Dekh Saky 👁️)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Aap ko Admin ki taraf se sirf shopping list dekhny ki access di gayi hai. Koi bhi cheez add, edit, ya delete karne ke liye Admin se access hasil karen.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFB45309),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: LayoutBuilder(
                        builder: (context, barConstraints) {
                          final isCompact = barConstraints.maxWidth < 650;

                          final textInput = TextField(
                            controller: _nameController,
                            onSubmitted: (_) => _quickAdd(),
                            decoration: InputDecoration(
                              hintText: 'Add item to buy or log purchase (e.g. Eggs, Oil)...',
                              isDense: true,
                              border: isCompact
                                  ? OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    )
                                  : InputBorder.none,
                              enabledBorder: isCompact
                                  ? OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    )
                                  : InputBorder.none,
                              focusedBorder: isCompact
                                  ? OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                    )
                                  : InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          );

                          final controls = Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Quantity input with quick stepper buttons
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        final current = double.tryParse(_qtyController.text) ?? 1.0;
                                        if (current > 1) {
                                          final next = current - 1;
                                          setState(() {
                                            _qtyController.text = next % 1 == 0 ? next.toInt().toString() : next.toString();
                                          });
                                        }
                                      },
                                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        child: Icon(Icons.remove_rounded, size: 16, color: AppColors.textSecondary),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 42,
                                      child: TextField(
                                        controller: _qtyController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onSubmitted: (_) => _quickAdd(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        final current = double.tryParse(_qtyController.text) ?? 1.0;
                                        final next = current + 1;
                                        setState(() {
                                          _qtyController.text = next % 1 == 0 ? next.toInt().toString() : next.toString();
                                        });
                                      },
                                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        child: Icon(Icons.add_rounded, size: 16, color: AppColors.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Date picker button for entry
                              InkWell(
                                onTap: _pickDateForAdd,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.event_note_rounded, size: 16, color: AppColors.textSecondary),
                                      const SizedBox(width: 5),
                                      Text(
                                        DateFormat('dd MMM').format(_itemDate),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _quickAdd(markAsBought: false),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Add'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                              Tooltip(
                                message: 'Add directly as past purchase with quantity',
                                child: OutlinedButton.icon(
                                  onPressed: () => _quickAdd(markAsBought: true),
                                  icon: const Icon(Icons.check_rounded, size: 18, color: Color(0xFF047857)),
                                  label: const Text('Log Bought', style: TextStyle(color: Color(0xFF047857), fontSize: 13)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    side: const BorderSide(color: Color(0xFFA7F3D0)),
                                    backgroundColor: const Color(0xFFECFDF5),
                                  ),
                                ),
                              ),
                            ],
                          );

                          if (isCompact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                textInput,
                                const SizedBox(height: 10),
                                controls,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(flex: 4, child: textInput),
                              const SizedBox(width: 8),
                              controls,
                            ],
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 14),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterTab('All', 'All (${filteredByDate.length})'),
                        const SizedBox(width: 8),
                        _buildFilterTab('Bought', 'Bought History (${boughtItems.length})'),
                        const SizedBox(width: 8),
                        _buildFilterTab('To Buy', 'To Buy (${toBuyItems.length})'),
                        if (!isWideScreen) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _scrollToTop,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.arrow_upward_rounded, size: 14, color: AppColors.textSecondary),
                                  SizedBox(width: 4),
                                  Text('Top ⬆️', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Items List
                  if (isWideScreen)
                    Expanded(
                      child: buildItemsList(true),
                    )
                  else ...[
                    buildItemsList(false),
                    const SizedBox(height: 48),
                  ],
                ],
              ),
            );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: isWideScreen
                ? pageContent
                : SingleChildScrollView(
                    controller: _mobileScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: pageContent,
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _openShoppingListPdf({
    required int tripNum,
    required List<ShoppingListItemModel> tripItems,
    required bool isFrozen,
  }) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text('Shopping List #$tripNum PDF open ho rahi hai...'),
            ],
          ),
          duration: const Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await PdfGeneratorService.generateShoppingListPdf(
        tripNum: tripNum,
        items: tripItems,
        isFrozen: isFrozen,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF generate karne me masla: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showWhatsAppShareDialog({
    required int tripNum,
    required List<ShoppingListItemModel> tripItems,
    required bool isFrozen,
  }) {
    final phoneController = TextEditingController();
    final messagePreview = PdfGeneratorService.buildWhatsAppShoppingListText(
      tripNum: tripNum,
      items: tripItems,
      isFrozen: isFrozen,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF075E54), Color(0xFF128C7E), Color(0xFF25D366)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Shopping List #$tripNum WhatsApp Share',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${tripItems.length} Products • ${isFrozen ? 'Finalized 🔒' : 'Active 🛒'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 20),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Phone Number Field
                            const Text(
                              'WhatsApp Phone Number (Optional):',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                hintText: 'e.g. 03001234567 ya khali chhor dein',
                                prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF16A34A), size: 18),
                                helperText: 'Number likhne par direct chat khulegi, blank rakhne par contact choose kar sakeinge.',
                                helperMaxLines: 2,
                                helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
                                ),
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 16),

                            // Message preview header with copy button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'WhatsApp Message Preview:',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                ),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: messagePreview));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Shopping list text clipboard par copy ho gaya! 📋'),
                                        duration: Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.copy_rounded, size: 13, color: Color(0xFF475569)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Copy Text',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Preview container
                            Container(
                              width: double.infinity,
                              height: 120,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: SingleChildScrollView(
                                child: Text(
                                  messagePreview,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    height: 1.35,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Tip info banner
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFF16A34A)),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'WhatsApp par sirf shopping list ke items share honge. Agar PDF report bhejni ho to "Share PDF File" use karein.',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF166534), height: 1.3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Actions
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // System PDF share sheet button
                          OutlinedButton.icon(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              Navigator.of(dialogContext).pop();
                              try {
                                await PdfGeneratorService.shareShoppingListPdfDocument(
                                  tripNum: tripNum,
                                  items: tripItems,
                                  isFrozen: isFrozen,
                                );
                              } catch (e) {
                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Share error: $e'),
                                      backgroundColor: Colors.red.shade700,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                            label: const Text(
                              'Share PDF File 📄',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),

                          // Direct WhatsApp button
                          ElevatedButton.icon(
                            onPressed: () async {
                              final phone = phoneController.text.trim();
                              final messenger = ScaffoldMessenger.of(context);

                              try {
                                final launched = await PdfGeneratorService.launchWhatsApp(
                                  message: messagePreview,
                                  phoneNumber: phone.isNotEmpty ? phone : null,
                                );

                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }

                                if (mounted) {
                                  if (launched) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text('WhatsApp open ho raha hai! (Shopping List #$tripNum)'),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: const Color(0xFF15803D),
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  } else {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: const Text('WhatsApp open nahi ho saka. Aap "Copy Text" karke direct WhatsApp me paste kar sakte hain.'),
                                        backgroundColor: Colors.orange.shade800,
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('WhatsApp share error: $e'),
                                      backgroundColor: Colors.red.shade700,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.send_rounded, size: 15),
                            label: const Text(
                              'WhatsApp par Bhejein 💬',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTripProductsDialog({
    required BuildContext context,
    required int tripNum,
    required List<ShoppingListItemModel> tripItems,
    required bool isFrozen,
  }) {
    // Exact sequence of addition (oldest createdAt first -> #1, #2, #3...)
    final orderedItems = List<ShoppingListItemModel>.from(tripItems);
    orderedItems.sort((a, b) {
      final dateA = a.createdAt;
      final dateB = b.createdAt;
      if (dateA != null && dateB != null) {
        return dateA.compareTo(dateB);
      } else if (dateA != null) {
        return -1;
      } else if (dateB != null) {
        return 1;
      }
      return 0;
    });

    final totalQty = orderedItems.fold<double>(
      0.0,
      (sum, item) => sum + item.quantityNeeded,
    );
    final formattedTotalQty = totalQty % 1 == 0 ? totalQty.toInt().toString() : totalQty.toStringAsFixed(1);
    final boughtCount = orderedItems.where((e) => e.resolved).length;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        String searchQuery = '';
        bool sortAscending = true; // true = sequence of addition (1..N)

        return StatefulBuilder(
          builder: (context, setModalState) {
            final isMobile = MediaQuery.of(context).size.width < 550;

            final currentItems = List<ShoppingListItemModel>.from(orderedItems);
            if (!sortAscending) {
              currentItems.sort((a, b) {
                final dateA = a.createdAt;
                final dateB = b.createdAt;
                if (dateA != null && dateB != null) {
                  return dateB.compareTo(dateA);
                }
                return 0;
              });
            }

            final filteredList = searchQuery.trim().isEmpty
                ? currentItems
                : currentItems
                    .where((item) => item.ingredientName.toLowerCase().contains(searchQuery.toLowerCase().trim()))
                    .toList();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 24,
                vertical: 20,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 580,
                  maxHeight: 720,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: isFrozen ? const Color(0xFF1E293B) : const Color(0xFF14532D),
                        border: Border(
                          bottom: BorderSide(
                            color: isFrozen ? const Color(0xFF334155) : const Color(0xFF15803D),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFrozen ? Icons.lock_outline_rounded : Icons.shopping_cart_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Shopping Cart #$tripNum Items',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: -0.3,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isFrozen ? const Color(0xFF475569) : const Color(0xFF22C55E),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isFrozen ? 'Finalized 🔒' : 'Active 🛒',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Sequence of Addition • ${orderedItems.length} Products Total',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                            onPressed: () {
                              _openShoppingListPdf(
                                tripNum: tripNum,
                                tripItems: orderedItems,
                                isFrozen: isFrozen,
                              );
                            },
                            tooltip: 'Open PDF Document',
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white70),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),

                    // KPI & Sequence Controls Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      color: isFrozen ? const Color(0xFFF1F5F9) : const Color(0xFFF0FDF4),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isFrozen ? const Color(0xFFCBD5E1) : const Color(0xFF86EFAC),
                                  ),
                                ),
                                child: Text(
                                  'Products: ${orderedItems.length}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isFrozen ? const Color(0xFF334155) : const Color(0xFF14532D),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isFrozen ? const Color(0xFFCBD5E1) : const Color(0xFF86EFAC),
                                  ),
                                ),
                                child: Text(
                                  'Total Qty: $formattedTotalQty',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isFrozen ? const Color(0xFF334155) : const Color(0xFF14532D),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (boughtCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$boughtCount bought',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // Sequence Order badge / button
                          InkWell(
                            onTap: () {
                              setModalState(() {
                                sortAscending = !sortAscending;
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    sortAscending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                    size: 13,
                                    color: const Color(0xFF475569),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    sortAscending ? 'Sequence: Added Order' : 'Sequence: Reverse Order',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (orderedItems.length > 5) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                        child: TextField(
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search items in this cart...',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                          style: const TextStyle(fontSize: 12),
                          onChanged: (val) {
                            setModalState(() {
                              searchQuery = val;
                            });
                          },
                        ),
                      ),
                    ],

                    const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.2)),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              'Sr #',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Items Name',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 85,
                            child: Text(
                              'Quantity',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Body
                    if (filteredList.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(28),
                        child: Center(
                          child: Text(
                            searchQuery.isNotEmpty
                                ? 'No products match "$searchQuery"'
                                : 'Is shopping cart me koi items nahi hain.',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: filteredList.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0xFFF1F5F9),
                            ),
                            itemBuilder: (context, index) {
                              final item = filteredList[index];
                              // Display original sequence of addition
                              final origSeq = orderedItems.indexOf(item) + 1;
                              final qtyStr = item.quantityNeeded % 1 == 0
                                  ? item.quantityNeeded.toInt().toString()
                                  : item.quantityNeeded.toString();
                              final isEven = index % 2 == 0;

                              return Container(
                                color: isEven ? Colors.white : const Color(0xFFFAFAFA),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Sequence / Serial #
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        '#$origSeq',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),

                                    // Item Name + Status Badge
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              item.ingredientName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: Color(0xFF1E293B),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (item.resolved)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFDCFCE7),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFF86EFAC)),
                                              ),
                                              child: const Text(
                                                'Bought ✓',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF15803D),
                                                ),
                                              ),
                                            )
                                          else
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFFFCD34D)),
                                              ),
                                              child: const Text(
                                                'To Buy 🛒',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF92400E),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    // Quantity on the other side
                                    SizedBox(
                                      width: 85,
                                      child: Container(
                                        alignment: Alignment.centerRight,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                          ),
                                          child: Text(
                                            qtyStr,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                    const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

                    // Footer with summary and close button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Products: ${filteredList.length} / ${orderedItems.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  _openShoppingListPdf(
                                    tripNum: tripNum,
                                    tripItems: orderedItems,
                                    isFrozen: isFrozen,
                                  );
                                },
                                icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                                label: const Text(
                                  'Open PDF 📄',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _showWhatsAppShareDialog(
                                    tripNum: tripNum,
                                    tripItems: orderedItems,
                                    isFrozen: isFrozen,
                                  );
                                },
                                icon: const Icon(Icons.share_rounded, size: 14),
                                label: const Text(
                                  'WhatsApp Share 💬',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isFrozen ? const Color(0xFF1E293B) : const Color(0xFF15803D),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTripSectionHeader({
    required int tripNum,
    required List<ShoppingListItemModel> tripItems,
    required List<ShoppingListItemModel> allTripProducts,
    required bool isFrozen,
    required bool isExpanded,
    required bool isReadOnly,
    required VoidCallback onToggle,
  }) {
    final pendingCount = tripItems.where((e) => !e.resolved).length;
    final boughtCount = tripItems.where((e) => e.resolved).length;

    if (!isFrozen) {
      // Active / In Progress List Header
      return InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(top: 6, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 640;

              final cartIcon = Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF15803D), size: 18),
              );

              final titleAndBadge = Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    tripNum > 1
                        ? 'New Shopping List #$tripNum (In Progress 🛒)'
                        : 'Active Shopping List (Trip #1 🛒)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF14532D),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isReadOnly ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isReadOnly ? const Color(0xFFFCD34D) : const Color(0xFF86EFAC)),
                    ),
                    child: Text(
                      isReadOnly ? 'Active (View-Only 👁️)' : 'Active / Editable',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isReadOnly ? const Color(0xFF92400E) : Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              );

              final subtitle = Text(
                '$pendingCount to buy • $boughtCount bought • Click to ${isExpanded ? 'collapse' : 'expand dropdown ▼'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.green.shade900.withValues(alpha: 0.8),
                ),
              );

              final expandChevron = Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Icon(
                  isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF15803D),
                  size: 20,
                ),
              );

              final actionButtons = <Widget>[
                if (!isReadOnly) ...[
                  ElevatedButton.icon(
                    onPressed: () => _confirmFinalizeLock(tripItems, tripNum),
                    icon: const Icon(Icons.lock_rounded, size: 13),
                    label: Text(
                      'Finalize #$tripNum 🔒',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton.icon(
                  onPressed: () => _openShoppingListPdf(
                    tripNum: tripNum,
                    tripItems: allTripProducts,
                    isFrozen: false,
                  ),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                  label: const Text(
                    'View List',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'WhatsApp par PDF & List Share karein',
                  child: ElevatedButton.icon(
                    onPressed: () => _showWhatsAppShareDialog(
                      tripNum: tripNum,
                      tripItems: allTripProducts,
                      isFrozen: false,
                    ),
                    icon: const Icon(Icons.share_rounded, size: 14),
                    label: const Text(
                      'Share',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Quick Table View in App',
                  child: InkWell(
                    onTap: () => _showTripProductsDialog(
                      context: context,
                      tripNum: tripNum,
                      tripItems: allTripProducts,
                      isFrozen: false,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: const Icon(Icons.table_chart_outlined, size: 15, color: Color(0xFF15803D)),
                    ),
                  ),
                ),
              ];

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        cartIcon,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              titleAndBadge,
                              const SizedBox(height: 6),
                              subtitle,
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        expandChevron,
                      ],
                    ),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: actionButtons,
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  cartIcon,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleAndBadge,
                        const SizedBox(height: 4),
                        subtitle,
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...actionButtons,
                      const SizedBox(width: 8),
                      expandChevron,
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      );
    } else {
      // Finalized & Locked List Header
      return InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(top: 6, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 640;

              final lockIcon = Container(
                padding: const EdgeInsets.all(7),
                decoration: const BoxDecoration(
                  color: Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded, color: Color(0xFF475569), size: 16),
              );

              final titleAndBadge = Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Shopping List #$tripNum (Finalized 🔒)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Frozen / Immutable',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              );

              final subtitle = Text(
                '${tripItems.length} items locked • Click karke list dropdown ${isExpanded ? 'band karein ▲' : 'dekhein ▼'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              );

              final expandChevron = Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Icon(
                  isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF475569),
                  size: 20,
                ),
              );

              final actionButtons = <Widget>[
                ElevatedButton.icon(
                  onPressed: () => _openShoppingListPdf(
                    tripNum: tripNum,
                    tripItems: allTripProducts,
                    isFrozen: true,
                  ),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                  label: const Text(
                    'View List',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF334155),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'WhatsApp par PDF & List Share karein',
                  child: ElevatedButton.icon(
                    onPressed: () => _showWhatsAppShareDialog(
                      tripNum: tripNum,
                      tripItems: allTripProducts,
                      isFrozen: true,
                    ),
                    icon: const Icon(Icons.share_rounded, size: 14),
                    label: const Text(
                      'Share',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Quick Table View in App',
                  child: InkWell(
                    onTap: () => _showTripProductsDialog(
                      context: context,
                      tripNum: tripNum,
                      tripItems: allTripProducts,
                      isFrozen: true,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Icon(Icons.table_chart_outlined, size: 15, color: Color(0xFF475569)),
                    ),
                  ),
                ),
              ];

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        lockIcon,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              titleAndBadge,
                              const SizedBox(height: 6),
                              subtitle,
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        expandChevron,
                      ],
                    ),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: actionButtons,
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  lockIcon,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleAndBadge,
                        const SizedBox(height: 4),
                        subtitle,
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...actionButtons,
                      const SizedBox(width: 8),
                      expandChevron,
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      );
    }
  }

  Widget _buildKpiItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    bool highlight = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: highlight ? AppColors.primaryDark : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterTab(String filterKey, String title) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(title),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = filterKey);
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
    );
  }

  Widget _buildEmptyState() {
    final monthName = DateFormat('MMMM yyyy').format(_selectedMonth);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              size: 44,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _selectedFilter == 'Bought'
                ? 'No purchases recorded for $monthName'
                : 'No shopping items found for $monthName',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isMonthFilterActive
                ? 'Use the < and > arrows to browse previous months or add new items above.'
                : 'Your shopping list is empty! Type an item above to add it.',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
