const mongoose = require('mongoose');

const archivedItemSchema = new mongoose.Schema({
  name: { type: String, required: true },
  category: { type: String, default: 'Other' },
  unit: { type: String, required: true },
  stockIn: { type: Number, default: 0 },
  dailyUsageLogs: { type: Object, default: {} },
  dailyUsageEdits: { type: Object, default: {} },
  shiftUsageLogs: { type: Object, default: {} },
  totalUsed: { type: Number, default: 0 },
  balance: { type: Number, default: 0 },
  shoppingNeededQty: { type: Number, default: 0 },
});

const monthlyArchiveSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    monthYear: {
      type: String,
      required: true,
      trim: true,
    },
    items: [archivedItemSchema],
    totalStockIn: {
      type: Number,
      default: 0,
    },
    totalUsed: {
      type: Number,
      default: 0,
    },
    inHandBalance: {
      type: Number,
      default: 0,
    },
    closedAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('MonthlyArchive', monthlyArchiveSchema);
