const express = require('express');
const inventoryController = require('../../controllers/inventory.controller');
const authenticate = require('../../middleware/authenticate');
const validate = require('../../middleware/validate');
const { createIngredientValidator, updateIngredientValidator, mongoIdValidator } = require('../../validators/ingredient.validator');

const router = express.Router();

router.use(authenticate); // Protect all inventory routes

router
  .route('/')
  .get(inventoryController.getInventory)
  .post(createIngredientValidator, validate, inventoryController.addIngredient);

router.post('/clear-days', inventoryController.clearMonthDays);
router.post('/close-month', inventoryController.closeMonth);
router.get('/archives', inventoryController.getMonthlyArchives);
router.delete('/archives/:id', mongoIdValidator, validate, inventoryController.deleteMonthlyArchive);

router
  .route('/:id')
  .patch(updateIngredientValidator, validate, inventoryController.updateIngredient)
  .delete(mongoIdValidator, validate, inventoryController.deleteIngredient);

router.post('/:id/usage', mongoIdValidator, validate, inventoryController.logUsage);
router.post('/:id/usage/update-user-entry', mongoIdValidator, validate, inventoryController.updateUserShiftEntry);
router.post('/:id/restock', mongoIdValidator, validate, inventoryController.restockIngredient);

module.exports = router;
