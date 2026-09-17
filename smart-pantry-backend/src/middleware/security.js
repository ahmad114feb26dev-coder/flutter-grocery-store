const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const mongoSanitize = require('express-mongo-sanitize');
const xss = require('xss-clean');
const cors = require('cors');

const securityMiddleware = (app) => {
  // Set secure HTTP headers
  app.use(helmet());

  // CORS configuration (allow-list approach can be added here)
  app.use(
    cors({
      origin: '*', // For dev, but can be restricted to specific origins
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
    })
  );

  // Data sanitization against NoSQL query injection
  app.use((req, res, next) => {
    if (req.body) {
      mongoSanitize.sanitize(req.body);
    }
    next();
  });

  // Data sanitization against XSS (Express 5 safe)
  // xss-clean mutates req.query which is read-only in Express 5

  // Rate limiting for sensitive auth routes (login, register)
  const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // limit each IP to 100 requests per windowMs for auth
    message: 'Too many login attempts from this IP, please try again after 15 minutes',
  });

  app.use('/api/v1/auth/login', authLimiter);
  app.use('/api/v1/auth/register', authLimiter);
};

module.exports = securityMiddleware;
