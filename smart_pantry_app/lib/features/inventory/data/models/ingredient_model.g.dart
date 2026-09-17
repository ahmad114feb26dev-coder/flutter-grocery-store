// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ingredient_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IngredientModel _$IngredientModelFromJson(Map<String, dynamic> json) =>
    IngredientModel(
      id: json['_id'] as String?,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'Other',
      quantity: (json['quantity'] as num).toDouble(),
      stockIn: (json['stockIn'] as num?)?.toDouble(),
      totalUsed: (json['totalUsed'] as num?)?.toDouble(),
      dailyUsageLogs: (json['dailyUsageLogs'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
      dailyUsageEdits: json['dailyUsageEdits'] as Map<String, dynamic>?,
      shiftUsageLogs: json['shiftUsageLogs'] as Map<String, dynamic>?,
      unit: json['unit'] as String,
      expiryDate: DateTime.parse(json['expiryDate'] as String),
      daysLeft: (json['daysLeft'] as num?)?.toInt(),
      dailyUsage: (json['dailyUsage'] as num?)?.toDouble(),
      lowStockThreshold: (json['lowStockThreshold'] as num?)?.toDouble() ?? 3.0,
    );

Map<String, dynamic> _$IngredientModelToJson(IngredientModel instance) =>
    <String, dynamic>{
      if (instance.id != null) '_id': instance.id,
      'name': instance.name,
      'category': instance.category,
      'quantity': instance.quantity,
      if (instance.stockIn != null) 'stockIn': instance.stockIn,
      if (instance.totalUsed != null) 'totalUsed': instance.totalUsed,
      if (instance.dailyUsageLogs != null) 'dailyUsageLogs': instance.dailyUsageLogs,
      if (instance.dailyUsageEdits != null) 'dailyUsageEdits': instance.dailyUsageEdits,
      if (instance.shiftUsageLogs != null) 'shiftUsageLogs': instance.shiftUsageLogs,
      'unit': instance.unit,
      'expiryDate': instance.expiryDate.toIso8601String(),
      if (instance.daysLeft != null) 'daysLeft': instance.daysLeft,
      if (instance.dailyUsage != null) 'dailyUsage': instance.dailyUsage,
      if (instance.lowStockThreshold != null) 'lowStockThreshold': instance.lowStockThreshold,
    };
