const mongoose = require('mongoose');
const env = require('../config/env');
const Recipe = require('../models/Recipe');

const dummyRecipes = [
  {
    title: 'Spicy Tomato Pasta',
    requiredIngredients: [
      { name: 'Pasta', quantity: 200, unit: 'grams' },
      { name: 'Tomato Sauce', quantity: 1, unit: 'cup' },
      { name: 'Chili Flakes', quantity: 1, unit: 'tsp' },
      { name: 'Garlic', quantity: 2, unit: 'cloves' }
    ],
    substitutes: [
      { original: 'Pasta', substitute: 'Zucchini Noodles' }
    ],
    instructions: ['Boil pasta', 'Sauté garlic', 'Add sauce and chili', 'Mix and serve'],
    cuisineType: 'Italian',
    prepTimeMinutes: 20,
  },
  {
    title: 'Chicken Fried Rice',
    requiredIngredients: [
      { name: 'Rice', quantity: 2, unit: 'cups' },
      { name: 'Chicken Breast', quantity: 1, unit: 'pcs' },
      { name: 'Soy Sauce', quantity: 2, unit: 'tbsp' },
      { name: 'Eggs', quantity: 2, unit: 'pcs' },
      { name: 'Peas', quantity: 0.5, unit: 'cup' }
    ],
    substitutes: [
      { original: 'Chicken Breast', substitute: 'Tofu' },
      { original: 'Rice', substitute: 'Quinoa' }
    ],
    instructions: ['Cook rice', 'Scramble eggs', 'Cook chicken', 'Mix all with soy sauce'],
    cuisineType: 'Asian',
    prepTimeMinutes: 25,
  },
  {
    title: 'Simple Omelette',
    requiredIngredients: [
      { name: 'Eggs', quantity: 3, unit: 'pcs' },
      { name: 'Cheese', quantity: 50, unit: 'grams' },
      { name: 'Butter', quantity: 1, unit: 'tbsp' },
      { name: 'Salt', quantity: 1, unit: 'pinch' }
    ],
    substitutes: [
      { original: 'Butter', substitute: 'Olive Oil' }
    ],
    instructions: ['Whisk eggs', 'Melt butter', 'Cook eggs', 'Add cheese and fold'],
    cuisineType: 'Continental',
    prepTimeMinutes: 10,
  },
  {
    title: 'Oatmeal with Berries',
    requiredIngredients: [
      { name: 'Oats', quantity: 1, unit: 'cup' },
      { name: 'Milk', quantity: 1, unit: 'cup' },
      { name: 'Honey', quantity: 1, unit: 'tbsp' },
      { name: 'Mixed Berries', quantity: 0.5, unit: 'cup' }
    ],
    substitutes: [
      { original: 'Milk', substitute: 'Almond Milk' },
      { original: 'Honey', substitute: 'Maple Syrup' }
    ],
    instructions: ['Boil milk', 'Add oats and cook', 'Top with honey and berries'],
    cuisineType: 'American',
    prepTimeMinutes: 15,
  },
  {
    title: 'Avocado Toast',
    requiredIngredients: [
      { name: 'Bread', quantity: 2, unit: 'slices' },
      { name: 'Avocado', quantity: 1, unit: 'pcs' },
      { name: 'Lemon Juice', quantity: 1, unit: 'tsp' },
      { name: 'Salt', quantity: 1, unit: 'pinch' }
    ],
    substitutes: [
      { original: 'Lemon Juice', substitute: 'Lime Juice' }
    ],
    instructions: ['Toast bread', 'Mash avocado with lemon and salt', 'Spread on toast'],
    cuisineType: 'American',
    prepTimeMinutes: 5,
  }
];

const seedDB = async () => {
  try {
    await mongoose.connect(env.MONGODB_URI);
    console.log('MongoDB connected for seeding.');

    await Recipe.deleteMany();
    console.log('Cleared existing recipes.');

    await Recipe.insertMany(dummyRecipes);
    console.log('Dummy recipes inserted.');

    process.exit();
  } catch (err) {
    console.error('Seeding error:', err);
    process.exit(1);
  }
};

seedDB();
