const express = require('express');
const userController = require('../../controllers/user.controller');
const authenticate = require('../../middleware/authenticate');
const authorize = require('../../middleware/authorize');
const { mongoIdValidator } = require('../../validators/ingredient.validator');
const validate = require('../../middleware/validate');

const router = express.Router();

// All user management routes require login and 'admin' role
router.use(authenticate);
router.use(authorize('admin'));

router
  .route('/')
  .get(userController.getUsers)
  .post(userController.createUser);

router
  .route('/:id')
  .patch(mongoIdValidator, validate, userController.updateUser)
  .put(mongoIdValidator, validate, userController.updateUser)
  .delete(mongoIdValidator, validate, userController.deleteUser);

module.exports = router;
