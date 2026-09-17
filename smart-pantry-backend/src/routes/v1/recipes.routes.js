const express = require('express');
const recipesController = require('../../controllers/recipes.controller');
const authenticate = require('../../middleware/authenticate');

const router = express.Router();

router.use(authenticate);

router.get('/suggestions', recipesController.getSuggestions);

module.exports = router;
