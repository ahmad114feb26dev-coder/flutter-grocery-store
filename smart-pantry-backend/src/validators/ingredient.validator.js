const { body, param } = require('express-validator');

const createIngredientValidator = [
  body('name').notEmpty().withMessage('Name is required').trim(),
  body('quantity').isFloat({ min: 0 }).withMessage('Quantity must be a positive number'),
  body('unit').notEmpty().withMessage('Unit is required').trim(),
  body('expiryDate').optional().isISO8601().withMessage('Valid expiry date is required'),
  body('category').optional().trim(),
  body('dailyUsage').optional({ nullable: true }).isFloat({ min: 0 }),
  body('lowStockThreshold').optional({ nullable: true }).isFloat({ min: 0 }),
];

const updateIngredientValidator = [
  param('id').isMongoId().withMessage('Invalid ingredient ID'),
  body('name').optional().notEmpty().withMessage('Name cannot be empty').trim(),
  body('quantity').optional().isFloat({ min: 0 }).withMessage('Quantity must be a positive number'),
  body('unit').optional().notEmpty().withMessage('Unit cannot be empty').trim(),
  body('expiryDate').optional().isISO8601().withMessage('Valid expiry date is required'),
  body('category').optional().trim(),
  body('dailyUsage').optional({ nullable: true }).isFloat({ min: 0 }),
  body('lowStockThreshold').optional({ nullable: true }).isFloat({ min: 0 }),
];

const mongoIdValidator = [
  param('id').isMongoId().withMessage('Invalid ID format'),
];

module.exports = { createIngredientValidator, updateIngredientValidator, mongoIdValidator };
