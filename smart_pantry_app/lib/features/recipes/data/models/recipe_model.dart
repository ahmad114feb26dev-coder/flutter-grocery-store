import 'package:json_annotation/json_annotation.dart';

part 'recipe_model.g.dart';

@JsonSerializable()
class RecipeModel {
  @JsonKey(name: '_id')
  final String? id;
  final String title;
  final List<String> instructions;
  final String? cuisineType;
  final int? prepTimeMinutes;
  final double matchPercentage;
  final List<String> missingIngredients;
  final List<Map<String, String>> substituteOptions;

  RecipeModel({
    this.id,
    required this.title,
    required this.instructions,
    this.cuisineType,
    this.prepTimeMinutes,
    this.matchPercentage = 0.0,
    this.missingIngredients = const [],
    this.substituteOptions = const [],
  });

  factory RecipeModel.fromJson(Map<String, dynamic> json) => _$RecipeModelFromJson(json);
  Map<String, dynamic> toJson() => _$RecipeModelToJson(this);
}
