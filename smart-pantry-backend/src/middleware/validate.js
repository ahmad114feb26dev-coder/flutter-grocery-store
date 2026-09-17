const { validationResult } = require('express-validator');
const AppError = require('../utils/AppError');

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (errors.isEmpty()) {
    return next();
  }
  
  const extractedErrors = [];
  errors.array().forEach(err => extractedErrors.push(`${err.path}: ${err.msg}`));

  return next(new AppError(`Validation failed: ${extractedErrors.join(', ')}`, 400));
};

module.exports = validate;
