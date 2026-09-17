const express = require('express');
const authController = require('../../controllers/auth.controller');
const validate = require('../../middleware/validate');
const { registerValidator, loginValidator, refreshTokenValidator } = require('../../validators/auth.validator');
const authenticate = require('../../middleware/authenticate');

const router = express.Router();

router.post('/register', registerValidator, validate, authController.register);
router.post('/login', loginValidator, validate, authController.login);
router.post('/refresh-token', refreshTokenValidator, validate, authController.refreshToken);
router.post('/logout', authenticate, authController.logout);
router.get('/me', authenticate, authController.getMe);

module.exports = router;
