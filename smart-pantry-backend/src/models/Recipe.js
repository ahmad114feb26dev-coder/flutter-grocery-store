const mongoose = require('mongoose');

const recipeSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
      trim: true,
    },
    requiredIngredients: [
      {
        name: { type: String, required: true },
        quantity: { type: Number, required: true },
        unit: { type: String, required: true },
      },
    ],
    substitutes: [
      {
        original: { type: String, required: true },
        substitute: { type: String, required: true },
      },
    ],
    instructions: {
      type: [String],
      required: true,
    },
    cuisineType: {
      type: String,
      trim: true,
    },
    prepTimeMinutes: {
      type: Number,
      min: 0,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Recipe', recipeSchema);
