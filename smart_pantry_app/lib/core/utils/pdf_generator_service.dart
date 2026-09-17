import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'url_launcher_helper.dart';
import '../../features/inventory/data/models/ingredient_model.dart';
import '../../features/shopping_list/data/models/shopping_list_item_model.dart';

class PdfGeneratorService {
  static Future<void> generateAndDownloadPdf({
    required String monthYear,
    required List<IngredientModel> items,
    double? totalStockIn,
    double? totalUsed,
    double? inHandBalance,
  }) async {
    final pdf = pw.Document();

    final computedStockIn = totalStockIn ?? items.fold<double>(0, (s, e) => s + e.effectiveStockIn);
    final computedUsed = totalUsed ?? items.fold<double>(0, (s, e) => s + e.effectiveUsed);
    final computedBalance = inHandBalance ?? items.fold<double>(0, (s, e) => s + e.inHandBalance);
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    // Page 1: Landscape table matching Excel register
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            // Report Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Office Expense Detail & Monthly Stock Register',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#854D0E'),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Month: $monthYear  |  Generated on: $formattedDate',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
                // KPI Summary Badges
                pw.Row(
                  children: [
                    _buildPdfKpi('Stock In', computedStockIn, PdfColor.fromHex('#FEF08A'), PdfColor.fromHex('#854D0E')),
                    pw.SizedBox(width: 8),
                    _buildPdfKpi('Total Used', computedUsed, PdfColor.fromHex('#F1F5F9'), PdfColor.fromHex('#334155')),
                    pw.SizedBox(width: 8),
                    _buildPdfKpi('In-Hand Balance', computedBalance, PdfColor.fromHex('#FCE7F3'), PdfColor.fromHex('#BE185D')),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // Table
            _buildPdfTable(items),
          ];
        },
        footer: (pw.Context context) {
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Smart Pantry Office Management System', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          );
        },
      ),
    );

    // Trigger printing layout / download on web and mobile
    final sanitizedMonth = monthYear.replaceAll(RegExp(r'[^\w\s]+'), '_').replaceAll(' ', '_');
    await Printing.layoutPdf(
      name: 'Office_Expense_$sanitizedMonth.pdf',
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  static pw.Widget _buildPdfKpi(String label, double value, PdfColor bg, PdfColor text) {
    final strVal = value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('$label: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: text)),
          pw.Text(strVal, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: text)),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfTable(List<IngredientModel> items) {
    const daysCount = 31;
    final List<int> days = List.generate(daysCount, (i) => i + 1);

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(22), // Sr
        1: const pw.FixedColumnWidth(110), // Item Name
        2: const pw.FixedColumnWidth(40), // Stock In
        for (int i = 0; i < daysCount; i++) i + 3: const pw.FixedColumnWidth(16), // Days 1-31
        34: const pw.FixedColumnWidth(38), // Used
        35: const pw.FixedColumnWidth(42), // Balance
      },
      children: [
        // Header Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _buildPdfHeaderCell('Sr'),
            _buildPdfHeaderCell('ITEM NAME', align: pw.TextAlign.left),
            _buildPdfHeaderCell('Stock In', bg: PdfColor.fromHex('#FEF08A'), textColor: PdfColor.fromHex('#854D0E')),
            ...days.map((d) => _buildPdfHeaderCell('$d')),
            _buildPdfHeaderCell('Used', bg: PdfColor.fromHex('#F1F5F9'), textColor: PdfColor.fromHex('#334155')),
            _buildPdfHeaderCell('Balance', bg: PdfColor.fromHex('#FCE7F3'), textColor: PdfColor.fromHex('#BE185D')),
          ],
        ),
        // Data Rows
        ...items.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final item = entry.value;
          final bal = item.inHandBalance;
          final isNegative = bal < 0;
          final rowBg = idx.isOdd ? PdfColors.white : PdfColor.fromHex('#F8FAFC');

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: rowBg),
            children: [
              // Sr
              _buildPdfDataCell('$idx', align: pw.TextAlign.center),
              // Item Name
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(item.name, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${item.category} (${item.unit})', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                  ],
                ),
              ),
              // Stock In
              _buildPdfDataCell(
                item.effectiveStockIn % 1 == 0 ? item.effectiveStockIn.toInt().toString() : item.effectiveStockIn.toStringAsFixed(1),
                bg: PdfColor.fromHex('#FEF9C3'),
                textColor: PdfColor.fromHex('#854D0E'),
                isBold: true,
              ),
              // Days 1-31
              ...days.map((d) {
                final dayVal = item.dailyUsageLogs?['$d'];
                final hasUsage = dayVal != null && dayVal > 0;
                final text = hasUsage ? (dayVal % 1 == 0 ? dayVal.toInt().toString() : dayVal.toString()) : '';
                return _buildPdfDataCell(
                  text,
                  bg: hasUsage ? PdfColor.fromHex('#E0F2FE') : null,
                  textColor: PdfColor.fromHex('#0369A1'),
                  isBold: hasUsage,
                  fontSize: 6.5,
                );
              }),
              // Total Used
              _buildPdfDataCell(
                item.effectiveUsed % 1 == 0 ? item.effectiveUsed.toInt().toString() : item.effectiveUsed.toStringAsFixed(1),
                bg: PdfColor.fromHex('#F1F5F9'),
                textColor: PdfColor.fromHex('#334155'),
                isBold: true,
              ),
              // Balance
              _buildPdfDataCell(
                bal % 1 == 0 ? bal.toInt().toString() : bal.toStringAsFixed(1),
                bg: isNegative ? PdfColor.fromHex('#FEE2E2') : PdfColor.fromHex('#FDF2F8'),
                textColor: isNegative ? PdfColor.fromHex('#DC2626') : PdfColor.fromHex('#DB2777'),
                isBold: true,
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildPdfHeaderCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.center,
    PdfColor? bg,
    PdfColor? textColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      color: bg,
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          color: textColor ?? PdfColors.grey900,
        ),
      ),
    );
  }

  static pw.Widget _buildPdfDataCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.center,
    PdfColor? bg,
    PdfColor? textColor,
    bool isBold = false,
    double fontSize = 7.5,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      color: bg,
      alignment: align == pw.TextAlign.center ? pw.Alignment.center : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor ?? PdfColors.grey900,
        ),
      ),
    );
  }

  /// Builds the pw.Document for a Shopping Cart / Trip
  static pw.Document buildShoppingListDocument({
    required int tripNum,
    required List<ShoppingListItemModel> items,
    required bool isFrozen,
    String? monthYear,
  }) {
    final pdf = pw.Document();

    // Preserve exact sequence of addition (oldest createdAt first -> #1, #2, #3...)
    final ordered = List<ShoppingListItemModel>.from(items);
    ordered.sort((a, b) {
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

    final totalQty = ordered.fold<double>(0.0, (s, e) => s + e.quantityNeeded);
    final formattedTotalQty = totalQty % 1 == 0 ? totalQty.toInt().toString() : totalQty.toStringAsFixed(1);
    final boughtCount = ordered.where((e) => e.resolved).length;
    final toBuyCount = ordered.where((e) => !e.resolved).length;
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        build: (pw.Context context) {
          return [
            // Top Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SMART PANTRY INVENTORY SYSTEM',
                      style: pw.TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Shopping List #$tripNum Report',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex(isFrozen ? '#1E293B' : '#14532D'),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Generated: $formattedDate • ${ordered.length} Products in Sequence of Addition',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                    ),
                  ],
                ),
                // Status Badge
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex(isFrozen ? '#1E293B' : '#15803D'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Text(
                    isFrozen ? 'FINALIZED LIST 🔒' : 'ACTIVE SHOPPING LIST 🛒',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // KPI Summary Row
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildSummaryBox(
                    label: 'TOTAL PRODUCTS',
                    value: '${ordered.length}',
                    bg: PdfColor.fromHex('#F1F5F9'),
                    text: PdfColor.fromHex('#1E293B'),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildSummaryBox(
                    label: 'TOTAL QUANTITY',
                    value: formattedTotalQty,
                    bg: PdfColor.fromHex('#F0FDF4'),
                    text: PdfColor.fromHex('#15803D'),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildSummaryBox(
                    label: 'BOUGHT',
                    value: '$boughtCount items',
                    bg: PdfColor.fromHex('#DCFCE7'),
                    text: PdfColor.fromHex('#166534'),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildSummaryBox(
                    label: 'PENDING TO BUY',
                    value: '$toBuyCount items',
                    bg: PdfColor.fromHex('#FEF3C7'),
                    text: PdfColor.fromHex('#92400E'),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Products Table in exact sequence
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.8),
              columnWidths: {
                0: const pw.FixedColumnWidth(36), // Sr #
                1: const pw.FlexColumnWidth(3),   // Item Name (one side)
                2: const pw.FixedColumnWidth(85), // Status (Bought / To Buy)
                3: const pw.FixedColumnWidth(75), // Quantity (other side)
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex(isFrozen ? '#1E293B' : '#14532D'),
                  ),
                  children: [
                    _buildPdfShoppingHeaderCell('Sr #'),
                    _buildPdfShoppingHeaderCell('Items Name', align: pw.TextAlign.left),
                    _buildPdfShoppingHeaderCell('Status'),
                    _buildPdfShoppingHeaderCell('Quantity', align: pw.TextAlign.right),
                  ],
                ),
                // Table Data Rows
                ...ordered.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final item = entry.value;
                  final isEven = idx % 2 == 0;
                  final rowBg = isEven ? PdfColor.fromHex('#F8FAFC') : PdfColors.white;
                  final qtyStr = item.quantityNeeded % 1 == 0
                      ? item.quantityNeeded.toInt().toString()
                      : item.quantityNeeded.toString();

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: rowBg),
                    children: [
                      // Sr #
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          '#$idx',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ),
                      // Item Name
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              item.ingredientName,
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#0F172A'),
                              ),
                            ),
                            if (item.addedReason.isNotEmpty && item.addedReason != 'manual')
                              pw.Text(
                                'Reason: ${item.addedReason}',
                                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                              ),
                          ],
                        ),
                      ),
                      // Status
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                        alignment: pw.Alignment.center,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex(item.resolved ? '#DCFCE7' : '#FEF3C7'),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Text(
                            item.resolved ? 'Bought [✓]' : 'To Buy [ ]',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex(item.resolved ? '#15803D' : '#92400E'),
                            ),
                          ),
                        ),
                      ),
                      // Quantity
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(
                          qtyStr,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#0F172A'),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                // Total Summary Row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F1F5F9')),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'TOTAL',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Total Products: ${ordered.length} items',
                        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        '$boughtCount / ${ordered.length} Bought',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        'Qty: $formattedTotalQty',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#15803D'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Smart Pantry Grocery & Shopping Management', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  /// Generates and opens a high quality printable PDF for a Shopping Cart / Trip
  static Future<void> generateShoppingListPdf({
    required int tripNum,
    required List<ShoppingListItemModel> items,
    required bool isFrozen,
    String? monthYear,
  }) async {
    final pdf = buildShoppingListDocument(
      tripNum: tripNum,
      items: items,
      isFrozen: isFrozen,
      monthYear: monthYear,
    );

    final filename = 'Shopping_List_Trip_${tripNum}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    await Printing.layoutPdf(
      name: filename,
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  /// Shares the Shopping List PDF file via system share sheet (WhatsApp, Email, etc.)
  static Future<bool> shareShoppingListPdfDocument({
    required int tripNum,
    required List<ShoppingListItemModel> items,
    required bool isFrozen,
    String? monthYear,
  }) async {
    final pdf = buildShoppingListDocument(
      tripNum: tripNum,
      items: items,
      isFrozen: isFrozen,
      monthYear: monthYear,
    );

    final bytes = await pdf.save();
    final filename = 'Shopping_List_Trip_${tripNum}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    return await Printing.sharePdf(
      bytes: bytes,
      filename: filename,
      subject: 'Shopping List #$tripNum Report',
      body: 'Smart Pantry: Attached is the Shopping List #$tripNum PDF report.',
    );
  }

  /// Builds a formatted text representation of the shopping list for WhatsApp
  static String buildWhatsAppShoppingListText({
    required int tripNum,
    required List<ShoppingListItemModel> items,
    required bool isFrozen,
    String? monthYear,
  }) {
    final ordered = List<ShoppingListItemModel>.from(items);
    ordered.sort((a, b) {
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

    final buffer = StringBuffer();
    for (var i = 0; i < ordered.length; i++) {
      final item = ordered[i];
      final qtyStr = item.quantityNeeded % 1 == 0
          ? item.quantityNeeded.toInt().toString()
          : item.quantityNeeded.toString();
      buffer.writeln('${i + 1}. ${item.ingredientName} — Qty: $qtyStr');
    }

    return buffer.toString().trim();
  }

  /// Launches WhatsApp with the shopping list text
  static Future<bool> launchWhatsApp({
    required String message,
    String? phoneNumber,
  }) async {
    String cleanNumber = (phoneNumber ?? '').replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanNumber.startsWith('+')) {
      cleanNumber = cleanNumber.substring(1);
    }
    if (cleanNumber.startsWith('0') && cleanNumber.length == 11) {
      // Pakistani numbers e.g. 0300... -> 92300...
      cleanNumber = '92${cleanNumber.substring(1)}';
    }

    final encodedText = Uri.encodeComponent(message);
    final urlStr = cleanNumber.isNotEmpty
        ? 'https://api.whatsapp.com/send?phone=$cleanNumber&text=$encodedText'
        : 'https://api.whatsapp.com/send?text=$encodedText';

    return await openWebOrNativeUrl(urlStr);
  }

  static pw.Widget _buildSummaryBox({
    required String label,
    required String value,
    required PdfColor bg,
    required PdfColor text,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: text),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: text),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfShoppingHeaderCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      alignment: align == pw.TextAlign.center
          ? pw.Alignment.center
          : align == pw.TextAlign.right
              ? pw.Alignment.centerRight
              : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }
}
