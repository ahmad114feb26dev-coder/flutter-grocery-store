import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:smart_pantry_app/core/constants/app_colors.dart';
import 'package:smart_pantry_app/features/inventory/data/models/ingredient_model.dart';

class PantryAnalyticsCharts extends StatefulWidget {
  final List<IngredientModel> items;

  const PantryAnalyticsCharts({super.key, required this.items});

  @override
  State<PantryAnalyticsCharts> createState() => _PantryAnalyticsChartsState();
}

class _PantryAnalyticsChartsState extends State<PantryAnalyticsCharts> {
  int _touchedPieIndex = -1;
  int _touchedBarGroupIndex = -1;
  int _selectedViewTab = 0; // 0: Overview (Donut + Bar), 1: Freshness Timeline

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with View Selector
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.insights_rounded,
                          size: 18,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Pantry Analytics & Charts',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Visual overview of your stock health, alarm triggers, and category breakdown',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  // Full-width Toggle Tab Chips for Mobile
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _buildTabBtn('Stock & Categories', 0, Icons.pie_chart_outline_rounded)),
                        const SizedBox(width: 4),
                        Expanded(child: _buildTabBtn('Freshness', 1, Icons.timelapse_rounded)),
                      ],
                    ),
                  ),
                ],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.insights_rounded,
                              size: 18,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Pantry Analytics & Charts',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Visual overview of your stock health, alarm triggers, and category breakdown',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Toggle Tab Chips for Desktop
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
                      _buildTabBtn('Stock & Categories', 0, Icons.pie_chart_outline_rounded),
                      const SizedBox(width: 4),
                      _buildTabBtn('Freshness', 1, Icons.timelapse_rounded),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        // Main Charts Layout
        if (_selectedViewTab == 0) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 860;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildStockStatusDonutCard(context),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 6,
                      child: _buildCategoryBarCard(context),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildStockStatusDonutCard(context),
                    const SizedBox(height: 16),
                    _buildCategoryBarCard(context),
                  ],
                );
              }
            },
          ),
        ] else ...[
          _buildFreshnessTimelineCard(context),
        ],
      ],
    );
  }

  Widget _buildTabBtn(String label, int tabIndex, IconData icon) {
    final isSelected = _selectedViewTab == tabIndex;
    return InkWell(
      onTap: () => setState(() => _selectedViewTab = tabIndex),
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
            Icon(
              icon,
              size: 15,
              color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
            ),
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

  // ==========================================
  // 1. Stock Status Donut Chart Card
  // ==========================================
  Widget _buildStockStatusDonutCard(BuildContext context) {
    int outOfStock = 0;
    int lowStock = 0;
    int moderate = 0;
    int sufficient = 0;

    for (final item in widget.items) {
      final qty = item.quantity;
      final threshold = item.lowStockThreshold ?? 3.0;
      if (qty <= 0) {
        outOfStock++;
      } else if (qty <= threshold) {
        lowStock++;
      } else if (qty <= threshold + 2) {
        moderate++;
      } else {
        sufficient++;
      }
    }

    final total = widget.items.length;
    final healthScore = total > 0 ? ((sufficient + moderate * 0.7) / total * 100).round() : 100;

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Stock Level Health',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Distribution based on your custom alarm limits',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: healthScore >= 70
                      ? const Color(0xFFECFDF5)
                      : healthScore >= 40
                          ? const Color(0xFFFFFBEB)
                          : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: healthScore >= 70
                        ? const Color(0xFFA7F3D0)
                        : healthScore >= 40
                            ? const Color(0xFFFDE68A)
                            : const Color(0xFFFCA5A5),
                  ),
                ),
                child: Text(
                  '$healthScore% Healthy',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: healthScore >= 70
                        ? const Color(0xFF059669)
                        : healthScore >= 40
                            ? const Color(0xFFD97706)
                            : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Donut Chart with Center Label
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        final newIndex = (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null)
                            ? -1
                            : pieTouchResponse.touchedSection!.touchedSectionIndex;
                        if (newIndex != _touchedPieIndex) {
                          setState(() => _touchedPieIndex = newIndex);
                        }
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 3,
                    centerSpaceRadius: 52,
                    sections: [
                      // Sufficient
                      _buildPieSection(
                        value: sufficient.toDouble(),
                        total: total,
                        color: const Color(0xFF10B981),
                        isSelected: _touchedPieIndex == 0,
                      ),
                      // Moderate
                      _buildPieSection(
                        value: moderate.toDouble(),
                        total: total,
                        color: const Color(0xFFF59E0B),
                        isSelected: _touchedPieIndex == 1,
                      ),
                      // Low Stock
                      _buildPieSection(
                        value: lowStock.toDouble(),
                        total: total,
                        color: const Color(0xFFEF4444),
                        isSelected: _touchedPieIndex == 2,
                      ),
                      // Out of stock
                      _buildPieSection(
                        value: outOfStock.toDouble(),
                        total: total,
                        color: const Color(0xFF94A3B8),
                        isSelected: _touchedPieIndex == 3,
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    const Text(
                      'TOTAL ITEMS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Legend grid below donut
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildDonutLegendItem('🟢 Sufficient', sufficient, total, const Color(0xFF10B981)),
              _buildDonutLegendItem('🟡 Moderate', moderate, total, const Color(0xFFF59E0B)),
              _buildDonutLegendItem('🔴 Low Stock', lowStock, total, const Color(0xFFEF4444)),
              _buildDonutLegendItem('⚪ Out of Stock', outOfStock, total, const Color(0xFF94A3B8)),
            ],
          ),
        ],
      ),
    );
  }

  PieChartSectionData _buildPieSection({
    required double value,
    required int total,
    required Color color,
    required bool isSelected,
  }) {
    if (value <= 0) {
      return PieChartSectionData(
        value: 0,
        color: Colors.transparent,
        radius: 0,
        showTitle: false,
      );
    }

    final percentage = (value / total * 100).round();
    final radius = isSelected ? 36.0 : 28.0;

    return PieChartSectionData(
      value: value,
      color: color,
      radius: radius,
      title: '$percentage%',
      titleStyle: TextStyle(
        fontSize: isSelected ? 12 : 10,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    );
  }

  Widget _buildDonutLegendItem(String label, int count, int total, Color color) {
    final pct = total > 0 ? (count / total * 100).round() : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 4),
          Text(
            '$count ($pct%)',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. Category Distribution Bar Chart Card
  // ==========================================
  Widget _buildCategoryBarCard(BuildContext context) {
    final Map<String, int> categoryCounts = {
      'Produce': 0,
      'Dairy': 0,
      'Meat': 0,
      'Bakery': 0,
      'Pantry': 0,
      'Spices': 0,
      'Other': 0,
    };

    for (final item in widget.items) {
      final cat = item.category;
      if (categoryCounts.containsKey(cat)) {
        categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
      } else {
        categoryCounts['Other'] = (categoryCounts['Other'] ?? 0) + 1;
      }
    }

    final categories = categoryCounts.keys.toList();
    final maxCount = categoryCounts.values.fold<int>(0, (max, val) => val > max ? val : max);
    final maxY = (maxCount + 2).toDouble();

    final categoryColors = {
      'Produce': const Color(0xFF10B981),
      'Dairy': const Color(0xFF3B82F6),
      'Meat': const Color(0xFFEF4444),
      'Bakery': const Color(0xFFF59E0B),
      'Pantry': const Color(0xFF8B5CF6),
      'Spices': const Color(0xFFF97316),
      'Other': const Color(0xFF64748B),
    };

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Inventory by Category',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Item count distributed across food groups',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.category_rounded, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${categories.where((c) => (categoryCounts[c] ?? 0) > 0).length} Active Categories',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bar Chart
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    final newIndex = (!event.isInterestedForInteractions ||
                            barTouchResponse == null ||
                            barTouchResponse.spot == null)
                        ? -1
                        : barTouchResponse.spot!.touchedBarGroupIndex;
                    if (newIndex != _touchedBarGroupIndex) {
                      setState(() => _touchedBarGroupIndex = newIndex);
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => const Color(0xFF1E293B),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final catName = categories[groupIndex];
                      final count = rod.toY.round();
                      return BarTooltipItem(
                        '$catName\n',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: '$count item${count == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: Color(0xFF93C5FD),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: maxCount > 8 ? 2 : 1,
                      getTitlesWidget: (val, meta) {
                        if (val % 1 != 0 || val < 0) return const SizedBox.shrink();
                        return Text(
                          '${val.toInt()}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (val, meta) {
                        final index = val.toInt();
                        if (index < 0 || index >= categories.length) return const SizedBox.shrink();
                        final name = categories[index];
                        // Short 3-letter label
                        final shortName = name.length > 4 ? name.substring(0, 3) : name;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            shortName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _touchedBarGroupIndex == index ? FontWeight.w800 : FontWeight.w600,
                              color: _touchedBarGroupIndex == index ? AppColors.primaryDark : AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxCount > 8 ? 2 : 1,
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.6),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(categories.length, (i) {
                  final cat = categories[i];
                  final count = (categoryCounts[cat] ?? 0).toDouble();
                  final color = categoryColors[cat] ?? AppColors.primary;
                  final isHovered = _touchedBarGroupIndex == i;

                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: count,
                        color: color,
                        width: isHovered ? 18 : 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: AppColors.surfaceMuted.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Micro badge pills for active categories
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: categories.where((c) => (categoryCounts[c] ?? 0) > 0).map((cat) {
              final color = categoryColors[cat] ?? AppColors.primary;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(
                      '$cat: ${categoryCounts[cat]}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. Freshness Timeline Card
  // ==========================================
  Widget _buildFreshnessTimelineCard(BuildContext context) {
    int expired = 0;
    int critical = 0; // <= 3 days
    int soon = 0; // 4 - 7 days
    int fresh = 0; // > 7 days

    for (final item in widget.items) {
      final days = item.daysLeft ?? 99;
      if (days <= 0) {
        expired++;
      } else if (days <= 3) {
        critical++;
      } else if (days <= 7) {
        soon++;
      } else {
        fresh++;
      }
    }

    final total = widget.items.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pantry Freshness Timeline',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Breakdown of items based on expiration countdown',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Horizontal segmented progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 24,
              child: Row(
                children: [
                  if (fresh > 0)
                    Expanded(
                      flex: fresh,
                      child: Container(
                        color: const Color(0xFF10B981),
                        child: Center(
                          child: total > 0 && (fresh / total) >= 0.16
                              ? Text(
                                  '$fresh Fresh',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  if (soon > 0)
                    Expanded(
                      flex: soon,
                      child: Container(
                        color: const Color(0xFF3B82F6),
                        child: Center(
                          child: total > 0 && (soon / total) >= 0.16
                              ? Text(
                                  '$soon Normal',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  if (critical > 0)
                    Expanded(
                      flex: critical,
                      child: Container(
                        color: const Color(0xFFF59E0B),
                        child: Center(
                          child: total > 0 && (critical / total) >= 0.16
                              ? Text(
                                  '$critical Soon',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  if (expired > 0)
                    Expanded(
                      flex: expired,
                      child: Container(
                        color: const Color(0xFFEF4444),
                        child: Center(
                          child: total > 0 && (expired / total) >= 0.16
                              ? Text(
                                  '$expired Expired',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 4 Freshness Stat Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isWide ? 2.0 : (constraints.maxWidth < 400 ? 1.9 : 2.1),
                children: [
                  _buildFreshnessStatCard(
                    'Fresh (> 7 days)',
                    '$fresh',
                    total > 0 ? '${(fresh / total * 100).round()}%' : '0%',
                    const Color(0xFF10B981),
                    const Color(0xFFECFDF5),
                  ),
                  _buildFreshnessStatCard(
                    'Soon (4 - 7 days)',
                    '$soon',
                    total > 0 ? '${(soon / total * 100).round()}%' : '0%',
                    const Color(0xFF3B82F6),
                    const Color(0xFFEFF6FF),
                  ),
                  _buildFreshnessStatCard(
                    'Critical (1 - 3 days)',
                    '$critical',
                    total > 0 ? '${(critical / total * 100).round()}%' : '0%',
                    const Color(0xFFF59E0B),
                    const Color(0xFFFFFBEB),
                  ),
                  _buildFreshnessStatCard(
                    'Expired',
                    '$expired',
                    total > 0 ? '${(expired / total * 100).round()}%' : '0%',
                    const Color(0xFFEF4444),
                    const Color(0xFFFEF2F2),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFreshnessStatCard(
    String label,
    String count,
    String percentage,
    Color color,
    Color bg,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                count,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                percentage,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
