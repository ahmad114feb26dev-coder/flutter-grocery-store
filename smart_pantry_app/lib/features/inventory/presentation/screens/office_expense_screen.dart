import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/pdf_generator_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../shopping_list/providers/shopping_list_provider.dart';
import '../../data/models/ingredient_model.dart';
import '../../providers/inventory_provider.dart';
import '../widgets/monthly_stock_register_sheet.dart';

class OfficeExpenseScreen extends ConsumerStatefulWidget {
  const OfficeExpenseScreen({super.key});

  @override
  ConsumerState<OfficeExpenseScreen> createState() => _OfficeExpenseScreenState();
}

class _OfficeExpenseScreenState extends ConsumerState<OfficeExpenseScreen> {
  int _activeTab = 0; // 0: Live Register, 1: Archived Reports & PDF History
  String? _selectedArchiveId; // null = Live Current Month, otherwise archived month ID
  late final ScrollController _mobilePageScrollController = ScrollController();

  @override
  void dispose() {
    _mobilePageScrollController.dispose();
    super.dispose();
  }

  void _scrollToSheet() {
    if (_mobilePageScrollController.hasClients) {
      _mobilePageScrollController.animateTo(
        _mobilePageScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _scrollToTop() {
    if (_mobilePageScrollController.hasClients) {
      _mobilePageScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final currentUser = authState.valueOrNull;
    final isReadOnly = currentUser?.isReadOnly ?? false;

    final inventoryAsync = ref.watch(inventoryControllerProvider);
    final archivesAsync = ref.watch(monthlyArchivesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: inventoryAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                const SizedBox(height: 12),
                Text('Error loading expense details: $err',
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.refresh(inventoryControllerProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          data: (items) {
            final archives = archivesAsync.valueOrNull ?? [];
            final selectedArchive = _selectedArchiveId != null
                ? archives.firstWhere(
                    (a) => (a['_id']?.toString() ?? a['id']?.toString()) == _selectedArchiveId,
                    orElse: () => null,
                  )
                : null;

            final bool isArchiveMode = selectedArchive != null;
            final String? archiveMonthYear = isArchiveMode ? (selectedArchive['monthYear'] as String? ?? 'Archived Month') : null;

            final List<IngredientModel> archiveItems = isArchiveMode
                ? (selectedArchive['items'] as List<dynamic>? ?? []).map((raw) {
                    return IngredientModel(
                      id: raw['_id']?.toString() ?? raw['id']?.toString(),
                      name: raw['name'] ?? '',
                      category: raw['category'] ?? 'Other',
                      unit: raw['unit'] ?? 'pcs',
                      quantity: (raw['balance'] as num?)?.toDouble() ?? 0.0,
                      stockIn: (raw['stockIn'] as num?)?.toDouble() ?? 0.0,
                      totalUsed: (raw['totalUsed'] as num?)?.toDouble() ?? 0.0,
                      dailyUsageLogs: raw['dailyUsageLogs'] is Map
                          ? (raw['dailyUsageLogs'] as Map).map(
                              (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
                            )
                          : null,
                      dailyUsageEdits: raw['dailyUsageEdits'] is Map
                          ? (raw['dailyUsageEdits'] as Map).map(
                              (k, v) => MapEntry(k.toString(), v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{}),
                            )
                          : null,
                      shiftUsageLogs: raw['shiftUsageLogs'] is Map
                          ? Map<String, dynamic>.from(raw['shiftUsageLogs'] as Map)
                          : null,
                      expiryDate: DateTime.now(),
                    );
                  }).toList()
                : [];

            double totalStockIn = 0;
            double totalUsed = 0;
            double inHandBalance = 0;
            int deficitCount = 0;
            int neededCount = 0;

            if (isArchiveMode) {
              totalStockIn = (selectedArchive['totalStockIn'] as num?)?.toDouble() ?? 0.0;
              totalUsed = (selectedArchive['totalUsed'] as num?)?.toDouble() ?? 0.0;
              inHandBalance = (selectedArchive['inHandBalance'] as num?)?.toDouble() ?? 0.0;
              for (final item in archiveItems) {
                if (item.inHandBalance < 0) deficitCount++;
                if (item.shoppingNeededQty > 0) neededCount++;
              }
            } else {
              for (final item in items) {
                totalStockIn += item.effectiveStockIn;
                totalUsed += item.effectiveUsed;
                inHandBalance += item.inHandBalance;
                if (item.inHandBalance < 0) deficitCount++;
                if (item.shoppingNeededQty > 0) neededCount++;
              }
            }

            final isWideScreen = MediaQuery.of(context).size.width >= 800;
            final isNarrow = MediaQuery.of(context).size.width < 500;

            if (isWideScreen) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dedicated Top Header with Navigation Tabs
                    _buildTopHeader(
                      context,
                      ref,
                      isArchiveMode ? archiveItems : items,
                      isArchiveMode ? 0 : neededCount,
                      isWideScreen,
                      isReadOnly,
                      isArchiveMode,
                      archiveMonthYear,
                    ),
                    const SizedBox(height: 14),

                    // Section Tab Switcher & Month Picker: Live Register vs Archived Reports vs Calendar
                    _buildSectionSwitcher(archives, isNarrow, isWideScreen),
                    const SizedBox(height: 14),

                    if (_activeTab == 0) ...[
                      // KPI Summary Ribbon
                      _buildKpiRibbon(
                        totalStockIn: totalStockIn,
                        totalUsed: totalUsed,
                        inHandBalance: inHandBalance,
                        deficitCount: deficitCount,
                        neededCount: neededCount,
                        isWideScreen: isWideScreen,
                        isArchiveMode: isArchiveMode,
                        archiveMonthYear: archiveMonthYear,
                      ),
                      const SizedBox(height: 14),

                      // The Main Interactive Excel Spreadsheet Table
                      Expanded(
                        child: (isArchiveMode ? archiveItems : items).isEmpty
                            ? _buildEmptyState(context)
                            : MonthlyStockRegisterSheet(
                                items: isArchiveMode ? archiveItems : items,
                                isArchive: isArchiveMode,
                                monthLabel: archiveMonthYear,
                                archiveData: selectedArchive,
                                onSwitchToLive: () {
                                  setState(() {
                                    _selectedArchiveId = null;
                                  });
                                },
                                onOpenCalendar: () {
                                  _showMonthPickerModal(context, archives);
                                },
                              ),
                      ),
                    ] else ...[
                      // Archived Reports & PDF History View
                      Expanded(
                        child: _buildArchivedReportsView(archivesAsync, isReadOnly),
                      ),
                    ],
                  ],
                ),
              );
            }

            // Mobile & Narrow Screens: Smooth vertical scrolling so the sheet can slide up into full view
            return SingleChildScrollView(
              controller: _mobilePageScrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 600 ? 10 : 16,
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dedicated Top Header with Navigation Tabs
                  _buildTopHeader(
                    context,
                    ref,
                    isArchiveMode ? archiveItems : items,
                    isArchiveMode ? 0 : neededCount,
                    isWideScreen,
                    isReadOnly,
                    isArchiveMode,
                    archiveMonthYear,
                  ),
                  const SizedBox(height: 12),

                  // Section Tab Switcher & Month Picker + Quick Jump Pill
                  _buildSectionSwitcher(archives, isNarrow, isWideScreen),
                  const SizedBox(height: 12),

                  if (_activeTab == 0) ...[
                    // KPI Summary Ribbon
                    _buildKpiRibbon(
                      totalStockIn: totalStockIn,
                      totalUsed: totalUsed,
                      inHandBalance: inHandBalance,
                      deficitCount: deficitCount,
                      neededCount: neededCount,
                      isWideScreen: isWideScreen,
                      isArchiveMode: isArchiveMode,
                      archiveMonthYear: archiveMonthYear,
                    ),
                    const SizedBox(height: 14),

                    // The Main Interactive Excel Spreadsheet Table with generous bounded height on mobile
                    SizedBox(
                      height: max(640.0, MediaQuery.of(context).size.height - 70),
                      child: (isArchiveMode ? archiveItems : items).isEmpty
                          ? _buildEmptyState(context)
                          : MonthlyStockRegisterSheet(
                              items: isArchiveMode ? archiveItems : items,
                              isArchive: isArchiveMode,
                              monthLabel: archiveMonthYear,
                              archiveData: selectedArchive,
                              onSwitchToLive: () {
                                setState(() {
                                  _selectedArchiveId = null;
                                });
                              },
                              onOpenCalendar: () {
                                _showMonthPickerModal(context, archives);
                              },
                              onScrollToTop: _scrollToTop,
                            ),
                    ),
                  ] else ...[
                    // Archived Reports & PDF History View
                    SizedBox(
                      height: max(550.0, MediaQuery.of(context).size.height - 120),
                      child: _buildArchivedReportsView(archivesAsync, isReadOnly),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionSwitcher(List<dynamic> archives, [bool isNarrow = false, bool isWideScreen = true]) {
    final isArchiveSelected = _selectedArchiveId != null;
    final selectedArchive = isArchiveSelected
        ? archives.firstWhere(
            (a) => (a['_id']?.toString() ?? a['id']?.toString()) == _selectedArchiveId,
            orElse: () => null,
          )
        : null;
    final selectedMonthLabel = selectedArchive != null
        ? (selectedArchive['monthYear'] as String? ?? 'Archived Month')
        : 'Current Month (Live)';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTabBtn(isNarrow ? 'Live Register' : 'Live Stock Register', 0, Icons.table_chart_rounded),
                const SizedBox(width: 6),
                _buildTabBtn(isNarrow ? 'Archived & PDFs' : 'Archived Reports & PDF History', 1, Icons.history_edu_rounded),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Calendar / Month Selection Pill Button
          InkWell(
            onTap: () => _showMonthPickerModal(context, archives),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isArchiveSelected ? const Color(0xFFFEF3C7) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isArchiveSelected ? const Color(0xFFF59E0B) : AppColors.border,
                  width: isArchiveSelected ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: isArchiveSelected ? const Color(0xFFD97706) : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isArchiveSelected ? '📅 $selectedMonthLabel' : '📅 Live: ${DateFormat('MMMM yyyy').format(DateTime.now())}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isArchiveSelected ? const Color(0xFF92400E) : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (isArchiveSelected) ...[
                    InkWell(
                      onTap: () => setState(() => _selectedArchiveId = null),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFDE68A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF78350F)),
                      ),
                    ),
                  ] else ...[
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
                  ],
                ],
              ),
            ),
          ),

          // Quick Jump to Sheet button for mobile view
          if (!isWideScreen && _activeTab == 0) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: _scrollToSheet,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_downward_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Sheet ⬇️',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBtn(String label, int tabIndex, IconData icon) {
    final isSelected = _activeTab == tabIndex;
    return InkWell(
      onTap: () => setState(() => _activeTab = tabIndex),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFEF08A) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: const Color(0xFFFACC15)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFF854D0E) : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFF854D0E) : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchivedReportsView(AsyncValue<List<dynamic>> archivesAsync, bool isReadOnly) {
    return archivesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (err, stack) => Center(
        child: Text('Error loading archives: $err', style: const TextStyle(color: AppColors.error)),
      ),
      data: (archives) {
        if (archives.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.picture_as_pdf_outlined, size: 54, color: Color(0xFFD97706)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Closed Monthly Reports Yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Jab aap Live Register mein "Done (Close Month)" dabayenge, to is mahine ka complete PDF snapshot yahan archive ho jayega.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: archives.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final arch = archives[index];
            final monthYear = arch['monthYear'] as String? ?? 'Closed Month';
            final totalStockIn = (arch['totalStockIn'] as num?)?.toDouble() ?? 0.0;
            final totalUsed = (arch['totalUsed'] as num?)?.toDouble() ?? 0.0;
            final inHandBal = (arch['inHandBalance'] as num?)?.toDouble() ?? 0.0;
            final closedAtRaw = arch['closedAt'] as String?;
            final closedDate = closedAtRaw != null ? DateTime.tryParse(closedAtRaw) : null;
            final formattedDate = closedDate != null
                ? DateFormat('dd MMM yyyy, hh:mm a').format(closedDate)
                : 'Recent';

            final itemsList = (arch['items'] as List<dynamic>? ?? []).map((raw) {
              return IngredientModel(
                name: raw['name'] ?? '',
                category: raw['category'] ?? 'Other',
                unit: raw['unit'] ?? 'pcs',
                quantity: (raw['balance'] as num?)?.toDouble() ?? 0.0,
                stockIn: (raw['stockIn'] as num?)?.toDouble() ?? 0.0,
                totalUsed: (raw['totalUsed'] as num?)?.toDouble() ?? 0.0,
                dailyUsageLogs: (raw['dailyUsageLogs'] as Map<String, dynamic>?)?.map(
                  (k, v) => MapEntry(k, (v as num).toDouble()),
                ),
                shiftUsageLogs: raw['shiftUsageLogs'] is Map
                    ? Map<String, dynamic>.from(raw['shiftUsageLogs'] as Map)
                    : null,
                expiryDate: DateTime.now(),
              );
            }).toList();

            return LayoutBuilder(
              builder: (context, cardConstraints) {
                final isCardCompact = cardConstraints.maxWidth < 650;

                final actions = Row(
                  mainAxisSize: isCardCompact ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    if (isCardCompact)
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFEF08A),
                                  foregroundColor: const Color(0xFF854D0E),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: const BorderSide(color: Color(0xFFFACC15)),
                                  ),
                                ),
                                icon: const Icon(Icons.table_chart_rounded, size: 14, color: Color(0xFF854D0E)),
                                label: const Text('Sheet Dekhein 📊', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
                                onPressed: () {
                                  final archiveId = arch['_id']?.toString() ?? arch['id']?.toString();
                                  if (archiveId != null) {
                                    setState(() {
                                      _selectedArchiveId = archiveId;
                                      _activeTab = 0;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF047857),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.download_rounded, size: 14),
                                label: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                                onPressed: () async {
                                  await PdfGeneratorService.generateAndDownloadPdf(
                                    monthYear: monthYear,
                                    items: itemsList,
                                    totalStockIn: totalStockIn,
                                    totalUsed: totalUsed,
                                    inHandBalance: inHandBal,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEF08A),
                          foregroundColor: const Color(0xFF854D0E),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFFACC15)),
                          ),
                        ),
                        icon: const Icon(Icons.table_chart_rounded, size: 16, color: Color(0xFF854D0E)),
                        label: const Text('Sheet Mein Dekhein 📊', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        onPressed: () {
                          final archiveId = arch['_id']?.toString() ?? arch['id']?.toString();
                          if (archiveId != null) {
                            setState(() {
                              _selectedArchiveId = archiveId;
                              _activeTab = 0;
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.w700)),
                        onPressed: () async {
                          await PdfGeneratorService.generateAndDownloadPdf(
                            monthYear: monthYear,
                            items: itemsList,
                            totalStockIn: totalStockIn,
                            totalUsed: totalUsed,
                            inHandBalance: inHandBal,
                          );
                        },
                      ),
                    ],
                    if (!isReadOnly) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Delete Report',
                        style: IconButton.styleFrom(
                          foregroundColor: AppColors.error,
                          backgroundColor: const Color(0xFFFEF2F2),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.all(10),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        onPressed: () {
                          final archiveId = arch['_id']?.toString() ?? arch['id']?.toString();
                          if (archiveId != null) {
                            _confirmDeleteArchive(context, archiveId, monthYear);
                          }
                        },
                      ),
                    ],
                  ],
                );

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: isCardCompact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFD97706), size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            monthYear,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFD1FAE5),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('Archived Record', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF047857))),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Closed on: $formattedDate  •  ${itemsList.length} Items Recorded',
                                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text('Stock In: ${totalStockIn.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
                                Text('•', style: TextStyle(color: AppColors.textMuted)),
                                Text('Total Used: ${totalUsed.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                                Text('•', style: TextStyle(color: AppColors.textMuted)),
                                Text('Closing Balance: ${inHandBal.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFDB2777))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            actions,
                          ],
                        )
                      : Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFD97706), size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        monthYear,
                                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD1FAE5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('Archived Record', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF047857))),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Closed on: $formattedDate  •  ${itemsList.length} Items Recorded',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 10,
                                    children: [
                                      Text('Stock In: ${totalStockIn.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
                                      Text('•', style: TextStyle(color: AppColors.textMuted)),
                                      Text('Total Used: ${totalUsed.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                                      Text('•', style: TextStyle(color: AppColors.textMuted)),
                                      Text('Closing Balance: ${inHandBal.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDB2777))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            actions,
                          ],
                        ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _confirmDeleteArchive(BuildContext context, String archiveId, String monthYear) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('Delete Statement?'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete the archived statement for "$monthYear"?\n\nThis action cannot be undone.',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref.read(inventoryControllerProvider.notifier).deleteMonthlyArchive(archiveId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Archived statement for "$monthYear" deleted.'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete statement: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete Statement'),
          ),
        ],
      ),
    );
  }

  void _showMonthPickerModal(BuildContext context, List<dynamic> archives) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        final screenHeight = MediaQuery.of(context).size.height;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Modal Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Modal Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.calendar_month_rounded, color: Color(0xFFD97706), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Select Register Month (Mahina Chunain)',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Current live month ya kisi bhi pichlay mahine ki sheet register dekhnay ke liye select karein.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Scrollable Body
                  Flexible(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      shrinkWrap: true,
                      children: [
                        // Option 1: Live Current Month
                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedArchiveId = null;
                              _activeTab = 0;
                            });
                            Navigator.pop(modalCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Switched to Live Current Month Register'),
                                backgroundColor: Color(0xFF047857),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _selectedArchiveId == null ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _selectedArchiveId == null ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                                width: _selectedArchiveId == null ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _selectedArchiveId == null ? const Color(0xFF10B981) : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF10B981)),
                                  ),
                                  child: Icon(
                                    Icons.table_chart_rounded,
                                    size: 20,
                                    color: _selectedArchiveId == null ? Colors.white : const Color(0xFF047857),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Current Month (Live: ${DateFormat('MMMM yyyy').format(DateTime.now())})',
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFD1FAE5),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('Active Now', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF047857))),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Laptop Live Calendar: Aaj ${DateFormat('dd MMMM yyyy').format(DateTime.now())} hai • Live daily entries',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_selectedArchiveId == null)
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Section Title: Past Closed Months
                        Row(
                          children: [
                            const Icon(Icons.history_edu_rounded, size: 18, color: Color(0xFFB45309)),
                            const SizedBox(width: 8),
                            const Text(
                              'Pichlay Mahinay (Closed Historic Archives)',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF78350F)),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${archives.length} Mahinay',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (archives.isEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Column(
                              children: const [
                                Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 30),
                                SizedBox(height: 8),
                                Text(
                                  'Abhi koi closed month archive nahi hua',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Mahina khatam hone par jab admin "Done (Close Month)" karega, to us mahine ki complete sheet yahan pichlay record ke tor par mehfooz ho jayegi.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: Color(0xFFB45309), height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          ...archives.map((arch) {
                            final archId = arch['_id']?.toString() ?? arch['id']?.toString();
                            final monthYear = arch['monthYear'] as String? ?? 'Closed Month';
                            final totalStockIn = (arch['totalStockIn'] as num?)?.toDouble() ?? 0.0;
                            final totalUsed = (arch['totalUsed'] as num?)?.toDouble() ?? 0.0;
                            final inHandBal = (arch['inHandBalance'] as num?)?.toDouble() ?? 0.0;
                            final itemsCount = (arch['items'] as List?)?.length ?? 0;
                            final isSelected = _selectedArchiveId == archId;

                            final closedAtRaw = arch['closedAt'] as String?;
                            final closedDate = closedAtRaw != null ? DateTime.tryParse(closedAtRaw) : null;
                            final formattedDate = closedDate != null
                                ? DateFormat('dd MMM yyyy, hh:mm a').format(closedDate)
                                : 'Recent';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedArchiveId = archId;
                                    _activeTab = 0; // Switch to register sheet!
                                  });
                                  Navigator.pop(modalCtx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('📅 Showing sheet register for "$monthYear" (Read-Only)'),
                                      backgroundColor: const Color(0xFFB45309),
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFFFFBEB) : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.02),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.calendar_today_rounded,
                                          size: 20,
                                          color: isSelected ? Colors.white : const Color(0xFFD97706),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  monthYear,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFEF3C7),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    'Archived',
                                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Closed: $formattedDate  •  $itemsCount Items Recorded',
                                              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 4,
                                              children: [
                                                Text('Stock In: ${totalStockIn.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
                                                Text('•', style: TextStyle(color: AppColors.textMuted)),
                                                Text('Used: ${totalUsed.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                                                Text('•', style: TextStyle(color: AppColors.textMuted)),
                                                Text('Balance: ${inHandBal.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDB2777))),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(Icons.check_circle_rounded, color: Color(0xFFF59E0B), size: 24)
                                      else
                                        const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],

                        const SizedBox(height: 16),

                        // Option 3: Pick From Calendar (Date Picker)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4338CA),
                            side: const BorderSide(color: Color(0xFF818CF8), width: 1.5),
                            backgroundColor: const Color(0xFFEEF2FF),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            final now = DateTime.now();
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: now,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                              helpText: 'Select Month to View Register',
                            );
                            if (pickedDate != null) {
                              final formattedTarget = DateFormat('MMMM yyyy').format(pickedDate).toLowerCase();
                              final matchedArchive = archives.firstWhere(
                                (a) {
                                  final m = (a['monthYear'] as String? ?? '').toLowerCase();
                                  return m.contains(formattedTarget) || formattedTarget.contains(m);
                                },
                                orElse: () => null,
                              );

                              if (matchedArchive != null) {
                                final archId = matchedArchive['_id']?.toString() ?? matchedArchive['id']?.toString();
                                setState(() {
                                  _selectedArchiveId = archId;
                                  _activeTab = 0;
                                });
                                if (modalCtx.mounted) Navigator.pop(modalCtx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('📅 Opened sheet for "${matchedArchive['monthYear']}"!'),
                                      backgroundColor: const Color(0xFFB45309),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Calendar: "${DateFormat('MMMM yyyy').format(pickedDate)}" ka koi closed record nahi mila. Sirf "Done (Close Month)" kiye gaye mahino ka record moojood hota hai.',
                                      ),
                                      backgroundColor: Colors.indigo.shade800,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.date_range_rounded, size: 20),
                          label: const Text(
                            'Calendar Sy Mahina Chunain (Pick from Calendar)',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopHeader(
    BuildContext context,
    WidgetRef ref,
    List<dynamic> items,
    int neededCount,
    bool isWideScreen,
    bool isReadOnly, [
    bool isArchiveMode = false,
    String? archiveMonthYear,
  ]) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 650;

        final badgeOrAction = isArchiveMode
            ? ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedArchiveId = null;
                  });
                },
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Live Current Month', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              )
            : (isReadOnly
                ? Container(
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
                : (neededCount > 0 && isWideScreen
                    ? ElevatedButton.icon(
                        onPressed: () async {
                          int addedCount = 0;
                          for (final item in items) {
                            if (item.shoppingNeededQty > 0) {
                              await ref.read(shoppingListControllerProvider.notifier).addItem(
                                item.name,
                                item.shoppingNeededQty.ceilToDouble(),
                                'Office stock replenishment',
                              );
                              addedCount++;
                            }
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added $addedCount recommended items to Shopping List!'),
                                backgroundColor: AppColors.primaryDark,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                        label: Text(
                          'Auto-Add $neededCount to Shopping',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE11D48),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                      )
                    : null));

        final titleAndSubtitle = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Office Expense Detail',
                  style: TextStyle(
                    fontSize: isWideScreen ? 20 : 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isArchiveMode ? const Color(0xFFFEF3C7) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isArchiveMode ? const Color(0xFFF59E0B) : const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    isArchiveMode ? 'Archived Record ($archiveMonthYear)' : 'Monthly Stock Register',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isArchiveMode ? const Color(0xFF92400E) : const Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isArchiveMode
                  ? 'Viewing historic closed statement for "$archiveMonthYear" (Read-Only Snapshot)'
                  : 'Daily consumption (Days 1–31), stock-in accumulation & smart balance calculations',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ],
        );

        final iconWidget = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
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
            size: 24,
          ),
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        iconWidget,
                        const SizedBox(width: 12),
                        Expanded(child: titleAndSubtitle),
                      ],
                    ),
                    if (badgeOrAction != null) ...[
                      const SizedBox(height: 10),
                      badgeOrAction,
                    ],
                  ],
                )
              : Row(
                  children: [
                    iconWidget,
                    const SizedBox(width: 14),
                    Expanded(child: titleAndSubtitle),
                    if (badgeOrAction != null) ...[
                      const SizedBox(width: 14),
                      badgeOrAction,
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _buildKpiRibbon({
    required double totalStockIn,
    required double totalUsed,
    required double inHandBalance,
    required int deficitCount,
    required int neededCount,
    required bool isWideScreen,
    bool isArchiveMode = false,
    String? archiveMonthYear,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 650;

        final card1 = _buildMetricCard(
          title: 'Total Stock In',
          value: totalStockIn % 1 == 0 ? totalStockIn.toInt().toString() : totalStockIn.toStringAsFixed(1),
          subtitle: isArchiveMode ? 'Accumulated ($archiveMonthYear)' : 'Accumulated arrivals',
          color: const Color(0xFFF59E0B),
          bgColor: const Color(0xFFFEF3C7),
          icon: Icons.inventory_rounded,
        );

        final card2 = _buildMetricCard(
          title: 'Total Used (Month)',
          value: totalUsed % 1 == 0 ? totalUsed.toInt().toString() : totalUsed.toStringAsFixed(1),
          subtitle: isArchiveMode ? 'Consumed ($archiveMonthYear)' : 'Consumed 1-31',
          color: const Color(0xFF6366F1),
          bgColor: const Color(0xFFEEF2FF),
          icon: Icons.trending_down_rounded,
        );

        final card3 = _buildMetricCard(
          title: 'In-Hand Balance',
          value: inHandBalance % 1 == 0 ? inHandBalance.toInt().toString() : inHandBalance.toStringAsFixed(1),
          subtitle: isArchiveMode
              ? 'Closing balance'
              : (deficitCount > 0 ? '$deficitCount Deficit items!' : 'Remaining stock'),
          color: deficitCount > 0 ? const Color(0xFFDC2626) : const Color(0xFFDB2777),
          bgColor: deficitCount > 0 ? const Color(0xFFFEE2E2) : const Color(0xFFFCE7F3),
          icon: deficitCount > 0 ? Icons.warning_amber_rounded : Icons.account_balance_wallet_rounded,
        );

        final card4 = isArchiveMode
            ? _buildMetricCard(
                title: 'Register Status',
                value: 'Archived',
                subtitle: '$archiveMonthYear record',
                color: const Color(0xFF047857),
                bgColor: const Color(0xFFD1FAE5),
                icon: Icons.history_edu_rounded,
              )
            : _buildMetricCard(
                title: 'Shopping Needed',
                value: '$neededCount items',
                subtitle: 'Next order cycle',
                color: const Color(0xFF0D9488),
                bgColor: const Color(0xFFCCFBF1),
                icon: Icons.shopping_basket_rounded,
              );

        if (isCompact) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 10),
                  Expanded(child: card2),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: card3),
                  const SizedBox(width: 10),
                  Expanded(child: card4),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: card1),
            const SizedBox(width: 12),
            Expanded(child: card2),
            const SizedBox(width: 12),
            Expanded(child: card3),
            if (isWideScreen || neededCount > 0 || isArchiveMode) ...[
              const SizedBox(width: 12),
              Expanded(child: card4),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.table_chart_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text(
            'No items in Office Expense register yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add pantry or office grocery items to start tracking daily usage and monthly balance.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => context.push('/inventory/add'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add First Item'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
