import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/pdf_generator_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../dashboard/presentation/screens/main_shell.dart';
import '../../data/models/ingredient_model.dart';
import '../../providers/inventory_provider.dart';
import '../../../../core/animations/scroll_reveal.dart';

class PdfReportsArchiveScreen extends ConsumerStatefulWidget {
  const PdfReportsArchiveScreen({super.key});

  @override
  ConsumerState<PdfReportsArchiveScreen> createState() => _PdfReportsArchiveScreenState();
}

class _PdfReportsArchiveScreenState extends ConsumerState<PdfReportsArchiveScreen> {
  String _searchQuery = '';
  bool _sortAscending = false;
  final Set<String> _expandedArchiveIds = {};

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final currentUser = authState.valueOrNull;
    final isReadOnly = currentUser?.isReadOnly ?? false;

    final archivesAsync = ref.watch(monthlyArchivesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: archivesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text('Error loading saved PDF reports: $err',
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.refresh(monthlyArchivesProvider),
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
        data: (archives) {
          if (archives.isEmpty) {
            return _buildEmptyState(context);
          }

          // Sort archives by closed date
          final sorted = [...archives]..sort((a, b) {
              final aDate = a['closedAt'] != null ? DateTime.tryParse(a['closedAt']) ?? DateTime(1970) : DateTime(1970);
              final bDate = b['closedAt'] != null ? DateTime.tryParse(b['closedAt']) ?? DateTime(1970) : DateTime(1970);
              return _sortAscending ? aDate.compareTo(bDate) : bDate.compareTo(aDate);
            });

          // Search filter
          final filtered = sorted.where((arch) {
            final monthYear = (arch['monthYear'] as String? ?? '').toLowerCase();
            return monthYear.contains(_searchQuery.toLowerCase());
          }).toList();

          // Compute KPI totals across all recorded archives
          double totalStockIn = 0;
          double totalUsed = 0;
          double totalBalance = 0;
          for (final a in archives) {
            totalStockIn += (a['totalStockIn'] as num?)?.toDouble() ?? 0.0;
            totalUsed += (a['totalUsed'] as num?)?.toDouble() ?? 0.0;
            totalBalance += (a['inHandBalance'] as num?)?.toDouble() ?? 0.0;
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width < 600 ? 12 : 24,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dedicated Top Header with Action Buttons
                      _buildHeader(context, filtered.length, isReadOnly),
                      const SizedBox(height: 16),

                      // 4 Summary Metric Cards Ribbon
                      _buildSummaryKpiRow(
                        totalStatements: archives.length,
                        totalStockIn: totalStockIn,
                        totalUsed: totalUsed,
                        totalBalance: totalBalance,
                      ).scrollSlideUp(duration: const Duration(milliseconds: 600)),
                      const SizedBox(height: 16),

                      // Search & Sort Bar
                      _buildSearchAndFilterBar().scrollSlideUp(
                        duration: const Duration(milliseconds: 600),
                        delay: const Duration(milliseconds: 100),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'No statements found matching "$_searchQuery"',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width < 600 ? 12 : 24,
                  ).copyWith(bottom: 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final archive = filtered[index];
                        return _buildArchiveCard(context, archive, isReadOnly).scrollSlideUp(
                          delay: Duration(milliseconds: (index % 6) * 60),
                          duration: const Duration(milliseconds: 550),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int totalCount, bool isReadOnly) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 650;

        final titleBlock = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.2)),
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                size: 26,
                color: Color(0xFFE11D48),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Monthly Statements & PDF Archive',
                        style: TextStyle(
                          fontSize: isCompact ? 18 : 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$totalCount Saved',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE11D48),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'History of all closed monthly registers, consumption summaries, and instant PDF downloads.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        );

        final actionButtons = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
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
              ),
            IconButton.filledTonal(
              onPressed: () => ref.refresh(monthlyArchivesProvider),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Refresh Statements',
            ),
            ElevatedButton.icon(
              onPressed: () => ref.read(activeNavTabProvider.notifier).state = 2,
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              label: const Text('Go to Live Register'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: 12),
              actionButtons,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            actionButtons,
          ],
        );
      },
    );
  }

  Widget _buildSummaryKpiRow({
    required int totalStatements,
    required double totalStockIn,
    required double totalUsed,
    required double totalBalance,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        final cardWidth = isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildKpiCard(
              title: 'Archived Months',
              value: '$totalStatements',
              icon: Icons.folder_special_rounded,
              color: const Color(0xFF6366F1),
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Total Stock In',
              value: totalStockIn % 1 == 0 ? totalStockIn.toInt().toString() : totalStockIn.toStringAsFixed(1),
              icon: Icons.login_rounded,
              color: const Color(0xFFF59E0B),
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Total Consumed',
              value: totalUsed % 1 == 0 ? totalUsed.toInt().toString() : totalUsed.toStringAsFixed(1),
              icon: Icons.trending_down_rounded,
              color: const Color(0xFFEF4444),
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'In-Hand Closing',
              value: totalBalance % 1 == 0 ? totalBalance.toInt().toString() : totalBalance.toStringAsFixed(1),
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFF10B981),
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 550;

        final searchInput = Row(
          children: [
            const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search archived statements (e.g. September, 2026)...',
                  border: InputBorder.none,
                  isDense: true,
                  hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () => setState(() => _searchQuery = ''),
              ),
          ],
        );

        final sortBtn = TextButton.icon(
          onPressed: () => setState(() => _sortAscending = !_sortAscending),
          icon: Icon(
            _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 16,
            color: AppColors.textSecondary,
          ),
          label: Text(
            _sortAscending ? 'Oldest First' : 'Newest First',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        );

        if (isCompact) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                searchInput,
                const Divider(height: 1, color: AppColors.borderLight),
                Align(
                  alignment: Alignment.centerRight,
                  child: sortBtn,
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(child: searchInput),
              const VerticalDivider(width: 16, thickness: 1),
              sortBtn,
            ],
          ),
        );
      },
    );
  }

  Widget _buildArchiveCard(BuildContext context, dynamic archive, bool isReadOnly) {
    final archiveId = archive['_id']?.toString() ?? archive['id']?.toString() ?? UniqueKey().toString();
    final isExpanded = _expandedArchiveIds.contains(archiveId);

    final monthYear = archive['monthYear'] ?? 'Unknown Month';
    final closedAtStr = archive['closedAt']?.toString();
    String formattedClosed = 'Unknown Date';
    if (closedAtStr != null) {
      try {
        final parsed = DateTime.parse(closedAtStr);
        formattedClosed = DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
      } catch (_) {
        formattedClosed = closedAtStr;
      }
    }

    final totalStockIn = (archive['totalStockIn'] as num?)?.toDouble() ?? 0.0;
    final totalUsed = (archive['totalUsed'] as num?)?.toDouble() ?? 0.0;
    final inHandBalance = (archive['inHandBalance'] as num?)?.toDouble() ?? 0.0;
    final items = (archive['items'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Column(
        children: [
          // Main Card Row
          Padding(
            padding: const EdgeInsets.all(18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 750;

                final leftSection = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Color(0xFFE11D48),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                monthYear,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: const Text(
                                  'Archived & Saved',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Closed on $formattedClosed',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.inventory_2_outlined, size: 14, color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${items.length} items logged',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final pillsSection = Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildPill(
                      label: 'Stock In',
                      value: totalStockIn % 1 == 0 ? totalStockIn.toInt().toString() : totalStockIn.toStringAsFixed(1),
                      bg: const Color(0xFFFEF08A),
                      textColor: const Color(0xFF854D0E),
                    ),
                    _buildPill(
                      label: 'Total Used',
                      value: totalUsed % 1 == 0 ? totalUsed.toInt().toString() : totalUsed.toStringAsFixed(1),
                      bg: const Color(0xFFF1F5F9),
                      textColor: const Color(0xFF334155),
                    ),
                    _buildPill(
                      label: 'Balance',
                      value: inHandBalance % 1 == 0 ? inHandBalance.toInt().toString() : inHandBalance.toStringAsFixed(1),
                      bg: const Color(0xFFFCE7F3),
                      textColor: const Color(0xFFBE185D),
                    ),
                  ],
                );

                final actionButtons = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedArchiveIds.remove(archiveId);
                          } else {
                            _expandedArchiveIds.add(archiveId);
                          }
                        });
                      },
                      icon: Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                      ),
                      label: Text(isExpanded ? 'Hide Details' : 'View Details'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        side: const BorderSide(color: AppColors.border),
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _downloadArchivePdf(context, archive),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Download PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                    if (!isReadOnly)
                      IconButton(
                        tooltip: 'Delete Archived Statement',
                        style: IconButton.styleFrom(
                          foregroundColor: AppColors.error,
                          backgroundColor: const Color(0xFFFEF2F2),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.all(10),
                        ),
                        onPressed: () => _confirmDeleteArchive(context, archiveId, monthYear),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      ),
                  ],
                );

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(child: leftSection),
                      pillsSection,
                      const SizedBox(width: 16),
                      actionButtons,
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leftSection,
                    const SizedBox(height: 12),
                    pillsSection,
                    const SizedBox(height: 12),
                    actionButtons,
                  ],
                );
              },
            ),
          ),

          // Collapsible Items Breakdown Table
          if (isExpanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Container(
              color: AppColors.background,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Archived Items & Consumption Breakdown',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        headingTextStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                        dataTextStyle: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        columns: const [
                          DataColumn(label: Text('Sr')),
                          DataColumn(label: Text('Item Name')),
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Stock In')),
                          DataColumn(label: Text('Total Used')),
                          DataColumn(label: Text('In-Hand Balance')),
                          DataColumn(label: Text('Unit')),
                        ],
                        rows: List.generate(items.length, (idx) {
                          final item = items[idx];
                          final name = item['name'] ?? '';
                          final cat = item['category'] ?? 'Other';
                          final stock = (item['stockIn'] as num?)?.toDouble() ?? 0.0;
                          final used = (item['totalUsed'] as num?)?.toDouble() ?? 0.0;
                          final bal = (item['balance'] as num?)?.toDouble() ?? (stock - used);
                          final unit = item['unit'] ?? '';

                          return DataRow(
                            cells: [
                              DataCell(Text('${idx + 1}')),
                              DataCell(Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(Text(cat)),
                              DataCell(Text(stock % 1 == 0 ? stock.toInt().toString() : stock.toStringAsFixed(1))),
                              DataCell(Text(used % 1 == 0 ? used.toInt().toString() : used.toStringAsFixed(1))),
                              DataCell(
                                Text(
                                  bal % 1 == 0 ? bal.toInt().toString() : bal.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: bal <= 0 ? AppColors.error : AppColors.primaryDark,
                                  ),
                                ),
                              ),
                              DataCell(Text(unit)),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPill({
    required String label,
    required String value,
    required Color bg,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 48,
                  color: Color(0xFFE11D48),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Archived PDF Statements Yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Whenever you complete a month in "Expense Detail" and click "Done (Close Month)", your official monthly PDF report and stock balance statement will automatically be saved and displayed here forever.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.read(activeNavTabProvider.notifier).state = 2,
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text('Go to Live Stock Register'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadArchivePdf(BuildContext context, dynamic archive) async {
    try {
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF statement for $monthYear ready for print/download!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
}
