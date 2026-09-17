const Recipe = require('../models/Recipe');
const Ingredient = require('../models/Ingredient');

const getSuggestedRecipes = async (userId) => {
  // 1. Fetch user's available ingredients
  const userIngredients = await Ingredient.find({ userId, quantity: { $gt: 0 } });
  const userIngredientNames = userIngredients.map(i => i.name.toLowerCase());

  // 2. Fetch all recipes
  const allRecipes = await Recipe.find();

  const fullMatch = [];
  const partialMatch = [];

  for (const recipe of allRecipes) {
    let matchedCount = 0;
    const missingIngredients = [];
    const substituteOptions = [];

    // Evaluate each required ingredient
    for (const reqIng of recipe.requiredIngredients) {
      const reqName = reqIng.name.toLowerCase();

      if (userIngredientNames.includes(reqName)) {
        matchedCount++;
      } else {
        // Check for substitutes
        const sub = recipe.substitutes.find(
          (s) => s.original.toLowerCase() === reqName
        );

        if (sub && userIngredientNames.includes(sub.substitute.toLowerCase())) {
          matchedCount++;
          substituteOptions.push({ original: reqIng.name, usedSubstitute: sub.substitute });
        } else {
          missingIngredients.push(reqIng.name);
        }
      }
    }

    const totalRequired = recipe.requiredIngredients.length;
    const matchPercentage = totalRequired > 0 ? (matchedCount / totalRequired) * 100 : 0;

    const recipeData = {
      ...recipe.toObject(),
      matchPercentage,
      missingIngredients,
      substituteOptions,
    };

    if (missingIngredients.length === 0) {
      fullMatch.push(recipeData);
    } else if (missingIngredients.length <= 2) {
      partialMatch.push(recipeData);
    }
  }

  // Sort descending by match percentage
  fullMatch.sort((a, b) => b.matchPercentage - a.matchPercentage);
  partialMatch.sort((a, b) => b.matchPercentage - a.matchPercentage);

  return { fullMatch, partialMatch };
};

module.exports = {
  getSuggestedRecipes,
};
