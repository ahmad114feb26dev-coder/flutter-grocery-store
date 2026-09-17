// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecipeModel _$RecipeModelFromJson(Map<String, dynamic> json) => RecipeModel(
      id: json['_id'] as String?,
      title: json['title'] as String,
      instructions: (json['instructions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      cuisineType: json['cuisineType'] as String?,
      prepTimeMinutes: (json['prepTimeMinutes'] as num?)?.toInt(),
      matchPercentage: (json['matchPercentage'] as num?)?.toDouble() ?? 0.0,
      missingIngredients: (json['missingIngredients'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      substituteOptions: (json['substituteOptions'] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e as Map))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$RecipeModelToJson(RecipeModel instance) =>
    <String, dynamic>{
      '_id': instance.id,
      'title': instance.title,
      'instructions': instance.instructions,
      'cuisineType': instance.cuisineType,
      'prepTimeMinutes': instance.prepTimeMinutes,
      'matchPercentage': instance.matchPercentage,
      'missingIngredients': instance.missingIngredients,
      'substituteOptions': instance.substituteOptions,
    };
