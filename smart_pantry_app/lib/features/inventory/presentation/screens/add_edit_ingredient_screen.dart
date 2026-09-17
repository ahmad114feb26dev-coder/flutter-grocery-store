import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_pantry_app/core/constants/app_colors.dart';
import 'package:smart_pantry_app/core/utils/validators.dart';
import 'package:smart_pantry_app/features/inventory/data/models/ingredient_model.dart';
import 'package:smart_pantry_app/features/inventory/providers/inventory_provider.dart';

class AddEditIngredientScreen extends ConsumerStatefulWidget {
  final String? ingredientId;

  const AddEditIngredientScreen({super.key, this.ingredientId});

  @override
  ConsumerState<AddEditIngredientScreen> createState() => _AddEditIngredientScreenState();
}

class _AddEditIngredientScreenState extends ConsumerState<AddEditIngredientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _dailyUsageController = TextEditingController();
  final _lowStockThresholdController = TextEditingController(text: '3');
  String _selectedUnit = 'pcs';
  String _consumptionUnit = 'pcs';
  String _selectedCategory = 'Produce';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  bool _isLoading = false;
  String _consumptionFrequency = 'Daily'; // 'Daily', 'Weekly', 'Monthly'

  final List<String> _categories = [
    'Produce',
    'Dairy',
    'Meat',
    'Bakery',
    'Pantry',
    'Spices',
    'Other',
  ];

  final List<String> _units = [
    'pcs',
    'kg',
    'g',
    'L',
    'ml',
    'can',
    'jar',
    'loaf',
    'bottle',
  ];

  final List<Map<String, dynamic>> _quickPresets = [
    {'name': 'Greek Yogurt', 'cat': 'Dairy', 'qty': '500', 'unit': 'g', 'daily': '100', 'days': 5},
    {'name': 'Basmati Rice', 'cat': 'Pantry', 'qty': '5', 'unit': 'kg', 'daily': '0.5', 'days': 10},
    {'name': 'Fresh Milk', 'cat': 'Dairy', 'qty': '3', 'unit': 'L', 'daily': '1', 'days': 3},
    {'name': 'Whole Wheat Bread', 'cat': 'Bakery', 'qty': '1', 'unit': 'loaf', 'daily': '0.25', 'days': 4},
    {'name': 'Chicken Breast', 'cat': 'Meat', 'qty': '2', 'unit': 'kg', 'daily': '0.5', 'days': 4},
    {'name': 'Red Apples', 'cat': 'Produce', 'qty': '10', 'unit': 'pcs', 'daily': '2', 'days': 5},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.ingredientId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadExistingItem();
      });
    }
    _quantityController.addListener(() => setState(() {}));
    _dailyUsageController.addListener(() => setState(() {}));
  }

  void _loadExistingItem() {
    final items = ref.read(inventoryControllerProvider).valueOrNull ?? [];
    final match = items.where((e) => e.id == widget.ingredientId).firstOrNull;
    if (match != null) {
      setState(() {
        _nameController.text = match.name;
        _quantityController.text = '${match.quantity % 1 == 0 ? match.quantity.toInt() : match.quantity}';
        if (match.dailyUsage != null && match.dailyUsage! > 0) {
          _dailyUsageController.text = '${match.dailyUsage! % 1 == 0 ? match.dailyUsage!.toInt() : match.dailyUsage}';
        }
        if (match.lowStockThreshold != null) {
          _lowStockThresholdController.text = '${match.lowStockThreshold! % 1 == 0 ? match.lowStockThreshold!.toInt() : match.lowStockThreshold}';
        }
        _selectedUnit = _units.contains(match.unit) ? match.unit : 'pcs';
        _consumptionUnit = _selectedUnit;
        _selectedCategory = _categories.contains(match.category) ? match.category : 'Other';
        _selectedDate = match.expiryDate;
      });
    }
  }

  void _simulateBarcodeScan() {
    final random = Random();
    final sample = _quickPresets[random.nextInt(_quickPresets.length)];
    setState(() {
      _nameController.text = sample['name'];
      _selectedCategory = sample['cat'];
      _quantityController.text = sample['qty'];
      _dailyUsageController.text = sample['daily'];
      _selectedUnit = sample['unit'];
      _consumptionUnit = sample['unit'];
      _selectedDate = DateTime.now().add(Duration(days: sample['days']));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('Barcode Scanned: ${sample['name']} detected!'),
          ],
        ),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
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
        _selectedDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final qty = double.tryParse(_quantityController.text.trim()) ?? 1.0;
    final enteredUsage = double.tryParse(_dailyUsageController.text.trim());
    final threshold = double.tryParse(_lowStockThresholdController.text.trim()) ?? 3.0;
    double? normalizedDailyRate;
    if (enteredUsage != null && enteredUsage > 0) {
      double rate = enteredUsage;
      if (_consumptionFrequency == 'Weekly') {
        rate = enteredUsage / 7.0;
      } else if (_consumptionFrequency == 'Monthly') {
        rate = enteredUsage / 30.0;
      }

      // Convert units if consumption unit differs from main product unit
      if (_selectedUnit == 'kg' && _consumptionUnit == 'g') {
        rate = rate / 1000.0;
      } else if (_selectedUnit == 'g' && _consumptionUnit == 'kg') {
        rate = rate * 1000.0;
      } else if (_selectedUnit == 'L' && _consumptionUnit == 'ml') {
        rate = rate / 1000.0;
      } else if (_selectedUnit == 'ml' && _consumptionUnit == 'L') {
        rate = rate * 1000.0;
      } else if (_selectedUnit == 'pcs' && (_consumptionUnit == 'kg' || _consumptionUnit == 'g' || _consumptionUnit == 'L')) {
        _selectedUnit = _consumptionUnit;
      }
      normalizedDailyRate = rate;
    }
    final diffDays = _selectedDate.difference(DateTime.now()).inDays;

    try {
      if (widget.ingredientId == null) {
        // Add new item to MongoDB
        final newItem = IngredientModel(
          name: name,
          category: _selectedCategory,
          quantity: qty,
          unit: _selectedUnit,
          expiryDate: _selectedDate,
          daysLeft: diffDays,
          dailyUsage: normalizedDailyRate,
          lowStockThreshold: threshold,
        );

        await ref.read(inventoryControllerProvider.notifier).addIngredient(newItem);
      } else {
        // Edit existing item in MongoDB
        await ref.read(inventoryControllerProvider.notifier).updateIngredient(
          widget.ingredientId!,
          {
            'name': name,
            'category': _selectedCategory,
            'quantity': qty,
            'unit': _selectedUnit,
            'expiryDate': _selectedDate.toIso8601String(),
            'dailyUsage': normalizedDailyRate,
            'lowStockThreshold': threshold,
          },
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.ingredientId == null ? 'Added "$name" to Pantry & MongoDB!' : 'Updated "$name" in MongoDB!'),
            backgroundColor: AppColors.primaryDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving to database: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _dailyUsageController.dispose();
    _lowStockThresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.ingredientId != null;
    final daysUntilExpiry = _selectedDate.difference(DateTime.now()).inDays;

    final qtyVal = double.tryParse(_quantityController.text.trim()) ?? 0;
    final enteredUsage = double.tryParse(_dailyUsageController.text.trim()) ?? 0;
    final hasUsage = enteredUsage > 0 && qtyVal > 0;
    double calculatedDaysLast = 0.0;
    if (hasUsage) {
      double rate = enteredUsage;
      if (_consumptionFrequency == 'Weekly') {
        rate = enteredUsage / 7.0;
      } else if (_consumptionFrequency == 'Monthly') {
        rate = enteredUsage / 30.0;
      }
      if (_selectedUnit == 'kg' && _consumptionUnit == 'g') {
        rate = rate / 1000.0;
      } else if (_selectedUnit == 'g' && _consumptionUnit == 'kg') {
        rate = rate * 1000.0;
      } else if (_selectedUnit == 'L' && _consumptionUnit == 'ml') {
        rate = rate / 1000.0;
      } else if (_selectedUnit == 'ml' && _consumptionUnit == 'L') {
        rate = rate * 1000.0;
      }
      if (rate > 0) {
        calculatedDaysLast = qtyVal / rate;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Ingredient' : 'Add New Grocery Item'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Barcode scan simulation banner
                  if (!isEdit) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.1),
                            AppColors.primaryLight.withValues(alpha: 0.4),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Smart Barcode Scanner',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Instantly recognize grocery packaging & fill item details.',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _simulateBarcodeScan,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            child: const Text('Simulate Scan'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Form Container
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Item Name Field
                        const Text(
                          'Ingredient Name',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Whole Milk, Avocados, Basmati Rice',
                            prefixIcon: Icon(Icons.shopping_bag_outlined, color: AppColors.textSecondary),
                          ),
                          validator: (v) => Validators.validateRequired(v, 'Ingredient name'),
                        ),
                        const SizedBox(height: 20),

                        // Category Dropdown
                        const Text(
                          'Food Category',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              AppColors.getCategoryIcon(_selectedCategory),
                              color: AppColors.getCategoryColor(_selectedCategory),
                            ),
                          ),
                          items: _categories.map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Row(
                                children: [
                                  Icon(
                                    AppColors.getCategoryIcon(cat),
                                    size: 18,
                                    color: AppColors.getCategoryColor(cat),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(cat),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                        ),
                        const SizedBox(height: 20),

                        // Total Quantity and Unit Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total Quantity',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _quantityController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      hintText: '1',
                                      prefixIcon: Icon(Icons.format_list_numbered_rounded, color: AppColors.textSecondary),
                                    ),
                                    validator: (v) => Validators.validateRequired(v, 'Quantity'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Unit',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    key: ValueKey(_selectedUnit),
                                    initialValue: _selectedUnit,
                                    items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedUnit = val;
                                          _consumptionUnit = val;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Quick Unit Choice Chips for fast 1-tap selection (kg, g, pcs, L, etc.)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: ['kg', 'g', 'pcs', 'L', 'ml', 'can', 'bottle'].map((u) {
                            final isSel = _selectedUnit == u;
                            return ChoiceChip(
                              label: Text(
                                u == 'kg'
                                    ? '⚖️ kg'
                                    : u == 'g'
                                        ? '⚖️ g'
                                        : u == 'pcs'
                                            ? '🔢 pcs'
                                            : u == 'L'
                                                ? '🥛 L'
                                                : u == 'ml'
                                                    ? '🥛 ml'
                                                    : u,
                              ),
                              selected: isSel,
                              selectedColor: const Color(0xFFDCFCE7),
                              backgroundColor: AppColors.surfaceMuted,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                color: isSel ? const Color(0xFF15803D) : AppColors.textSecondary,
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedUnit = u;
                                    _consumptionUnit = u;
                                  });
                                }
                              },
                            );
                          }).toList(),
                        ),
                        if (!isEdit) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF9C3),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFDE047)),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF854D0E)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Agar yeh item pehle se enter hai, to naya stock usi item mein add (accumulate) ho jayega.',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF854D0E)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Consumption Rate & Frequency (OPTIONAL)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.speed_rounded, size: 18, color: AppColors.secondary),
                                const SizedBox(width: 8),
                                const Text(
                                  'Consumption Rate',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Optional',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                            // Frequency & Unit Selectors
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Frequency Dropdown (Daily, Weekly, Monthly)
                                Container(
                                  height: 34,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _consumptionFrequency,
                                      isDense: true,
                                      borderRadius: BorderRadius.circular(10),
                                      icon: const Icon(Icons.arrow_drop_down_rounded, size: 20, color: AppColors.textPrimary),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'Daily',
                                          child: Text('📅 Daily (Rozana)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Weekly',
                                          child: Text('🗓️ Weekly (Hafta)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Monthly',
                                          child: Text('📆 Monthly (Mahana)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _consumptionFrequency = val);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Consumption Unit Dropdown (kg, g, pcs, L, ml)
                                Container(
                                  height: 34,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: (_selectedUnit == 'kg' || _consumptionUnit == 'kg')
                                          ? (_consumptionUnit == 'g' ? 'g' : 'kg')
                                          : (_selectedUnit == 'L' || _consumptionUnit == 'L')
                                              ? (_consumptionUnit == 'ml' ? 'ml' : 'L')
                                              : _consumptionUnit,
                                      isDense: true,
                                      borderRadius: BorderRadius.circular(10),
                                      icon: const Icon(Icons.arrow_drop_down_rounded, size: 20, color: Color(0xFFB45309)),
                                      items: ['kg', 'g', 'pcs', 'L', 'ml', 'can', 'bottle']
                                          .map((u) => DropdownMenuItem(
                                                value: u,
                                                child: Text(
                                                  u == 'kg'
                                                      ? '⚖️ kg'
                                                      : u == 'g'
                                                          ? '⚖️ gram (g)'
                                                          : u == 'pcs'
                                                              ? '🔢 pcs'
                                                              : u == 'L'
                                                                  ? '🥛 Liter (L)'
                                                                  : u == 'ml'
                                                                      ? '🥛 ml'
                                                                      : u,
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                                                ),
                                              ))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _consumptionUnit = val;
                                            if (_selectedUnit == 'pcs' && (val == 'kg' || val == 'g')) {
                                              _selectedUnit = 'kg';
                                            }
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _consumptionFrequency == 'Daily'
                              ? 'Rozana kitna $_consumptionUnit use hota hai? (e.g. 0.5 kg, 1 kg, ya 250 g)'
                              : _consumptionFrequency == 'Weekly'
                                  ? 'Har hafte kitna $_consumptionUnit use hota hai? (Weekly hisab)'
                                  : 'Har mahine kitna $_consumptionUnit use hota hai? (Mahana hisab)',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),

                        // Quick Preset Chips for Consumption
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: (_consumptionUnit == 'kg'
                              ? [
                                  {'label': '0.25 kg (250g)', 'val': '0.25'},
                                  {'label': '0.5 kg (Aadha kg)', 'val': '0.5'},
                                  {'label': '1 kg', 'val': '1'},
                                  {'label': '2 kg', 'val': '2'},
                                ]
                              : _consumptionUnit == 'g'
                                  ? [
                                      {'label': '100 g', 'val': '100'},
                                      {'label': '250 g', 'val': '250'},
                                      {'label': '500 g (Aadha kg)', 'val': '500'},
                                    ]
                                  : _consumptionUnit == 'L'
                                      ? [
                                          {'label': '0.25 L (250ml)', 'val': '0.25'},
                                          {'label': '0.5 L (Aadha L)', 'val': '0.5'},
                                          {'label': '1 L', 'val': '1'},
                                          {'label': '2 L', 'val': '2'},
                                        ]
                                      : [
                                          {'label': '0.5 pcs', 'val': '0.5'},
                                          {'label': '1 pcs', 'val': '1'},
                                          {'label': '2 pcs', 'val': '2'},
                                          {'label': '3 pcs', 'val': '3'},
                                          {'label': '5 pcs', 'val': '5'},
                                        ]).map((preset) {
                            final isSel = _dailyUsageController.text.trim() == preset['val'];
                            return ActionChip(
                              label: Text(preset['label']!),
                              backgroundColor: isSel ? const Color(0xFFFEF3C7) : AppColors.surfaceMuted,
                              side: BorderSide(color: isSel ? const Color(0xFFF59E0B) : AppColors.border),
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                color: isSel ? const Color(0xFFB45309) : AppColors.textPrimary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _dailyUsageController.text = preset['val']!;
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),

                        TextFormField(
                          controller: _dailyUsageController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: _consumptionFrequency == 'Daily'
                                ? 'e.g. ${_consumptionUnit == "kg" ? "0.5 (kitne kg rozana)" : _consumptionUnit == "g" ? "250 (kitne gram rozana)" : "0.5 (kitne $_consumptionUnit rozana)"}'
                                : _consumptionFrequency == 'Weekly'
                                    ? 'e.g. ${_consumptionUnit == "kg" ? "2 (kitne kg har hafte)" : "2 (kitne $_consumptionUnit har hafte)"}'
                                    : 'e.g. ${_consumptionUnit == "kg" ? "5 (kitne kg har mahine)" : "5 (kitne $_consumptionUnit har mahine)"}',
                            prefixIcon: const Icon(Icons.speed_rounded, color: AppColors.secondary),
                            suffixText: '$_consumptionUnit / ${_consumptionFrequency == "Daily" ? "day" : _consumptionFrequency == "Weekly" ? "week" : "month"}',
                            suffixStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                          ),
                        ),

                        // Dynamic calculation card if consumption rate entered
                        if (hasUsage) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.calculate_rounded, color: Color(0xFFB45309), size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        () {
                                          final daysStr = calculatedDaysLast >= 1 ? '${calculatedDaysLast.round()}' : calculatedDaysLast.toStringAsFixed(1);
                                          String extra = '';
                                          if (calculatedDaysLast >= 60) {
                                            extra = ' (~${(calculatedDaysLast / 30).toStringAsFixed(1)} mahine)';
                                          } else if (calculatedDaysLast >= 14) {
                                            extra = ' (~${(calculatedDaysLast / 7).toStringAsFixed(1)} hafte)';
                                          }
                                          return 'Stock Duration: ~$daysStr din chalega$extra';
                                        }(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  () {
                                    final freqLabel = _consumptionFrequency == 'Daily'
                                        ? 'Daily $enteredUsage $_consumptionUnit'
                                        : _consumptionFrequency == 'Weekly'
                                            ? 'Weekly $enteredUsage $_consumptionUnit'
                                            : 'Monthly $enteredUsage $_consumptionUnit';
                                    final formattedQty = qtyVal % 1 == 0 ? qtyVal.toInt() : qtyVal;
                                    String conversionNote = '';
                                    if (_selectedUnit == 'kg' && _consumptionUnit == 'g') {
                                      conversionNote = ' ($enteredUsage g = ${(enteredUsage / 1000).toStringAsFixed(2)} kg)';
                                    } else if (_selectedUnit == 'L' && _consumptionUnit == 'ml') {
                                      conversionNote = ' ($enteredUsage ml = ${(enteredUsage / 1000).toStringAsFixed(2)} L)';
                                    }
                                    return '$freqLabel$conversionNote ke hisab se $formattedQty $_selectedUnit taqreeban ${calculatedDaysLast.round()} din chalega.';
                                  }(),
                                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () {
                                    final days = max(1, calculatedDaysLast.round());
                                    setState(() {
                                      _selectedDate = DateTime.now().add(Duration(days: days));
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Expiration date updated to $days din from now!'),
                                        backgroundColor: AppColors.primaryDark,
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFB45309).withValues(alpha: 0.5)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.auto_fix_high_rounded, size: 14, color: Color(0xFFB45309)),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Auto-set Expiration Date to this duration (~${max(1, calculatedDaysLast.round())} din)',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFB45309),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        // Low Stock Alarm Threshold (Customizable)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.notifications_active_rounded, size: 18, color: Color(0xFFD97706)),
                                SizedBox(width: 8),
                                Text(
                                  'Low Stock Alarm Threshold',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: const Text(
                                'Alarm Trigger',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kitni $_selectedUnit se kam ya barabar ho to har 2 ghante baad low stock ka alarm bajy?',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [1.0, 2.0, 3.0, 5.0, 10.0].map((val) {
                            final valStr = '${val % 1 == 0 ? val.toInt() : val}';
                            final isSelected = _lowStockThresholdController.text.trim() == valStr;
                            return ChoiceChip(
                              label: Text('$valStr $_selectedUnit'),
                              selected: isSelected,
                              selectedColor: const Color(0xFFFEF3C7),
                              backgroundColor: AppColors.surfaceMuted,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? const Color(0xFFB45309) : AppColors.textSecondary,
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _lowStockThresholdController.text = valStr;
                                  });
                                }
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _lowStockThresholdController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: 'e.g. 3 (kitne $_selectedUnit reh jayein to alarm bajy)',
                            prefixIcon: const Icon(Icons.alarm_on_rounded, color: Color(0xFFD97706)),
                            suffixText: _selectedUnit,
                            suffixStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Expiry Date Picker Card
                        const Text(
                          'Expiration Date',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        daysUntilExpiry <= 0
                                            ? 'Expires today or past!'
                                            : 'Expires in $daysUntilExpiry days',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: daysUntilExpiry <= 3 ? AppColors.error : AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.edit_calendar_rounded, size: 20, color: AppColors.textMuted),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            isEdit ? 'Save Changes' : 'Add to Pantry',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
