import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/audio_alarm_service.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/utils/pdf_generator_service.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../dashboard/presentation/screens/main_shell.dart';
import '../../../shopping_list/providers/shopping_list_provider.dart';
import '../../data/models/ingredient_model.dart';
import '../../providers/inventory_provider.dart';
import 'package:smart_pantry_app/features/inventory/presentation/widgets/add_to_shopping_dialog.dart';

final shiftClockStreamProvider = StreamProvider.autoDispose<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 2), (_) => DateTime.now());
});

class MonthlyStockRegisterSheet extends ConsumerStatefulWidget {
  final List<IngredientModel> items;
  final bool isArchive;
  final String? monthLabel;
  final VoidCallback? onSwitchToLive;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onScrollToTop;
  final dynamic archiveData;

  const MonthlyStockRegisterSheet({
    super.key,
    required this.items,
    this.isArchive = false,
    this.monthLabel,
    this.onSwitchToLive,
    this.onOpenCalendar,
    this.onScrollToTop,
    this.archiveData,
  });

  @override
  ConsumerState<MonthlyStockRegisterSheet> createState() => _MonthlyStockRegisterSheetState();
}

class _MonthlyStockRegisterSheetState extends ConsumerState<MonthlyStockRegisterSheet> {
  final ScrollController _headerHorizontalScrollController = ScrollController();
  final ScrollController _bodyHorizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  bool _syncingHorizontal = false;
  final String _filterCategory = 'All';
  String _searchQuery = '';

  Timer? _shiftCheckTimer;
  bool? _lastShiftAllowed;
  BuildContext? _activeQuickLogDialogContext;

  static const double _headerHeight = 46.0;
  static const double _rowHeight = 52.0;
  static const double _srWidth = 38.0;
  static const double _nameWidth = 232.0; // Pinned total = 270
  static const double _stockInWidth = 85.0;
  static const double _dayWidth = 38.0;
  static const double _usedWidth = 75.0;
  static const double _balanceWidth = 85.0;
  static const double _shoppingWidth = 220.0;

  @override
  void initState() {
    super.initState();
    _bodyHorizontalScrollController.addListener(() {
      if (_syncingHorizontal) return;
      _syncingHorizontal = true;
      try {
        if (_headerHorizontalScrollController.hasClients &&
            _headerHorizontalScrollController.offset != _bodyHorizontalScrollController.offset) {
          _headerHorizontalScrollController.jumpTo(_bodyHorizontalScrollController.offset);
        }
      } finally {
        _syncingHorizontal = false;
      }
    });

    _headerHorizontalScrollController.addListener(() {
      if (_syncingHorizontal) return;
      _syncingHorizontal = true;
      try {
        if (_bodyHorizontalScrollController.hasClients &&
            _bodyHorizontalScrollController.offset != _headerHorizontalScrollController.offset) {
          _bodyHorizontalScrollController.jumpTo(_headerHorizontalScrollController.offset);
        }
      } finally {
        _syncingHorizontal = false;
      }
    });

    // Real-time shift expiration ticker: checks every 2 seconds
    _shiftCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      final currentUser = ref.read(authControllerProvider).valueOrNull;
      if (currentUser == null || !currentUser.isShiftRestricted) return;

      final isAllowedNow = currentUser.isWithinAllowedShift();
      if (_lastShiftAllowed != null && _lastShiftAllowed != isAllowedNow) {
        if (!isAllowedNow) {
          // SHIFT JUST EXPIRED IN REAL TIME!
          // 1. Dismiss open quick log dialog immediately
          if (_activeQuickLogDialogContext != null && Navigator.canPop(_activeQuickLogDialogContext!)) {
            Navigator.pop(_activeQuickLogDialogContext!);
            _activeQuickLogDialogContext = null;
          }
          // 2. Play audible alarm
          AudioAlarmService.playAlarmChime();
          // 3. Show prominent warning notification
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '⏰ Shift Time Khatam: Aap ka shift time (${currentUser.shiftDisplayLabel}) khatam ho chuka hai! Expense sheet entry ab lock ho chuki hai.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red.shade800,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          // SHIFT JUST STARTED IN REAL TIME!
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.access_time_filled_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '☀️ Shift Shuru: Aap ki shift (${currentUser.shiftDisplayLabel}) shuru ho chuki hai. Entry access open ho gaya hai!',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF047857),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        _lastShiftAllowed = isAllowedNow;
        setState(() {});
      } else {
        _lastShiftAllowed ??= isAllowedNow;
      }
    });
  }

  @override
  void dispose() {
    _shiftCheckTimer?.cancel();
    _headerHorizontalScrollController.dispose();
    _bodyHorizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _scrollToDays(double offset) {
    if (_bodyHorizontalScrollController.hasClients) {
      _bodyHorizontalScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // =========================================================================
  // DIALOGS: ADD, EDIT, DELETE, RESTOCK, USAGE, CLEAR, CLOSE MONTH
  // =========================================================================

  void _showAddItemDialog() {
    final nameCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'Other');
    final unitCtrl = TextEditingController(text: 'pcs');
    final stockInCtrl = TextEditingController(text: '10');
    final thresholdCtrl = TextEditingController(text: '3');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryDark, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('+ Add Item to Register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Item Name *',
                  hintText: 'e.g. Everyday 2kg, Surf, Scotch Brite',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: 'Other',
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: ['Other', 'Dairy', 'Pantry', 'Groceries', 'Beverages', 'Cleaning']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) => categoryCtrl.text = val ?? 'Other',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: 'pcs',
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: ['pcs', 'kg', 'bottle', 'roll', 'box', 'pack', 'liter', 'bags']
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (val) => unitCtrl.text = val ?? 'pcs',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: stockInCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Initial Stock In',
                        hintText: 'e.g. 20',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: thresholdCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Low Stock Alert',
                        hintText: 'e.g. 5',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final qty = double.tryParse(stockInCtrl.text.trim()) ?? 0.0;
              final th = double.tryParse(thresholdCtrl.text.trim()) ?? 3.0;

              Navigator.pop(ctx);
              await ref.read(inventoryControllerProvider.notifier).addIngredient(
                IngredientModel(
                  name: name,
                  category: categoryCtrl.text.trim(),
                  unit: unitCtrl.text.trim(),
                  quantity: qty,
                  stockIn: qty,
                  totalUsed: 0,
                  dailyUsageLogs: {},
                  lowStockThreshold: th,
                  expiryDate: DateTime.now().add(const Duration(days: 365)),
                ),
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added "$name" to register!'),
                    backgroundColor: AppColors.primaryDark,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showEditItemDialog(IngredientModel item) {
    final nameCtrl = TextEditingController(text: item.name);
    final categoryCtrl = TextEditingController(text: item.category);
    final unitCtrl = TextEditingController(text: item.unit);
    final thresholdCtrl = TextEditingController(
      text: item.lowStockThreshold != null
          ? (item.lowStockThreshold! % 1 == 0 ? item.lowStockThreshold!.toInt().toString() : item.lowStockThreshold.toString())
          : '3',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_note_rounded, color: Color(0xFF1D4ED8), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Edit Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(item.name, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: categoryCtrl,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: unitCtrl,
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: thresholdCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Low Stock Threshold',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty || item.id == null) return;
              final th = double.tryParse(thresholdCtrl.text.trim()) ?? 3.0;

              Navigator.pop(ctx);
              await ref.read(inventoryControllerProvider.notifier).updateIngredient(item.id!, {
                'name': newName,
                'category': categoryCtrl.text.trim(),
                'unit': unitCtrl.text.trim(),
                'lowStockThreshold': th,
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Updated "$newName"!'),
                    backgroundColor: AppColors.primaryDark,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showDeleteItemDialog(IngredientModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Delete Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'Kya aap waqai "${item.name}" ko register se delete karna chahte hain?\nIs item ka tamam data aur logs khatam ho jayenge.',
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (item.id == null) return;
              Navigator.pop(ctx);
              await ref.read(inventoryControllerProvider.notifier).deleteIngredient(item.id!);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleted "${item.name}" from register.'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showClearDaysDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cleaning_services_rounded, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Clear All Days Data?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text(
          'Yeh action is mahine ke tamam days (1–31) ka entered usage data empty (0) kar dega aur in-hand balance ko wapis starting Stock In ke barabar le aayega.\n\nItems delete nahi honge, sirf daily consumption clear hogi. Kya aap clear karna chahte hain?',
          style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(inventoryControllerProvider.notifier).clearMonthDays();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All days usage data cleared! Stock balance restored to Stock In.'),
                    backgroundColor: AppColors.primaryDark,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Yes, Clear All Days', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showCloseMonthDialog(double totalStockIn, double totalUsed, double inHandBalance) {
    final now = DateTime.now();
    final defaultMonth = DateFormat('MMMM yyyy').format(now);
    final daysInCurrentMonth = DateTime(now.year, now.month + 1, 0).day;
    final isMonthCompleted = now.day >= daysInCurrentMonth;
    final remainingDays = daysInCurrentMonth - now.day;

    bool isEmergencyOverride = false;
    String? overrideError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMonthCompleted ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isMonthCompleted ? Icons.task_alt_rounded : Icons.lock_clock_rounded,
                    color: isMonthCompleted ? const Color(0xFF047857) : const Color(0xFFD97706),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isMonthCompleted
                        ? 'Done (Close & Finalize Month)'
                        : 'Mahina Abhi Khatam Nahi Hua',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Calendar Info Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMonthCompleted ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isMonthCompleted ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 16,
                              color: isMonthCompleted ? const Color(0xFF047857) : const Color(0xFF92400E),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Laptop Live Date: ${DateFormat('dd MMMM yyyy').format(now)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isMonthCompleted ? const Color(0xFF047857) : const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (isMonthCompleted) ...[
                          Text(
                            '✨ Mahina Mukammal Ho Chuka Hai ($daysInCurrentMonth $defaultMonth). Aap ab is register ko close kar saktay hain.',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF065F46), height: 1.3),
                          ),
                        ] else ...[
                          Text(
                            '⏳ Yeh mahina $daysInCurrentMonth $defaultMonth ko khatam hoga ($remainingDays din baqi hain).',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Laptop ke live calendar ke mutabiq yeh mahina abhi jari hai. Stock register ko mahina khatam hone se pehle close nahi kiya ja sakta taakay tamaam dino ka hisaab mehfooz rahay.',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF78350F), height: 1.35),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // What happens on closing description
                  const Text(
                    'Mahina close hone par kya hoga:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '1. Is month ki PDF generate ho kar foran download hogi.\n'
                    '2. Poora record "Archived Reports" mein hamesha ke liye save hoga.\n'
                    '3. Har item ka In-Hand Balance aglay mahine ka "Stock In" ban jayega.\n'
                    '4. Days 1–31 aur Total Used zero reset ho jayenge.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.35),
                  ),

                  const SizedBox(height: 14),

                  // Month Name (Locked to live calendar)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_note_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Register Month: $defaultMonth',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),

                  // Admin Testing / Emergency Override (Only if month not finished)
                  if (!isMonthCompleted) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: isEmergencyOverride ? const Color(0xFFFFFBEB) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isEmergencyOverride ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: CheckboxListTile(
                        value: isEmergencyOverride,
                        onChanged: (val) {
                          setDialogState(() {
                            isEmergencyOverride = val ?? false;
                            overrideError = null;
                          });
                        },
                        dense: true,
                        activeColor: const Color(0xFFD97706),
                        title: const Text(
                          'Admin Testing / Emergency Override',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                        ),
                        subtitle: const Text(
                          'Main testing / emergency ke tehat waqt se pehle close karna chahta hoon.',
                          style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                  ],

                  if (overrideError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      overrideError!,
                      style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isMonthCompleted || isEmergencyOverride)
                      ? const Color(0xFF047857)
                      : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(
                  (isMonthCompleted || isEmergencyOverride)
                      ? Icons.picture_as_pdf_rounded
                      : Icons.lock_rounded,
                  size: 18,
                ),
                label: Text(
                  isMonthCompleted
                      ? 'Close Month & Export PDF'
                      : (isEmergencyOverride ? 'Force Close (Override) & PDF' : 'Month Khatam Hone Par Close Hoga'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: (isMonthCompleted || isEmergencyOverride)
                    ? () async {
                        final monthLabel = defaultMonth;
                        Navigator.pop(ctx);

                        // 1. Generate & download PDF before rollover
                        final currentLiveItems = ref.read(inventoryControllerProvider).valueOrNull ?? widget.items;
                        await PdfGeneratorService.generateAndDownloadPdf(
                          monthYear: monthLabel,
                          items: currentLiveItems,
                          totalStockIn: totalStockIn,
                          totalUsed: totalUsed,
                          inHandBalance: inHandBalance,
                        );

                        // 2. Call backend to rollover closing balance into opening Stock In
                        try {
                          await ref.read(inventoryControllerProvider.notifier).closeMonth(
                                monthLabel,
                                force: isEmergencyOverride,
                              );

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Month "$monthLabel" closed! PDF downloaded & remaining balance rolled over to Stock In.'),
                                backgroundColor: const Color(0xFF047857),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 5),
                                action: SnackBarAction(
                                  label: 'View in PDFs',
                                  textColor: Colors.white,
                                  onPressed: () => ref.read(activeNavTabProvider.notifier).state = 3,
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error closing month: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      }
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }

  void _showQuickLogUsageDialog(IngredientModel item, [int? presetDay]) {
    final targetDay = presetDay ?? DateTime.now().day;
    final dayKey = '$targetDay';
    final currentUser = ref.read(authControllerProvider).valueOrNull;
    final isAdmin = currentUser?.isAdmin ?? false;
    final isStaff = !isAdmin;
    final isReadOnly = currentUser?.isReadOnly ?? false;
    final isShiftRestricted = currentUser?.isShiftRestricted ?? false;
    final isWithinShift = currentUser?.isWithinAllowedShift() ?? true;

    // For staff: Check if THIS user already logged their shift entry on targetDay!
    final staffEntryVal = isStaff
        ? item.getStaffUsageOnDay(dayKey, currentUser?.id, currentUser?.email)
        : null;
    final hasStaffAlreadyLogged = isStaff && staffEntryVal != null && staffEntryVal > 0;
    final currentDayVal = item.dailyUsageLogs?[dayKey];

    if (isStaff && (targetDay != DateTime.now().day || hasStaffAlreadyLogged)) {
      final nowDay = DateTime.now().day;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  targetDay != nowDay
                      ? (targetDay < nowDay
                          ? '🔒 Pichli Tareekh Lock Hai: Aap sirf aaj ki tareekh ($nowDay) mein entry kar saktay hain. Pichla data sirf Admin edit kar sakta hai.'
                          : '🔒 Yeh Tareekh Abhi Aayi Nahi: Sirf aaj ki tareekh ($nowDay) mein entry ki ijazat hai.')
                      : '🔒 Day $targetDay ka data (${staffEntryVal != null ? (staffEntryVal % 1 == 0 ? staffEntryVal.toInt() : staffEntryVal) : ""}) aap already enter kar chuke hain. Is ko ab sirf Admin hi update kar sakta hai.',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF334155),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (isShiftRestricted && !isWithinShift) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock_clock_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⏰ Shift Closed: Aap ki shift (${currentUser?.shiftDisplayLabel}) abhi active nahi hai. Aap sirf apni shift ke dauran entry kar sakte hain.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final isEditingExisting = isAdmin && currentDayVal != null && currentDayVal > 0;
    final reasonController = TextEditingController();
    String? reasonErrorText;

    final dayController = TextEditingController(text: '$targetDay');
    final amountController = TextEditingController(
      text: isEditingExisting
          ? '${currentDayVal % 1 == 0 ? currentDayVal.toInt() : currentDayVal}'
          : (staffEntryVal != null && staffEntryVal > 0
              ? '${staffEntryVal % 1 == 0 ? staffEntryVal.toInt() : staffEntryVal}'
              : (item.dailyUsage != null && item.dailyUsage! > 0
                  ? '${item.dailyUsage! % 1 == 0 ? item.dailyUsage!.toInt() : item.dailyUsage}'
                  : '1')),
    );

    amountController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: amountController.text.length,
    );

    showDialog(
      context: context,
      builder: (ctx) {
        _activeQuickLogDialogContext = ctx;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isEditingExisting ? const Color(0xFFFEF3C7) : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEditingExisting ? Icons.edit_note_rounded : Icons.edit_calendar_rounded,
                      color: isEditingExisting ? const Color(0xFFD97706) : AppColors.primary,
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
                          isEditingExisting ? 'Edit Day $targetDay (Admin Update)' : 'Log Day $targetDay Usage',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        Text(item.name, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isShiftRestricted) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_filled_rounded, color: Color(0xFF047857), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Shift Active: ${currentUser?.shiftDisplayLabel} (Entry Allowed)',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF065F46), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (isReadOnly) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lock_clock_rounded, color: Color(0xFFD97706), size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Note: Ek dafa enter karne par yeh cell lock ho jayega aur dobara sirf Admin hi edit kar sakega.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (isEditingExisting) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pehle se entered data: $currentDayVal ${item.unit}. Is ko update karne ke liye Reason (wajah) likhna lazmi hai.',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.3, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Stock In: ${item.effectiveStockIn % 1 == 0 ? item.effectiveStockIn.toInt() : item.effectiveStockIn} ${item.unit}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text('In-Hand: ${item.inHandBalance % 1 == 0 ? item.inHandBalance.toInt() : item.inHandBalance.toStringAsFixed(1)} ${item.unit}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: item.inHandBalance < 0 ? AppColors.error : AppColors.primaryDark,
                            )),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: TextFormField(
                            controller: dayController,
                            keyboardType: TextInputType.number,
                            readOnly: isStaff,
                            decoration: InputDecoration(
                              labelText: isAdmin ? 'Day (1-31)' : 'Day (Aaj / Today)',
                              prefixIcon: Icon(
                                isStaff ? Icons.lock_outline_rounded : Icons.calendar_today_rounded,
                                size: 18,
                                color: isStaff ? Colors.blueGrey : null,
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 5,
                          child: TextFormField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            autofocus: !isEditingExisting,
                            decoration: InputDecoration(
                              labelText: 'Used (${item.unit})',
                              hintText: 'e.g. 2',
                              prefixIcon: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: AppColors.warning),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isEditingExisting) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: reasonController,
                        autofocus: true,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Reason for Update (Lazmi / Mandatory) *',
                          labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB45309), fontSize: 13),
                          hintText: 'e.g. Galat entry ho gayi thi, recount kiya, extra use hua...',
                          hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          errorText: reasonErrorText,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 24),
                            child: Icon(Icons.rate_review_rounded, size: 18, color: Color(0xFFD97706)),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFFFFBEB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFFDE68A)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.8),
                          ),
                        ),
                        onChanged: (val) {
                          if (reasonErrorText != null && val.trim().isNotEmpty) {
                            setDialogState(() {
                              reasonErrorText = null;
                            });
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      isEditingExisting
                          ? '💡 Update karne par is cell ka color tabdeel ho jayega taake record rahe ke yeh edit hua hai.'
                          : '💡 Day enter karne par register ke day cell mein show hoga aur In-Hand Balance foran kam ho jayega.',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEditingExisting ? const Color(0xFFD97706) : AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final day = int.tryParse(dayController.text.trim()) ?? targetDay;
                    final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (day < 1 || day > 31 || amt < 0) return;

                    if (isStaff && (day != DateTime.now().day || hasStaffAlreadyLogged)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            day != DateTime.now().day
                                ? '🔒 Aap sirf aaj ki tareekh (${DateTime.now().day}) mein entry kar saktay hain.'
                                : '🔒 Day $day ka data aap already enter kar chuke hain. Is ko sirf Admin update kar sakta hai.',
                          ),
                          backgroundColor: const Color(0xFF334155),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    if (isEditingExisting && reasonController.text.trim().isEmpty) {
                      setDialogState(() {
                        reasonErrorText = 'Update ki wajah (Reason) likhna lazmi hai!';
                      });
                      return;
                    }

                    Navigator.pop(ctx);
                    if (item.id != null) {
                      try {
                        await ref.read(inventoryControllerProvider.notifier).logUsage(
                              item.id!,
                              day,
                              amt,
                              isOverwrite: true,
                              reason: isEditingExisting ? reasonController.text.trim() : null,
                            );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEditingExisting
                                    ? '✏️ Updated Day $day for "${item.name}" (Reason: ${reasonController.text.trim()})'
                                    : 'Updated Day $day usage to $amt ${item.unit} for "${item.name}"!',
                              ),
                              backgroundColor: isEditingExisting ? const Color(0xFFB45309) : AppColors.primaryDark,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$e'),
                              backgroundColor: Colors.red.shade700,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: Text(isEditingExisting ? 'Save & Record Edit' : 'Save Usage'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      _activeQuickLogDialogContext = null;
    });
  }

  void _showArchiveDayDetailsDialog(
    IngredientModel item,
    int day,
    double? usedOnDay,
    bool isEdited,
    String? editReason,
    String? editedBy,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isEdited ? const Color(0xFFFEF3C7) : const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isEdited ? Icons.edit_note_rounded : Icons.history_rounded,
                color: isEdited ? const Color(0xFFD97706) : const Color(0xFF0284C7),
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
                    'Day $day Consumption',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    widget.monthLabel ?? 'Archived Month',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Category: ${item.category} • Unit: ${item.unit}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Quantity Consumed (Used):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        usedOnDay != null && usedOnDay > 0
                            ? '${usedOnDay % 1 == 0 ? usedOnDay.toInt() : usedOnDay} ${item.unit}'
                            : '0 ${item.unit} (No usage recorded)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: usedOnDay != null && usedOnDay > 0 ? const Color(0xFF0369A1) : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isEdited) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFFB45309)),
                        const SizedBox(width: 6),
                        const Text(
                          'Cell Edit Audit Record',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF92400E)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Wajah / Reason: ${editReason ?? "Admin Update"}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF78350F)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Updated By: ${editedBy ?? "Admin"}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_rounded, size: 14, color: Color(0xFFB45309)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '🔒 Yeh pichlay mahine ka record hai, isay tabdeel nahi kiya ja sakta.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Theek Hai (OK)'),
          ),
        ],
      ),
    );
  }

  void _showQuickRestockDialog(IngredientModel item) {
    final qtyController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF08A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_shopping_cart_rounded, color: Color(0xFF854D0E), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('New Stock Enter (Stock In)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(item.name, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Stock In: ${item.effectiveStockIn % 1 == 0 ? item.effectiveStockIn.toInt() : item.effectiveStockIn} ${item.unit}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text('Current In-Hand Balance: ${item.inHandBalance % 1 == 0 ? item.inHandBalance.toInt() : item.inHandBalance.toStringAsFixed(1)} ${item.unit}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
            const SizedBox(height: 14),
            TextFormField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Add Stock Quantity (${item.unit})',
                hintText: 'e.g. 20',
                prefixIcon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.success),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '💡 Yeh quantity duplicate entry banaye baghair isi item ke Stock In aur In-Hand Balance mein add ho jayegi.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEAB308),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final added = double.tryParse(qtyController.text.trim()) ?? 0.0;
              if (added <= 0) return;

              Navigator.pop(ctx);
              if (item.id != null) {
                await ref.read(inventoryControllerProvider.notifier).restock(item.id!, added);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added +$added ${item.unit} to "${item.name}" stock!'),
                      backgroundColor: AppColors.primaryDark,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Add to Stock (Stock In)', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _addAllNeededToShoppingList(List<IngredientModel> itemsNeedingShopping) {
    for (final item in itemsNeedingShopping) {
      final needed = item.shoppingNeededQty;
      if (needed > 0) {
        ref.read(shoppingListControllerProvider.notifier).addItem(
          item.name,
          needed % 1 == 0 ? needed : double.parse(needed.toStringAsFixed(1)),
          'Monthly Stock Deficit (<=${item.lowStockThreshold ?? 3})',
        );
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${itemsNeedingShopping.length} deficit items to Shopping List!'),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild every 2 seconds to reactively track shift minute changes in real time
    ref.watch(shiftClockStreamProvider);

    final authState = ref.watch(authControllerProvider);
    final currentUser = authState.valueOrNull;
    final isReadOnly = currentUser?.isReadOnly ?? false;
    final clearedDaysBanner = ref.watch(activeClearedDaysBannerProvider);

    // Watch live items so real-time socket events instantly rebuild the sheet,
    // but if viewing an archive, preserve the historic archived items!
    final liveItems = widget.isArchive
        ? widget.items
        : (ref.watch(inventoryControllerProvider).valueOrNull ?? widget.items);

    final filtered = liveItems.where((e) {
      final matchesCat = _filterCategory == 'All' || e.category == _filterCategory;
      final matchesSearch = _searchQuery.isEmpty || e.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    final itemsNeedingShopping = liveItems.where((e) => e.shoppingNeededQty > 0).toList();

    final totalStockIn = liveItems.fold<double>(0, (sum, e) => sum + e.effectiveStockIn);
    final totalUsedAll = liveItems.fold<double>(0, (sum, e) => sum + e.effectiveUsed);
    final totalBalanceAll = liveItems.fold<double>(0, (sum, e) => sum + e.inHandBalance);

    const daysCount = 31;
    final List<int> days = List.generate(daysCount, (i) => i + 1);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final srWidth = isMobile ? 26.0 : _srWidth;
    final nameWidth = isMobile ? 110.0 : _nameWidth;
    final pinnedWidth = srWidth + nameWidth;
    final totalScrollableWidth = _stockInWidth + (daysCount * _dayWidth) + _usedWidth + _balanceWidth + _shoppingWidth;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Historic Archive Read-Only Notice Banner
          if (widget.isArchive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Color(0xFFFDE68A))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.history_edu_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Pichla Mahina: ${widget.monthLabel ?? "Archived Month"}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF92400E),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDE68A),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Read-Only Historic Record',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF78350F)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Yeh pichlay mahine ka band shuda (finalized) record hai. Tamam entries mahfooz hain.',
                          style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onSwitchToLive != null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: widget.onSwitchToLive,
                      icon: const Icon(Icons.arrow_back_rounded, size: 15),
                      label: const Text('Live Current Month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),

          // Real-Time Notification Banner when Admin clears days
          if (clearedDaysBanner != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Color(0xFF86EFAC))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cleaning_services_rounded, color: Color(0xFF15803D), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      clearedDaysBanner,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF166534)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => ref.read(activeClearedDaysBannerProvider.notifier).state = null,
                  ),
                ],
              ),
            ),

          // Top Excel Yellow Header Banner with Action Buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF08A), // Excel Yellow Header
              borderRadius: (clearedDaysBanner != null || widget.isArchive)
                  ? BorderRadius.zero
                  : const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.table_chart_rounded, color: Color(0xFF854D0E), size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.isArchive
                            ? 'Office Expense Detail (${widget.monthLabel})'
                            : 'Office Expense Detail (${DateFormat('MMMM yyyy').format(DateTime.now())})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF854D0E),
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Action Buttons: Calendar, + Add Item, Clear Days, Done (Close Month) / Archive Download
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Calendar / Month Switcher Button
                    if (widget.onOpenCalendar != null)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: widget.isArchive ? const Color(0xFF92400E) : const Color(0xFF047857),
                          side: BorderSide(
                            color: widget.isArchive ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: widget.onOpenCalendar,
                        icon: Icon(
                          Icons.calendar_month_rounded,
                          size: 16,
                          color: widget.isArchive ? const Color(0xFFD97706) : const Color(0xFF047857),
                        ),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.isArchive ? '${widget.monthLabel}' : 'Month: ${DateFormat('MMMM yyyy').format(DateTime.now())}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down_rounded, size: 18),
                          ],
                        ),
                      ),

                    // ARCHIVE MODE CONTROLS: Download PDF & Switch to Live Month
                    if (widget.isArchive) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF047857), // Emerald Green
                          foregroundColor: Colors.white,
                          elevation: 1,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          await PdfGeneratorService.generateAndDownloadPdf(
                            monthYear: widget.monthLabel ?? 'Archived Month',
                            items: widget.items,
                            totalStockIn: totalStockIn,
                            totalUsed: totalUsedAll,
                            inHandBalance: totalBalanceAll,
                          );
                        },
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                      if (widget.onSwitchToLive != null)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            foregroundColor: Colors.white,
                            elevation: 1,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: widget.onSwitchToLive,
                          icon: const Icon(Icons.arrow_back_rounded, size: 15),
                          label: const Text('Live Month', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                    ] else ...[
                      // LIVE MODE CONTROLS:
                      // View-Only / Staff Shift Status Badge when restricted
                      if (isReadOnly) ...[
                        if (currentUser != null && currentUser.isShiftRestricted) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: currentUser.isWithinAllowedShift()
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: currentUser.isWithinAllowedShift()
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  currentUser.isWithinAllowedShift()
                                      ? Icons.access_time_filled_rounded
                                      : Icons.lock_clock_rounded,
                                  size: 16,
                                  color: currentUser.isWithinAllowedShift()
                                      ? const Color(0xFF047857)
                                      : const Color(0xFFDC2626),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  currentUser.isWithinAllowedShift()
                                      ? 'Shift Active: ${currentUser.shiftDisplayLabel} (Entry Allowed ✍️)'
                                      : 'Shift Closed (${currentUser.shiftDisplayLabel}) - Entry Locked 🔒',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: currentUser.isWithinAllowedShift()
                                        ? const Color(0xFF047857)
                                        : const Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFD97706)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_calendar_rounded, size: 16, color: Color(0xFFB45309)),
                                SizedBox(width: 6),
                                Text(
                                  'Staff Entry Mode (Khali Day Cells Enter Karein ✍️)',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFFB45309)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ] else ...[
                        // + Add Item Button
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF854D0E),
                            elevation: 1,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _showAddItemDialog,
                          icon: const Icon(Icons.add_circle_rounded, size: 16, color: Color(0xFFD97706)),
                          label: const Text('+ Add Item', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        ),

                        // Clear Days Button
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFF87171)),
                            backgroundColor: Colors.white.withValues(alpha: 0.7),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _showClearDaysDialog,
                          icon: const Icon(Icons.cleaning_services_rounded, size: 16),
                          label: const Text('Clear Days', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        ),

                        // Done / Close Month Button (Live Calendar sync)
                        Builder(
                          builder: (context) {
                            final nowBtn = DateTime.now();
                            final daysInMonthBtn = DateTime(nowBtn.year, nowBtn.month + 1, 0).day;
                            final isMonthCompletedBtn = nowBtn.day >= daysInMonthBtn;
                            final remainingDaysBtn = daysInMonthBtn - nowBtn.day;

                            return ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isMonthCompletedBtn ? const Color(0xFF047857) : const Color(0xFF0F766E),
                                foregroundColor: Colors.white,
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _showCloseMonthDialog(totalStockIn, totalUsedAll, totalBalanceAll),
                              icon: Icon(
                                isMonthCompletedBtn ? Icons.task_alt_rounded : Icons.lock_clock_rounded,
                                size: 16,
                                color: isMonthCompletedBtn ? Colors.white : const Color(0xFFFDE68A),
                              ),
                              label: Text(
                                isMonthCompletedBtn ? 'Done (Close Month ✨)' : 'Done (Close Month • ${remainingDaysBtn}d left)',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                            );
                          },
                        ),
                      ],

                      // Auto-Add to Shopping List Button (Only if can edit)
                      if (!isReadOnly && itemsNeedingShopping.isNotEmpty)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE11D48), // Rose red
                            foregroundColor: Colors.white,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _addAllNeededToShoppingList(itemsNeedingShopping),
                          icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 16),
                          label: Text(
                            'Auto-Add (${itemsNeedingShopping.length})',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ),
                    ],

                    // View All Saved PDFs Button (Viewing allowed for both)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE11D48),
                        side: const BorderSide(color: Color(0xFFFDA4AF)),
                        backgroundColor: const Color(0xFFFFF1F2),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => ref.read(activeNavTabProvider.notifier).state = 3,
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                      label: const Text('All Saved PDFs', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    ),

                    // Quick Jump to Top of page (mobile view)
                    if (widget.onScrollToTop != null)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: widget.onScrollToTop,
                        icon: const Icon(Icons.arrow_upward_rounded, size: 15, color: Color(0xFF475569)),
                        label: const Text('Top ⬆️', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Search Bar & Horizontal Quick Scroll Navigation Controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFFFAFAFA),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 750;

                final searchField = Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: const InputDecoration(
                      hintText: 'Search items (e.g. Everyday, Lipton, Tissue)...',
                      hintStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                );

                final jumpAndBadges = SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.onScrollToTop != null) ...[
                              _buildJumpBtn('⬆️ Top', widget.onScrollToTop!),
                              const SizedBox(width: 4),
                            ],
                            const Text('Jump: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            _buildJumpBtn('Stock In', () => _scrollToDays(0)),
                            const SizedBox(width: 4),
                            _buildJumpBtn('Days 1–15', () => _scrollToDays(85)),
                            const SizedBox(width: 4),
                            _buildJumpBtn('Days 16–31', () => _scrollToDays(650)),
                            const SizedBox(width: 4),
                            _buildJumpBtn('Balance →', () => _scrollToDays(1200)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildKpiBadge('Stock In', '${totalStockIn % 1 == 0 ? totalStockIn.toInt() : totalStockIn.toStringAsFixed(1)}', const Color(0xFFFEF08A), const Color(0xFF854D0E)),
                      const SizedBox(width: 6),
                      _buildKpiBadge('Used', '${totalUsedAll % 1 == 0 ? totalUsedAll.toInt() : totalUsedAll.toStringAsFixed(1)}', const Color(0xFFF1F5F9), const Color(0xFF475569)),
                      const SizedBox(width: 6),
                      _buildKpiBadge('Balance', '${totalBalanceAll % 1 == 0 ? totalBalanceAll.toInt() : totalBalanceAll.toStringAsFixed(1)}', const Color(0xFFFCE7F3), const Color(0xFFBE185D)),
                    ],
                  ),
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchField,
                      const SizedBox(height: 8),
                      jumpAndBadges,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 12),
                    jumpAndBadges,
                  ],
                );
              },
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // =================================================================
          // 1. FIXED STICKY HEADER ROW (Never moves on vertical scroll!)
          // =================================================================
          Container(
            height: _headerHeight,
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              boxShadow: [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top-Left: Fixed Pinned Header (Sr & ITEM NAME)
                Container(
                  width: pinnedWidth,
                  height: _headerHeight,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(
                      right: BorderSide(color: Color(0xFF94A3B8), width: 2), // Freeze divider
                    ),
                  ),
                  child: _buildPinnedHeader(srWidth, isMobile),
                ),

                // Top-Right: Horizontally Scrollable Header (Stock In, Days 1..31, Used, Balance, Shopping)
                Expanded(
                  child: SingleChildScrollView(
                    controller: _headerHorizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: totalScrollableWidth,
                      height: _headerHeight,
                      child: _buildScrollableHeader(days),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // =================================================================
          // 2. VERTICALLY SCROLLABLE DATA BODY (Moves on vertical scroll)
          // =================================================================
          Expanded(
            child: Scrollbar(
              controller: _verticalScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _verticalScrollController,
                scrollDirection: Axis.vertical,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bottom-Left: PINNED / FROZEN LEFT ROWS (Item Name & Sr #)
                    Container(
                      width: pinnedWidth,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: const Border(
                          right: BorderSide(color: Color(0xFF94A3B8), width: 2), // Freeze divider
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(3, 0),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...filtered.asMap().entries.map((entry) {
                            return _buildPinnedRow(entry.key + 1, entry.value, isReadOnly, srWidth, isMobile);
                          }),
                        ],
                      ),
                    ),

                    // Bottom-Right: HORIZONTALLY SCROLLABLE DATA ROWS (Stock In, Days 1..31, etc.)
                    Expanded(
                      child: Scrollbar(
                        controller: _bodyHorizontalScrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _bodyHorizontalScrollController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: totalScrollableWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ...filtered.asMap().entries.map((entry) {
                                  return _buildScrollableRow(entry.key + 1, entry.value, days, isReadOnly, currentUser);
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJumpBtn(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
        ),
      ),
    );
  }

  Widget _buildKpiBadge(String label, String value, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: text.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: text)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: text)),
        ],
      ),
    );
  }

  // =========================================================================
  // PINNED / FROZEN LEFT SECTION WIDGETS
  // =========================================================================
  Widget _buildPinnedHeader(double srWidth, bool isMobile) {
    return Container(
      height: _headerHeight,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: srWidth,
            height: _headerHeight,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Color(0xFFCBD5E1))),
            ),
            child: Text(
              'Sr',
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF334155),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: _headerHeight,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10),
              alignment: Alignment.centerLeft,
              child: Text(
                'ITEM NAME',
                style: TextStyle(
                  fontSize: isMobile ? 10.5 : 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedRow(int idx, IngredientModel item, bool isReadOnly, double srWidth, bool isMobile) {
    final isOdd = idx.isOdd;
    final rowBg = isOdd ? Colors.white : const Color(0xFFF8FAFC);

    return Container(
      height: _rowHeight,
      decoration: BoxDecoration(
        color: rowBg,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          // Sr #
          Container(
            width: srWidth,
            height: _rowHeight,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Text(
              '$idx',
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          // Item Name + Category + Action Icons (Edit & Delete - only if can edit)
          Expanded(
            child: Container(
              height: _rowHeight,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: isMobile ? 11.5 : 13,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${item.category} (${item.unit})',
                          style: TextStyle(
                            fontSize: isMobile ? 9 : 10,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!isReadOnly && !widget.isArchive) ...[
                    const SizedBox(width: 4),
                    // Edit Item Button
                    IconButton(
                      icon: Icon(Icons.edit_rounded, size: isMobile ? 13 : 15, color: AppColors.textSecondary),
                      tooltip: 'Edit "${item.name}"',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showEditItemDialog(item),
                    ),
                    SizedBox(width: isMobile ? 4 : 6),
                    // Delete Item Button
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, size: isMobile ? 13 : 15, color: AppColors.error),
                      tooltip: 'Delete "${item.name}"',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showDeleteItemDialog(item),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SCROLLABLE RIGHT SECTION WIDGETS
  // =========================================================================
  Widget _buildScrollableHeader(List<int> days) {
    return Container(
      height: _headerHeight,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
        ),
      ),
      child: Row(
        children: [
          // Stock In Header (Yellow)
          Container(
            width: _stockInWidth,
            height: _headerHeight,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF08A),
              border: Border(right: BorderSide(color: Color(0xFFCBD5E1))),
            ),
            child: const Text('Stock In', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF854D0E))),
          ),
          // Days 1..31 Headers (Live calendar sync)
          ...days.map((d) {
            final now = DateTime.now();
            final daysInCurrentMonth = DateTime(now.year, now.month + 1, 0).day;
            final isToday = !widget.isArchive && d == now.day;
            final isBeyondMonth = !widget.isArchive && d > daysInCurrentMonth;

            return Tooltip(
              message: isToday
                  ? 'Aaj ($d ${DateFormat('MMMM yyyy').format(now)})'
                  : (isBeyondMonth ? 'Is mahine mein sirf $daysInCurrentMonth din hain' : 'Day $d'),
              child: Container(
                width: _dayWidth,
                height: _headerHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isToday
                      ? const Color(0xFFD1FAE5) // Soft emerald for today
                      : (isBeyondMonth ? const Color(0xFFF1F5F9) : null),
                  border: Border(
                    right: const BorderSide(color: Color(0xFFCBD5E1)),
                    bottom: isToday ? const BorderSide(color: Color(0xFF059669), width: 2.5) : BorderSide.none,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$d',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                        color: isToday
                            ? const Color(0xFF065F46)
                            : (isBeyondMonth ? const Color(0xFF94A3B8) : const Color(0xFF334155)),
                      ),
                    ),
                    if (isToday)
                      const Text(
                        'Aaj',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF059669),
                          height: 0.9,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          // Used Header (Grey)
          Container(
            width: _usedWidth,
            height: _headerHeight,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(right: BorderSide(color: Color(0xFFCBD5E1))),
            ),
            child: const Text('Used', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
          ),
          // Balance Header (Pink)
          Container(
            width: _balanceWidth,
            height: _headerHeight,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFFCE7F3),
              border: Border(right: BorderSide(color: Color(0xFFCBD5E1))),
            ),
            child: const Text('Balance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFBE185D))),
          ),
          // Shopping Details Header
          Container(
            width: _shoppingWidth,
            height: _headerHeight,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            child: const Text('Shopping Details (Re-order Qty)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableRow(int idx, IngredientModel item, List<int> days, bool isReadOnly, [UserModel? currentUser]) {
    final isOdd = idx.isOdd;
    final rowBg = isOdd ? Colors.white : const Color(0xFFF8FAFC);
    final balance = item.inHandBalance;
    final isNegative = balance < 0;
    final neededQty = item.shoppingNeededQty;

    return Container(
      height: _rowHeight,
      decoration: BoxDecoration(
        color: rowBg,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          // 1. Stock In (Yellow cell with quick + button only if can edit)
          Container(
            width: _stockInWidth,
            height: _rowHeight,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF9C3),
              border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: InkWell(
              onTap: (isReadOnly || widget.isArchive) ? null : () => _showQuickRestockDialog(item),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${item.effectiveStockIn % 1 == 0 ? item.effectiveStockIn.toInt() : item.effectiveStockIn}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF854D0E)),
                  ),
                  if (!isReadOnly && !widget.isArchive) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.add_circle, size: 15, color: Color(0xFFEAB308)),
                  ],
                ],
              ),
            ),
          ),

          // 2. Days 1 to 31 Daily Usage Cells (Staff can enter empty cells; once entered, locked for staff)
          ...days.map((day) {
            final now = DateTime.now();
            final daysInCurrentMonth = DateTime(now.year, now.month + 1, 0).day;
            final isBeyondMonth = !widget.isArchive && day > daysInCurrentMonth;

            if (isBeyondMonth) {
              return Container(
                width: _dayWidth,
                height: _rowHeight,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(
                    right: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                child: const Text('—', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
              );
            }

            final dayKey = '$day';
            final isAdmin = currentUser?.isAdmin ?? false;
            final isStaff = !isAdmin;
            final isToday = !widget.isArchive && day == now.day;
            final isPastDay = !widget.isArchive && day < now.day;

            final totalUsedOnDay = item.dailyUsageLogs?[dayKey];
            final staffUsedOnDay = isStaff
                ? item.getStaffUsageOnDay(dayKey, currentUser?.id, currentUser?.email)
                : null;
            // Staff sees their own shift entry (or empty if not entered yet); Admin sees combined total
            final usedOnDay = isStaff ? staffUsedOnDay : totalUsedOnDay;
            final hasUsage = usedOnDay != null && usedOnDay > 0;

            // Locked for staff if: not today OR (today and THIS staff member has already entered)
            final isLockedForStaff = isStaff && !widget.isArchive && (!isToday || hasUsage);

            final isShiftClosed = (currentUser != null && currentUser.isShiftRestricted && !currentUser.isWithinAllowedShift());
            final isEdited = item.isDayEdited(dayKey);
            final editReason = item.getDayEditReason(dayKey);
            final editedBy = item.getDayEditedBy(dayKey);

            final cellContent = Container(
              width: _dayWidth,
              height: _rowHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hasUsage
                    ? (isEdited
                        ? const Color(0xFFFEF3C7) // Soft Golden Amber for Edited Cells!
                        : (isLockedForStaff
                            ? const Color(0xFFF1F5F9)
                            : (isToday ? const Color(0xFFECFDF5) : const Color(0xFFE0F2FE))))
                    : (isLockedForStaff
                        ? const Color(0xFFF8FAFC)
                        : (isToday
                            ? const Color(0xFFF0FDF4)
                            : (isShiftClosed ? const Color(0xFFF8FAFC) : Colors.transparent))),
                border: Border(
                  right: BorderSide(
                    color: isEdited
                        ? const Color(0xFFF59E0B)
                        : (isToday ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                    width: (isEdited || isToday) ? 1.5 : 1.0,
                  ),
                  bottom: isEdited ? const BorderSide(color: Color(0xFFF59E0B), width: 1.5) : BorderSide.none,
                ),
              ),
              child: hasUsage
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: isEdited
                            ? const Color(0xFFFDE68A)
                            : (isLockedForStaff
                                ? const Color(0xFFE2E8F0)
                                : (isToday ? const Color(0xFFD1FAE5) : const Color(0xFFBAE6FD))),
                        borderRadius: BorderRadius.circular(4),
                        border: isEdited ? Border.all(color: const Color(0xFFD97706), width: 1) : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isEdited) ...[
                            const Icon(Icons.edit_note_rounded, size: 12, color: Color(0xFFB45309)),
                            const SizedBox(width: 1),
                          ] else if (isLockedForStaff) ...[
                            const Icon(Icons.lock_rounded, size: 9, color: Color(0xFF64748B)),
                            const SizedBox(width: 2),
                          ],
                          Text(
                            '${usedOnDay % 1 == 0 ? usedOnDay.toInt() : usedOnDay}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isEdited
                                  ? const Color(0xFF92400E) // Dark amber text for edited
                                  : (isLockedForStaff
                                      ? const Color(0xFF475569)
                                      : (isToday ? const Color(0xFF065F46) : const Color(0xFF0369A1))),
                            ),
                          ),
                        ],
                      ),
                    )
                  : (isLockedForStaff
                      ? const Icon(Icons.lock_outline_rounded, size: 11, color: Color(0xFFCBD5E1))
                      : (isToday
                          ? const Icon(Icons.add_circle_outline_rounded, size: 14, color: Color(0xFF059669))
                          : (isShiftClosed
                              ? const Icon(Icons.lock_clock_rounded, size: 11, color: Color(0xFFCBD5E1))
                              : const Icon(Icons.add_rounded, size: 11, color: Color(0xFFCBD5E1))))),
            );

            final displayVal = usedOnDay != null ? (usedOnDay % 1 == 0 ? usedOnDay.toInt() : usedOnDay) : 0;
            final shiftEntries = item.getShiftEntriesForDay(dayKey);

            String tooltipMessage = '';
            if (isAdmin) {
              if (shiftEntries.isNotEmpty || (totalUsedOnDay != null && totalUsedOnDay > 0)) {
                final buffer = StringBuffer();
                buffer.writeln('📋 Day $day Shift Breakdown (${item.name}):');
                if (shiftEntries.isNotEmpty) {
                  for (final e in shiftEntries) {
                    final sType = (e['shiftType'] ?? '').toString().toLowerCase();
                    final icon = sType.contains('morning') ? '☀️' : (sType.contains('evening') ? '🌙' : '⏱️');
                    final sName = e['userName'] ?? 'Staff';
                    final sLabel = e['shiftLabel'] ?? (sType.contains('morning') ? 'Morning Shift' : (sType.contains('evening') ? 'Evening Shift' : 'Shift'));
                    final amt = e['amount'] ?? 0;
                    final amtFormatted = (amt is num && amt % 1 == 0) ? amt.toInt() : amt;
                    buffer.writeln('$icon $sLabel ($sName): $amtFormatted ${item.unit}');
                  }
                } else if (totalUsedOnDay != null && totalUsedOnDay > 0) {
                  final tVal = totalUsedOnDay % 1 == 0 ? totalUsedOnDay.toInt() : totalUsedOnDay;
                  buffer.writeln('📦 Logged Usage: $tVal ${item.unit}');
                }
                final totalFormatted = totalUsedOnDay != null
                    ? (totalUsedOnDay % 1 == 0 ? totalUsedOnDay.toInt() : totalUsedOnDay)
                    : 0;
                buffer.writeln('────────────────────────');
                buffer.writeln('📊 Total Day Usage: $totalFormatted ${item.unit}');
                if (isEdited) {
                  buffer.writeln('✏️ Admin Edit by $editedBy: ${editReason ?? "Updated"}');
                }
                tooltipMessage = buffer.toString().trim();
              } else if (isToday) {
                tooltipMessage = 'Day $day: Abhi tak kisi staff ne entry nahi ki.';
              }
            } else {
              if (hasUsage) {
                tooltipMessage = '🔒 Aap ki entry: ${usedOnDay % 1 == 0 ? usedOnDay.toInt() : usedOnDay} ${item.unit} (Locked)';
              } else if (isToday && !isShiftClosed) {
                tooltipMessage = '➕ Click kar ke Day $day ka usage enter karein (${currentUser?.shiftDisplayLabel})';
              }
            }

            final widgetWithTooltip = tooltipMessage.isNotEmpty
                ? Tooltip(
                    message: tooltipMessage,
                    waitDuration: Duration.zero,
                    showDuration: const Duration(seconds: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isAdmin ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isAdmin ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                        width: 1.2,
                      ),
                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4))],
                    ),
                    textStyle: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4, fontWeight: FontWeight.w600),
                    child: cellContent,
                  )
                : (isEdited
                    ? Tooltip(
                        message: '✏️ Edited by $editedBy\nReason: ${editReason ?? "Updated by Admin"}\nQty: $displayVal ${item.unit}',
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF78350F),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                        ),
                        textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        child: cellContent,
                      )
                    : cellContent);

            return InkWell(
              onTap: () {
                if (widget.isArchive) {
                  _showArchiveDayDetailsDialog(item, day, usedOnDay, isEdited, editReason, editedBy);
                  return;
                }
                if (isLockedForStaff) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hasUsage
                                  ? '🔒 Day $day ka data ($displayVal) aap already enter kar chuke hain. Is ko ab sirf Admin hi update kar sakta hai.'
                                  : (isPastDay
                                      ? '🔒 Pichli Tareekh Lock Hai: Aap sirf aaj ki tareekh (${now.day}) mein entry kar saktay hain. Pichla data sirf Admin edit kar sakta hai.'
                                      : '🔒 Yeh Tareekh Abhi Aayi Nahi: Sirf aaj ki tareekh (${now.day}) mein entry ki ijazat hai.'),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF334155),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                  return;
                }
                if (isShiftClosed) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.lock_clock_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '⏰ Shift Closed: Aap ki shift (${currentUser.shiftDisplayLabel}) abhi active nahi hai. Aap sirf apni shift ke dauran entry kar sakte hain.',
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red.shade700,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                  return;
                }
                _showQuickLogUsageDialog(item, day);
              },
              child: widgetWithTooltip,
            );
          }),

          // 3. Total Used Column (Grey)
          Container(
            width: _usedWidth,
            height: _rowHeight,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Text(
              '${item.effectiveUsed % 1 == 0 ? item.effectiveUsed.toInt() : item.effectiveUsed.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
            ),
          ),

          // 4. Balance Column (Pink / Magenta, turns Red if negative deficit)
          Container(
            width: _balanceWidth,
            height: _rowHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isNegative ? const Color(0xFFFEE2E2) : const Color(0xFFFDF2F8),
              border: const Border(right: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: isNegative
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${balance % 1 == 0 ? balance.toInt() : balance.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  )
                : Text(
                    '${balance % 1 == 0 ? balance.toInt() : balance.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFDB2777)),
                  ),
          ),

          // 5. Shopping Details & 1-Click Action (Button hidden if isReadOnly)
          Container(
            width: _shoppingWidth,
            height: _rowHeight,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: neededQty > 0
                ? Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCCFBF1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF14B8A6)),
                        ),
                        child: Text(
                          'Buy: ${neededQty % 1 == 0 ? neededQty.toInt() : neededQty.toStringAsFixed(1)} ${item.unit}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F766E)),
                        ),
                      ),
                      if (!isReadOnly && !widget.isArchive) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 16, color: Color(0xFF0D9488)),
                          tooltip: 'Add to Shopping List',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => AddToShoppingDialog.show(
                            context,
                            item,
                            initialQuantity: neededQty > 0 ? neededQty.ceilToDouble() : 1.0,
                            initialReason: 'Monthly Stock Replenishment',
                          ),
                        ),
                      ],
                    ],
                  )
                : Row(
                    children: const [
                      Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                      SizedBox(width: 4),
                      Text('Sufficient', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
