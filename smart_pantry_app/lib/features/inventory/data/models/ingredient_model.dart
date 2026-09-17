import 'package:json_annotation/json_annotation.dart';

part 'ingredient_model.g.dart';

@JsonSerializable()
class IngredientModel {
  @JsonKey(name: '_id')
  final String? id;
  final String name;
  final String category;
  final double quantity;
  final String unit;
  final DateTime expiryDate;
  final int? daysLeft;
  final double? dailyUsage;
  final double? lowStockThreshold;

  final double? stockIn;
  final double? totalUsed;
  final Map<String, double>? dailyUsageLogs;
  final Map<String, dynamic>? dailyUsageEdits;
  final Map<String, dynamic>? shiftUsageLogs;

  IngredientModel({
    this.id,
    required this.name,
    this.category = 'Other',
    required this.quantity,
    this.stockIn,
    this.totalUsed,
    this.dailyUsageLogs,
    this.dailyUsageEdits,
    this.shiftUsageLogs,
    required this.unit,
    required this.expiryDate,
    this.daysLeft,
    this.dailyUsage,
    this.lowStockThreshold,
  });

  /// Returns the entries recorded for each shift on this day
  List<Map<String, dynamic>> getShiftEntriesForDay(dynamic dayKey) {
    if (shiftUsageLogs == null) return [];
    final raw = shiftUsageLogs![dayKey.toString()] ?? shiftUsageLogs![dayKey];
    if (raw is List) {
      return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }
    return [];
  }

  /// Returns the quantity logged by this specific staff member on this day, or null if not entered
  double? getStaffUsageOnDay(dynamic dayKey, String? userId, String? userEmail) {
    final totalLog = dailyUsageLogs?[dayKey.toString()] ?? dailyUsageLogs?[dayKey];
    if (totalLog == null || totalLog <= 0) {
      return null;
    }

    final entries = getShiftEntriesForDay(dayKey);
    final targetId = userId?.trim();
    final targetEmail = userEmail?.toLowerCase().trim();

    for (final entry in entries) {
      final entryUserId = entry['userId']?.toString().trim();
      final entryUserEmail = entry['userEmail']?.toString().toLowerCase().trim();

      if ((targetId != null && targetId.isNotEmpty && entryUserId == targetId) ||
          (targetEmail != null && targetEmail.isNotEmpty && entryUserEmail == targetEmail)) {
        final amt = entry['amount'];
        if (amt is num) return amt.toDouble();
        if (amt != null) return double.tryParse(amt.toString());
      }
    }
    return null;
  }

  /// Checks whether this specific staff member has already entered on this day
  bool hasStaffLoggedForDay(dynamic dayKey, String? userId, String? userEmail) {
    final val = getStaffUsageOnDay(dayKey, userId, userEmail);
    return val != null && val > 0;
  }

  dynamic _getEdit(dynamic dayKey) {
    if (dailyUsageEdits == null) return null;
    return dailyUsageEdits![dayKey.toString()] ?? dailyUsageEdits![dayKey];
  }

  bool isDayEdited(dynamic dayKey) {
    final edit = _getEdit(dayKey);
    if (edit is Map) {
      return edit['isEdited'] == true || (edit['reason'] != null && edit['reason'].toString().trim().isNotEmpty);
    }
    return false;
  }

  String? getDayEditReason(dynamic dayKey) {
    final edit = _getEdit(dayKey);
    if (edit is Map) {
      return edit['reason']?.toString();
    }
    return null;
  }

  String? getDayEditedBy(dynamic dayKey) {
    final edit = _getEdit(dayKey);
    if (edit is Map) {
      return edit['editedByName']?.toString() ?? 'Admin';
    }
    return null;
  }

  /// In-hand remaining balance: Stock In - Total Used
  double get inHandBalance => (stockIn ?? quantity) - (totalUsed ?? 0.0);

  /// Effective opening/restocked Stock In
  double get effectiveStockIn => stockIn ?? quantity;

  /// Effective total used in the month
  double get effectiveUsed => totalUsed ?? 0.0;

  /// Calculated shopping deficit / quantity required to re-order
  double get shoppingNeededQty {
    final balance = inHandBalance;
    final threshold = lowStockThreshold ?? 3.0;
    final monthlyEstimated = (dailyUsage != null && dailyUsage! > 0) ? (dailyUsage! * 30.0) : effectiveUsed;

    if (balance < 0) {
      // Deficit: Needs enough to cover deficit plus monthly stock
      return (balance.abs() + (monthlyEstimated > 0 ? monthlyEstimated : threshold * 2));
    }

    if (balance <= threshold) {
      // Low stock: Needs to restock up to monthly consumption or 3x threshold
      final target = monthlyEstimated > 0 ? monthlyEstimated : (threshold * 3);
      final needed = target - balance;
      return needed > 0 ? needed : threshold;
    }

    // Sufficient stock: Nothing needed immediately
    return 0.0;
  }

  factory IngredientModel.fromJson(Map<String, dynamic> json) {
    try {
      return _$IngredientModelFromJson(json);
    } catch (_) {
      final rawLogs = json['dailyUsageLogs'];
      Map<String, double>? logs;
      if (rawLogs is Map) {
        logs = rawLogs.map((k, v) => MapEntry(
              k.toString(),
              (v is num) ? v.toDouble() : (double.tryParse(v.toString()) ?? 0.0),
            ));
      }

      DateTime exp;
      if (json['expiryDate'] != null) {
        exp = DateTime.tryParse(json['expiryDate'].toString()) ??
            DateTime.now().add(const Duration(days: 365));
      } else {
        exp = DateTime.now().add(const Duration(days: 365));
      }

      final rawEdits = json['dailyUsageEdits'];
      Map<String, dynamic>? edits;
      if (rawEdits is Map) {
        edits = Map<String, dynamic>.from(rawEdits);
      }

      final rawShiftLogs = json['shiftUsageLogs'];
      Map<String, dynamic>? shiftLogs;
      if (rawShiftLogs is Map) {
        shiftLogs = Map<String, dynamic>.from(rawShiftLogs);
      }

      return IngredientModel(
        id: (json['_id'] ?? json['id'])?.toString(),
        name: (json['name'] ?? 'Item').toString(),
        category: (json['category'] ?? 'Other').toString(),
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
        stockIn: (json['stockIn'] as num?)?.toDouble(),
        totalUsed: (json['totalUsed'] as num?)?.toDouble() ?? 0.0,
        dailyUsageLogs: logs ?? {},
        dailyUsageEdits: edits ?? {},
        shiftUsageLogs: shiftLogs ?? {},
        unit: (json['unit'] ?? 'pcs').toString(),
        expiryDate: exp,
        daysLeft: (json['daysLeft'] as num?)?.toInt(),
        dailyUsage: (json['dailyUsage'] as num?)?.toDouble(),
        lowStockThreshold: (json['lowStockThreshold'] as num?)?.toDouble() ?? 3.0,
      );
    }
  }

  Map<String, dynamic> toJson() {
    final map = _$IngredientModelToJson(this);
    if (dailyUsageEdits != null) {
      map['dailyUsageEdits'] = dailyUsageEdits;
    }
    if (shiftUsageLogs != null) {
      map['shiftUsageLogs'] = shiftUsageLogs;
    }
    return map;
  }
}
