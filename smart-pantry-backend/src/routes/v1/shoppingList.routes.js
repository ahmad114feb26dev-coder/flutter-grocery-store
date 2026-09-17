const express = require('express');
const shoppingListController = require('../../controllers/shoppingList.controller');
const authenticate = require('../../middleware/authenticate');
const validate = require('../../middleware/validate');
const { createShoppingListItemValidator, updateShoppingListItemValidator } = require('../../validators/shoppingList.validator');
const { mongoIdValidator } = require('../../validators/ingredient.validator'); // Re-using

const router = express.Router();

router.use(authenticate);

router
  .route('/')
  .get(shoppingListController.getShoppingList)
  .post(createShoppingListItemValidator, validate, shoppingListController.addItem);

router.patch('/finalize', shoppingListController.finalizeList);

router
  .route('/:id')
  .patch(updateShoppingListItemValidator, validate, shoppingListController.updateItem)
  .delete(mongoIdValidator, validate, shoppingListController.deleteItem);

module.exports = router;
