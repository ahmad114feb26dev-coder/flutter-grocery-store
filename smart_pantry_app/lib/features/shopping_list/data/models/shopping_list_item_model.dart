class ShoppingListItemModel {
  final String? id;
  final String ingredientName;
  final double quantityNeeded;
  final String addedReason;
  final bool resolved;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? boughtAt;
  final bool movedToPantry;
  final bool isFrozen;
  final int tripNumber;

  ShoppingListItemModel({
    this.id,
    required this.ingredientName,
    required this.quantityNeeded,
    required this.addedReason,
    this.resolved = false,
    this.createdAt,
    this.updatedAt,
    this.boughtAt,
    this.movedToPantry = false,
    this.isFrozen = false,
    this.tripNumber = 1,
  });

  /// Effective date when this purchase occurred or was added
  DateTime get effectiveDate => boughtAt ?? updatedAt ?? createdAt ?? DateTime.now();

  factory ShoppingListItemModel.fromJson(Map<String, dynamic> json) {
    return ShoppingListItemModel(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      ingredientName: json['ingredientName'] as String? ?? '',
      quantityNeeded: (json['quantityNeeded'] as num?)?.toDouble() ?? 1.0,
      addedReason: json['addedReason'] as String? ?? 'manual',
      resolved: json['resolved'] as bool? ?? false,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      boughtAt: json['boughtAt'] != null ? DateTime.tryParse(json['boughtAt'].toString()) : null,
      movedToPantry: json['movedToPantry'] as bool? ?? false,
      isFrozen: json['isFrozen'] as bool? ?? false,
      tripNumber: (json['tripNumber'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'ingredientName': ingredientName,
      'quantityNeeded': quantityNeeded,
      'addedReason': addedReason,
      'resolved': resolved,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (boughtAt != null) 'boughtAt': boughtAt!.toIso8601String(),
      'movedToPantry': movedToPantry,
      'isFrozen': isFrozen,
      'tripNumber': tripNumber,
    };
  }

  ShoppingListItemModel copyWith({
    String? id,
    String? ingredientName,
    double? quantityNeeded,
    String? addedReason,
    bool? resolved,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? boughtAt,
    bool? movedToPantry,
    bool? isFrozen,
    int? tripNumber,
  }) {
    return ShoppingListItemModel(
      id: id ?? this.id,
      ingredientName: ingredientName ?? this.ingredientName,
      quantityNeeded: quantityNeeded ?? this.quantityNeeded,
      addedReason: addedReason ?? this.addedReason,
      resolved: resolved ?? this.resolved,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      boughtAt: boughtAt ?? this.boughtAt,
      movedToPantry: movedToPantry ?? this.movedToPantry,
      isFrozen: isFrozen ?? this.isFrozen,
      tripNumber: tripNumber ?? this.tripNumber,
    );
  }
}
