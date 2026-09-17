const mongoose = require('mongoose');

const shoppingListItemSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    ingredientName: {
      type: String,
      required: true,
      trim: true,
    },
    quantityNeeded: {
      type: Number,
      required: true,
      min: 0.1,
    },
    addedReason: {
      type: String,
      default: 'manual',
    },
    resolved: {
      type: Boolean,
      default: false,
    },
    boughtAt: {
      type: Date,
    },
    movedToPantry: {
      type: Boolean,
      default: false,
    },
    isFrozen: {
      type: Boolean,
      default: false,
    },
    tripNumber: {
      type: Number,
      default: 1,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('ShoppingListItem', shoppingListItemSchema);
