const { body, param } = require('express-validator');

const createShoppingListItemValidator = [
  body('ingredientName').notEmpty().withMessage('Ingredient name is required').trim(),
  body('quantityNeeded').isFloat({ min: 0.1 }).withMessage('Quantity must be greater than 0'),
  body('addedReason').optional().trim(),
  body('resolved').optional().isBoolean(),
  body('tripNumber').optional().isInt({ min: 1 }),
  body('boughtAt').optional().isISO8601(),
  body('createdAt').optional().isISO8601(),
];

const updateShoppingListItemValidator = [
  param('id').isMongoId().withMessage('Invalid ID format'),
  body('resolved').optional().isBoolean(),
  body('quantityNeeded').optional().isFloat({ min: 0.1 }),
  body('isFrozen').optional().isBoolean(),
];

module.exports = { createShoppingListItemValidator, updateShoppingListItemValidator };
