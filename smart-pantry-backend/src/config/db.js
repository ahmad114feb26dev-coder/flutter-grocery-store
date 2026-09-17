const mongoose = require('mongoose');
const env = require('./env');

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(env.MONGODB_URI, {
      // Documenting connection pooling for production readiness
      maxPoolSize: 10,
    });
    console.log(`MongoDB Connected: ${conn.connection.host}`);

    // Ensure default initial admin chef exists
    const User = require('../models/User');
    let defaultUser = await User.findOne({ email: 'chef@smartpantry.local' });
    if (!defaultUser) {
      await User.create({
        name: 'Pantry Chef',
        email: 'chef@smartpantry.local',
        passwordHash: '$2b$12$Vp/IksLx9wOTtUj0iTdtJeqG0W1Yn9qztmnlQYhDAgKldlbUQXWxq',
        role: 'admin',
        allowedSections: ['dashboard', 'pantry', 'expenses', 'reports', 'shopping_list'],
        accessMode: 'can_edit',
      });
    }
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }
};

module.exports = connectDB;
