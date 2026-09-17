const mongoose = require('mongoose');

const ingredientSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    category: {
      type: String,
      default: 'Other',
      trim: true,
    },
    quantity: {
      type: Number,
      required: true,
      default: 0,
    },
    stockIn: {
      type: Number,
      default: function () {
        return this.quantity;
      },
    },
    totalUsed: {
      type: Number,
      default: 0,
    },
    dailyUsageLogs: {
      type: Object,
      default: {},
    },
    dailyUsageEdits: {
      type: Object,
      default: {},
    },
    shiftUsageLogs: {
      type: Object,
      default: {},
    },
    unit: {
      type: String,
      required: true,
      trim: true,
      // e.g., 'grams', 'cups', 'pcs'
    },
    expiryDate: {
      type: Date,
      required: false,
      default: () => new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
    },
    dailyUsage: {
      type: Number,
      default: null,
      min: 0,
    },
    lowStockThreshold: {
      type: Number,
      default: 3,
      min: 0,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Ingredient', ingredientSchema);
