const express = require('express');
const authRoutes = require('./auth.routes');
const inventoryRoutes = require('./inventory.routes');
const recipesRoutes = require('./recipes.routes');
const shoppingListRoutes = require('./shoppingList.routes');
const userRoutes = require('./user.routes');

const router = express.Router();

router.use('/auth', authRoutes);
router.use('/inventory', inventoryRoutes);
router.use('/recipes', recipesRoutes);
router.use('/shopping-list', shoppingListRoutes);
router.use('/users', userRoutes);

module.exports = router;
