const express = require('express');
const morgan = require('morgan');
const securityMiddleware = require('./middleware/security');
const errorHandler = require('./middleware/errorHandler');
const routesV1 = require('./routes/v1');
const env = require('./config/env');
const AppError = require('./utils/AppError');

const app = express();

// Body parser
app.use(express.json());

// Development logging
if (env.NODE_ENV === 'development') {
  app.use(morgan('dev'));
}

// Apply security middlewares (helmet, cors, sanitize, rate limit)
securityMiddleware(app);

// Mount API routes
app.use('/api/v1', routesV1);

// Handle unhandled routes
app.use((req, res, next) => {
  next(new AppError(`Can't find ${req.originalUrl} on this server!`, 404));
});

// Global error handler
app.use(errorHandler);

module.exports = app;
