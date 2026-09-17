const recipeMatcherService = require('../services/recipeMatcher.service');
const asyncHandler = require('../utils/asyncHandler');

const getSuggestions = asyncHandler(async (req, res, next) => {
  const suggestions = await recipeMatcherService.getSuggestedRecipes(req.user.id);

  res.status(200).json({
    status: 'success',
    data: suggestions,
  });
});

module.exports = {
  getSuggestions,
};
