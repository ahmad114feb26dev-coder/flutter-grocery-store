const mongoose = require('mongoose');
const env = require('../config/env');
const User = require('../models/User');
const Ingredient = require('../models/Ingredient');

const officeExpenseItems = [
  {
    name: 'Everyday 2kg',
    category: 'Dairy',
    unit: 'kg',
    stockIn: 64.25,
    dailyUsage: 2.5,
    lowStockThreshold: 10,
    dailyUsageLogs: {},
    totalUsed: 0,
    quantity: 64.25,
    expiryDate: new Date(Date.now() + 60 * 24 * 60 * 60 * 1000),
  },
  {
    name: 'Lipton Tea 2kg',
    category: 'Pantry',
    unit: 'kg',
    stockIn: 41.0,
    dailyUsage: 1.0,
    lowStockThreshold: 10,
    dailyUsageLogs: {},
    totalUsed: 0,
    quantity: 41.0,
    expiryDate: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000),
  },
  {
    name: 'Green Tea bags',
    category: 'Pantry',
    unit: 'pcs',
    stockIn: 610.0,
    dailyUsage: 10.0,
    lowStockThreshold: 100,
    dailyUsageLogs: {},
    totalUsed: 0,
    quantity: 610.0,
    expiryDate: new Date(Date.now() + 180 * 24 * 60 * 60 * 1000),
  },
  {
    name: 'Sugar',
    category: 'Pantry',
    unit: 'kg',
    stockIn: 21.0,
    dailyUsage: 0.5,
    lowStockThreshold: 5,
    dailyUsageLogs: {},
    totalUsed: 0,
    quantity: 21.0,
    expiryDate: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
  },
  {
    name: 'Water Bottels 19 liter',
    category: 'Other',
    unit: 'bottle',
    stockIn: 90.0,
    dailyUsage: 3.0,
    lowStockThreshold: 15,
    dailyUsageLogs: {},
    totalUsed: 0,
    quantity: 90.0,
    expiryDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
  },
  {
    name: 'Dishwashing liquid',
    category: 'Other',
    unit: 'bottle',
    stockIn: 12.0,
    dailyUsage: 0.5,
    lowStockThreshold: 3,
    dailyUsageLogs: {},
    totalUsed: 0,
    quantity: 12.0,
    expiryDate: new Date(Date.now() + 180 * 24 * 60 * 60 * 1000),
  },
  {
    name: 'Scotch Brite',
    category: 'Other',
    unit: 'pcs',
    stockIn: 38.0,
    dailyUsage: 1.0,
    lowStockThreshold: 5,
    dailyUsageLogs: {},
    totalUsed: 0,
    quantity: 38.0,
    expiryDate: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
  },
  {
    name: 'Sweep Acid',
    category: 'Other',
    unit: 'bottle',
    stockIn: 50.0,
    dailyUsage: 1.0,
    lowStockThreshold: 10,
    dailyUsageLogs: {},
    totalUsed: 0,
    quantity: 50.0,
    expiryDate: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
  },
  {
    name: 'Harpic',
    category: 'Other',
    unit: 'bottle',
    stockIn: 44.0,
    dailyUsage: 1.0,
    lowStockThreshold: 10,
    dailyUsageLogs: {},
    totalUsed: 0,
    quantity: 44.0,
    expiryDate: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
  },
  {
    name: 'Surf',
    category: 'Other',
    unit: 'pack',
    stockIn: 2.0,
    dailyUsage: 0.1,
    lowStockThreshold: 1,
    dailyUsageLogs: {},
    totalUsed: 0,
    quantity: 2.0,
    expiryDate: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
  },
  {
    name: 'Toilet Tissue',
    category: 'Other',
    unit: 'roll',
    stockIn: 344.0,
    dailyUsage: 10.0,
    lowStockThreshold: 50,
    dailyUsageLogs: {},
    totalUsed: 0,
    quantity: 344.0,
    expiryDate: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
  },
  {
    name: 'Table Tissue',
    category: 'Other',
    unit: 'box',
    stockIn: 34.0,
    dailyUsage: 1.0,
    lowStockThreshold: 5,
    dailyUsageLogs: {},
    totalUsed: 0,
    quantity: 34.0,
    expiryDate: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
  },
  {
    name: 'Phenyl',
    category: 'Other',
    unit: 'bottle',
    stockIn: 17.0,
    dailyUsage: 0.5,
    lowStockThreshold: 4,
    dailyUsageLogs: {},
    totalUsed: 0,
    quantity: 17.0,
    expiryDate: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
  },
  {
    name: 'Duster',
    category: 'Other',
    unit: 'pcs',
    stockIn: 15.0,
    dailyUsage: 1.0,
    lowStockThreshold: 5,
    dailyUsageLogs: {},
    totalUsed: 0,
    quantity: 15.0,
    expiryDate: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
  },
  {
    name: 'Garbage Bag',
    category: 'Other',
    unit: 'roll',
    stockIn: 6.5,
    dailyUsage: 0.2,
    lowStockThreshold: 2,
    dailyUsageLogs: {},
    totalUsed: 0,
    quantity: 6.5,
    expiryDate: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
  },
  {
    name: 'HandWash 5ltr Bottel',
    category: 'Other',
    unit: 'bottle',
    stockIn: 28.0,
    dailyUsage: 0.5,
    lowStockThreshold: 5,
    dailyUsageLogs: {},
    totalUsed: 0,
    quantity: 28.0,
    expiryDate: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
  },
];

async function seedOfficeExpense() {
  try {
    await mongoose.connect(env.MONGODB_URI);
    console.log('Connected to MongoDB for Office Expenses clean seed.');

    let user = await User.findOne();
    if (!user) {
      user = await User.create({
        name: 'Office Admin',
        email: 'admin@officepantry.com',
        password: 'Password123!',
      });
      console.log('Created default admin user for seeding.');
    }

    // Clear existing ingredients
    await Ingredient.deleteMany({ userId: user._id });
    console.log('Cleared existing pantry items.');

    // Insert clean items with only initial stock in and empty days 1-31
    const itemsToInsert = officeExpenseItems.map((item) => ({
      ...item,
      userId: user._id,
    }));

    await Ingredient.insertMany(itemsToInsert);
    console.log('Successfully seeded 16 Office Expense items with clean days 1-31!');

    await mongoose.disconnect();
    console.log('Disconnected from MongoDB.');
  } catch (error) {
    console.error('Error seeding office expenses:', error);
    process.exit(1);
  }
}

seedOfficeExpense();
